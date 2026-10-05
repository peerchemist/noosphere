import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/event_wire.dart' as event_wire;
import 'package:noosphere/noosphere.dart' hide DkgAckRequest;
import 'package:noosphere/domain.dart';

import '../config/iroh.dart';
import 'connection_context.dart';
import 'dispatcher.dart';
import 'messages.dart';

final class IrohConnectionHandler {
  IrohConnectionHandler({
    required this.connection,
    required this.dispatcher,
    required this.config,
  }) : context = ConnectionContext(
         connectionId: connection.stableId,
         remoteEndpointId: connection.remoteId,
       );

  final Connection connection;
  final IrohDispatcher dispatcher;
  final IrohConfig config;
  final ConnectionContext context;
  final Set<Future<void>> _streams = {};

  Future<void> run() async {
    try {
      while (!context.isClosed) {
        final (send, receive) = await connection.acceptBi();
        if (_streams.length >= config.maxStreamsPerConnection) {
          await send.reset(1);
          await receive.stop(1);
          continue;
        }
        late final Future<void> handling;
        handling = _handleStream(
          send,
          receive,
        ).whenComplete(() => _streams.remove(handling));
        _streams.add(handling);
      }
    } on IrohConnectionException {
      // Normal when the remote closes the connection.
    } finally {
      final group = context.groupFingerprint;
      if (!context.isClosed && group != null) {
        await dispatcher.disconnect(
          groupFingerprint: group,
          connection: context,
        );
      } else if (!context.isClosed) {
        context.close();
      }
      await Future.wait(_streams.toList(), eagerError: false);
    }
  }

  Future<void> _handleStream(SendStream send, RecvStream receive) async {
    final iterator = StreamIterator(
      decodeEnvelopes(
        _readChunks(receive),
        maxEnvelopeLength: config.maxEnvelopeLength,
      ),
    );
    try {
      if (!await iterator.moveNext().timeout(config.authTimeout)) return;
      final first = iterator.current;
      if (first.wireVersion != noosphereIrohWireVersion) {
        await _write(
          send,
          _error(
            ProtocolErrorCode.PROTOCOL_ERROR_UNSUPPORTED_VERSION,
            'unsupported Iroh wire version',
          ),
        );
      } else {
        switch (first.whichPayload()) {
          case Envelope_Payload.rpcRequest:
            final timeout = switch (first.rpcRequest.whichRequest()) {
              RpcRequest_Request.login ||
              RpcRequest_Request.respondToChallenge => config.authTimeout,
              _ => config.rpcTimeout,
            };
            await _handleRpc(send, first.rpcRequest).timeout(timeout);
          case Envelope_Payload.startSession:
            await _handleStartSession(send, iterator);
          case Envelope_Payload.logout:
            final group = context.groupFingerprint;
            if (group != null) {
              await dispatcher.logout(
                groupFingerprint: group,
                connection: context,
              );
            }
          default:
            await _write(
              send,
              _error(
                ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
                'payload is not valid as the first stream message',
              ),
            );
        }
      }
    } on Exception catch (error) {
      try {
        await _write(
          send,
          _error(ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST, '$error'),
        );
      } on Exception {
        // The stream may already have been closed/reset by the peer.
      }
    } finally {
      try {
        await iterator.cancel();
      } on Exception {
        // Connection loss may also surface while cancelling the decoder.
      }
      try {
        await send.finish().timeout(config.rpcTimeout);
      } on Exception {
        // The peer may have closed the connection first.
      }
    }
  }

  Future<void> _handleRpc(SendStream send, RpcRequest request) async {
    if (request.requestId.isEmpty) {
      await _write(
        send,
        _rpcError(
          request.requestId,
          ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
          'request_id is empty',
        ),
      );
      return;
    }

    final RpcResponse response;
    try {
      response = switch (request.whichRequest()) {
        RpcRequest_Request.login => await _login(request),
        RpcRequest_Request.respondToChallenge => await _authenticate(request),
        RpcRequest_Request.extendSession => await _extendSession(request),
        RpcRequest_Request.requestNewDkg => await _requestNewDkg(request),
        RpcRequest_Request.rejectDkg => await _rejectDkg(request),
        RpcRequest_Request.submitDkgCommitment => await _submitDkgCommitment(
          request,
        ),
        RpcRequest_Request.submitDkgRound2 => await _submitDkgRound2(request),
        RpcRequest_Request.sendDkgAcks => await _sendDkgAcks(request),
        RpcRequest_Request.requestDkgAcks => await _requestDkgAcks(request),
        RpcRequest_Request.requestSignatures => await _requestSignatures(
          request,
        ),
        RpcRequest_Request.rejectSignaturesRequest =>
          await _rejectSignaturesRequest(request),
        RpcRequest_Request.submitSignatureReplies =>
          await _submitSignatureReplies(request),
        RpcRequest_Request.shareSecretShare => await _shareSecretShare(request),
        RpcRequest_Request.ackKeyConstructed => await _ackKeyConstructed(
          request,
        ),
        _ => RpcResponse(
          requestId: request.requestId,
          error: ProtocolError(
            code: ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
            message: 'RPC is not supported on the ROAST ALPN',
          ),
        ),
      };
    } on Exception catch (error) {
      await _write(
        send,
        _rpcError(
          request.requestId,
          ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
          '$error',
        ),
      );
      return;
    }
    await _write(
      send,
      Envelope(wireVersion: noosphereIrohWireVersion, rpcResponse: response),
    );
  }

  Future<RpcResponse> _login(RpcRequest request) async {
    final login = request.login;
    final challenge = await dispatcher.beginAuthentication(
      groupFingerprint: login.groupFingerprint,
      participantId: Identifier.fromBytes(
        Uint8List.fromList(login.participantId),
      ),
      connection: context,
      protocolVersion: login.protocolVersion,
    );
    return RpcResponse(
      requestId: request.requestId,
      login: LoginResponse(challenge: challenge.toBytes()),
    );
  }

  Future<RpcResponse> _authenticate(RpcRequest request) async {
    final signed = request.respondToChallenge;
    final group = context.boundGroupFingerprint;
    if (group == null) throw StateError('connection has no group binding');
    await dispatcher.completeAuthentication(
      groupFingerprint: group,
      connection: context,
      signedChallenge: Signed<AuthChallenge>(
        obj: AuthChallenge.fromBytes(Uint8List.fromList(signed.challenge)),
        signature: coinlib.SchnorrSignature(
          Uint8List.fromList(signed.signature),
        ),
      ),
    );
    return RpcResponse(
      requestId: request.requestId,
      respondToChallenge: RespondToChallengeResponse(
        authenticated: EmptySuccess(),
      ),
    );
  }

  Future<RpcResponse> _extendSession(RpcRequest request) async {
    final group = context.groupFingerprint;
    if (group == null) throw StateError('connection is not authenticated');
    final dispatched = await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        final expiry = await handler.extendSession(
          _sessionId(request.extendSession.data),
        );
        return IrohDispatchResult(expiry);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      extendSession: ExtendSessionResponse(expiry: dispatched.value.toBytes()),
    );
  }

  Future<RpcResponse> _requestNewDkg(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.requestNewDkg;
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.requestNewDkg(
          sid: _sessionId(rpc.sid),
          signedDetails: Signed<NewDkgDetails>.fromBytes(
            Uint8List.fromList(rpc.signedDetails),
            (reader) => NewDkgDetails.fromReader(reader),
          ),
          commitment: DkgPublicCommitment.fromBytes(
            Uint8List.fromList(rpc.commitment),
          ),
        );
        return IrohDispatchResult(null);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      requestNewDkg: RequestNewDkgResponse(success: EmptySuccess()),
    );
  }

  Future<RpcResponse> _rejectDkg(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.rejectDkg;
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.rejectDkg(sid: _sessionId(rpc.sid), name: rpc.name);
        return IrohDispatchResult(null);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      rejectDkg: RejectDkgResponse(success: EmptySuccess()),
    );
  }

  Future<RpcResponse> _submitDkgCommitment(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.submitDkgCommitment;
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.submitDkgCommitment(
          sid: _sessionId(rpc.sid),
          name: rpc.name,
          commitment: DkgPublicCommitment.fromBytes(
            Uint8List.fromList(rpc.commitment),
          ),
        );
        return IrohDispatchResult(null);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      submitDkgCommitment: SubmitDkgCommitmentResponse(success: EmptySuccess()),
    );
  }

  Future<RpcResponse> _submitDkgRound2(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.submitDkgRound2;
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.submitDkgRound2(
          sid: _sessionId(rpc.sid),
          name: rpc.name,
          commitmentSetSignature: coinlib.SchnorrSignature(
            Uint8List.fromList(rpc.commitmentSetSignature),
          ),
          secrets: {
            for (final secret in rpc.secrets)
              Identifier.fromBytes(
                Uint8List.fromList(secret.id),
              ): DkgEncryptedSecret(
                ECCiphertext.fromBytes(Uint8List.fromList(secret.secret)),
              ),
          },
        );
        return IrohDispatchResult(null);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      submitDkgRound2: SubmitDkgRound2Response(success: EmptySuccess()),
    );
  }

  Future<RpcResponse> _sendDkgAcks(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.sendDkgAcks;
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.sendDkgAcks(
          sid: _sessionId(rpc.sid),
          acks: rpc.acks
              .map((ack) => SignedDkgAck.fromBytes(Uint8List.fromList(ack)))
              .toSet(),
        );
        return IrohDispatchResult(null);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      sendDkgAcks: SendDkgAcksResponse(success: EmptySuccess()),
    );
  }

  Future<RpcResponse> _requestDkgAcks(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.requestDkgAcks;
    final dispatched = await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        final acks = await handler.requestDkgAcks(
          sid: _sessionId(rpc.sid),
          requests: rpc.requests
              .map(
                (request) =>
                    DkgAckRequest.fromBytes(Uint8List.fromList(request)),
              )
              .toSet(),
        );
        return IrohDispatchResult(acks);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      requestDkgAcks: RequestDkgAcksResponse(
        acks: dispatched.value.map((ack) => ack.toBytes()),
      ),
    );
  }

  Future<RpcResponse> _requestSignatures(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.requestSignatures;
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.requestSignatures(
          sid: _sessionId(rpc.sid),
          keys: rpc.keys
              .map((key) => AggregateKeyInfo.fromBytes(Uint8List.fromList(key)))
              .toSet(),
          signedDetails: Signed<SignaturesRequestDetails>.fromBytes(
            Uint8List.fromList(rpc.signedDetails),
            (reader) => SignaturesRequestDetails.fromReader(reader),
          ),
          commitments: rpc.commitments
              .map(
                (commitment) =>
                    SigningCommitment.fromBytes(Uint8List.fromList(commitment)),
              )
              .toList(),
        );
        return IrohDispatchResult(null);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      requestSignatures: RequestSignaturesResponse(success: EmptySuccess()),
    );
  }

  Future<RpcResponse> _rejectSignaturesRequest(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.rejectSignaturesRequest;
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.rejectSignaturesRequest(
          sid: _sessionId(rpc.sid),
          reqId: SignaturesRequestId.fromBytes(Uint8List.fromList(rpc.reqId)),
        );
        return IrohDispatchResult(null);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      rejectSignaturesRequest: RejectSignaturesRequestResponse(
        success: EmptySuccess(),
      ),
    );
  }

  Future<RpcResponse> _submitSignatureReplies(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.submitSignatureReplies;
    final dispatched = await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        final response = await handler.submitSignatureReplies(
          sid: _sessionId(rpc.sid),
          reqId: SignaturesRequestId.fromBytes(Uint8List.fromList(rpc.reqId)),
          replies: rpc.replies
              .map(
                (reply) => SignatureReply.fromBytes(Uint8List.fromList(reply)),
              )
              .toList(),
        );
        return IrohDispatchResult(response);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      submitSignatureReplies: switch (dispatched.value) {
        SignatureNewRoundsResponse response => SubmitSignatureRepliesResponse(
          newRound: NewSignatureRound(data: response.toBytes()),
        ),
        SignaturesCompleteResponse response => SubmitSignatureRepliesResponse(
          completed: CompletedSignatures(data: response.toBytes()),
        ),
        null => SubmitSignatureRepliesResponse(noUpdate: NoSignatureUpdate()),
      },
    );
  }

  Future<RpcResponse> _shareSecretShare(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.shareSecretShare;
    final dispatched = await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        final events = await handler.shareSecretShare(
          sid: _sessionId(rpc.sid),
          groupKey: coinlib.ECCompressedPublicKey(
            Uint8List.fromList(rpc.groupKey),
          ),
          encryptedSecrets: {
            for (final secret in rpc.secrets)
              Identifier.fromBytes(
                Uint8List.fromList(secret.id),
              ): EncryptedKeyShare(
                ECCiphertext.fromBytes(Uint8List.fromList(secret.share)),
              ),
          },
        );
        return IrohDispatchResult(events);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      shareSecretShare: ShareSecretShareResponse(
        constructedKeyEvents: dispatched.value.map(
          event_wire.encodeConstructedKeyEvent,
        ),
      ),
    );
  }

  Future<RpcResponse> _ackKeyConstructed(RpcRequest request) async {
    final group = _readyGroup();
    final rpc = request.ackKeyConstructed;
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.ackKeyConstructed(
          sid: _sessionId(rpc.sid),
          constructedKey: Signed<KeyWasConstructed>.fromBytes(
            Uint8List.fromList(rpc.constructedKey),
            (reader) => KeyWasConstructed.fromReader(reader),
          ),
        );
        return IrohDispatchResult(null);
      },
    );
    return RpcResponse(
      requestId: request.requestId,
      ackKeyConstructed: AckKeyConstructedResponse(success: EmptySuccess()),
    );
  }

  Uint8List _readyGroup() {
    final group = context.groupFingerprint;
    if (group == null) throw StateError('connection is not authenticated');
    return group;
  }

  SessionID _sessionId(List<int> bytes) {
    final requested = SessionID.fromBytes(Uint8List.fromList(bytes));
    if (requested != context.sessionId) throw InvalidRequest.noSession();
    return requested;
  }

  Future<void> _handleStartSession(
    SendStream send,
    StreamIterator<Envelope> iterator,
  ) async {
    final group = context.groupFingerprint;
    if (group == null) throw StateError('connection is not authenticated');
    final started = await dispatcher
        .startSession(groupFingerprint: group, connection: context)
        .timeout(config.authTimeout);
    await _write(
      send,
      Envelope(wireVersion: noosphereIrohWireVersion, sessionStarted: started),
    );
    if (!await iterator.moveNext().timeout(config.authTimeout) ||
        iterator.current.whichPayload() != Envelope_Payload.ready) {
      throw StateError('expected Ready after SessionStarted');
    }
    final events = await dispatcher
        .ready(groupFingerprint: group, connection: context)
        .timeout(config.authTimeout);
    final controls = _handleSessionControls(iterator, group);
    final writingEvents = () async {
      await for (final event in events) {
        await _write(send, event);
      }
    }();
    final eventsEndedFirst = await Future.any([
      writingEvents.then((_) => true),
      controls.then((_) => false),
    ]);
    if (!eventsEndedFirst) await writingEvents;
  }

  Future<void> _handleSessionControls(
    StreamIterator<Envelope> iterator,
    List<int> group,
  ) async {
    while (await iterator.moveNext()) {
      switch (iterator.current.whichPayload()) {
        case Envelope_Payload.logout:
          await dispatcher.logout(groupFingerprint: group, connection: context);
          return;
        default:
          throw StateError('unexpected session control payload');
      }
    }
  }

  Future<void> _write(SendStream send, Envelope envelope) => send
      .writeAll(
        encodeEnvelope(envelope, maxEnvelopeLength: config.maxEnvelopeLength),
      )
      .timeout(config.rpcTimeout);

  Envelope _rpcError(
    List<int> requestId,
    ProtocolErrorCode code,
    String message,
  ) => Envelope(
    wireVersion: noosphereIrohWireVersion,
    rpcResponse: RpcResponse(
      requestId: requestId,
      error: ProtocolError(code: code, message: message),
    ),
  );

  Envelope _error(ProtocolErrorCode code, String message) => Envelope(
    wireVersion: noosphereIrohWireVersion,
    error: ProtocolError(code: code, message: message),
  );
}

Stream<List<int>> _readChunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(64 * 1024);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

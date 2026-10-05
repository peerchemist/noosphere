import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/api/types/dkg_ack_request.dart' as domain;
import 'package:noosphere/wire.dart';
import 'package:noosphere/domain.dart' hide DkgAckRequest;
import 'package:protobuf/protobuf.dart';

import '../config/iroh.dart';
import 'connection_context.dart';
import 'dispatcher.dart';

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
    final reader = QuicStreamReader(_readChunks(receive));
    var persistentResponse = false;
    try {
      final operationId = await reader.readVarInt().timeout(config.authTimeout);
      final body = await reader
          .readToEnd(maxLength: config.maxMessageLength)
          .timeout(config.rpcTimeout);
      final operation = RoastOperation.fromId(operationId);
      if (operation == null) {
        await _writeError(
          send,
          ProtocolError(
            code: ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
            message: 'unknown ROAST operation ID $operationId',
          ),
        );
      } else if (operation == RoastOperation.startSession) {
        StartSession.fromBuffer(body);
        persistentResponse = true;
        await _handleStartSession(send);
      } else {
        final timeout = switch (operation) {
          RoastOperation.login ||
          RoastOperation.respondToChallenge => config.authTimeout,
          _ => config.rpcTimeout,
        };
        await _handleRpc(send, operation, body).timeout(timeout);
      }
    } on Exception catch (error) {
      try {
        if (persistentResponse) {
          await send.reset(1);
        } else {
          await _writeError(send, _protocolError(error));
        }
      } on Exception {
        // The stream may already have been closed/reset by the peer.
      }
    } finally {
      try {
        await reader.cancel();
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

  Future<void> _handleRpc(
    SendStream send,
    RoastOperation operation,
    List<int> body,
  ) async {
    final GeneratedMessage response;
    try {
      response = switch (operation) {
        RoastOperation.login => await _login(LoginRequest.fromBuffer(body)),
        RoastOperation.respondToChallenge => await _authenticate(
          SignedAuthChallenge.fromBuffer(body),
        ),
        RoastOperation.extendSession => await _extendSession(
          Bytes.fromBuffer(body),
        ),
        RoastOperation.requestNewDkg => await _requestNewDkg(
          DkgRequest.fromBuffer(body),
        ),
        RoastOperation.rejectDkg => await _rejectDkg(
          DkgToReject.fromBuffer(body),
        ),
        RoastOperation.submitDkgCommitment => await _submitDkgCommitment(
          DkgCommitment.fromBuffer(body),
        ),
        RoastOperation.submitDkgRound2 => await _submitDkgRound2(
          DkgRound2.fromBuffer(body),
        ),
        RoastOperation.sendDkgAcks => await _sendDkgAcks(
          DkgAcks.fromBuffer(body),
        ),
        RoastOperation.requestDkgAcks => await _requestDkgAcks(
          DkgAckRequest.fromBuffer(body),
        ),
        RoastOperation.requestSignatures => await _requestSignatures(
          SignaturesRequest.fromBuffer(body),
        ),
        RoastOperation.rejectSignaturesRequest =>
          await _rejectSignaturesRequest(SignaturesRejection.fromBuffer(body)),
        RoastOperation.submitSignatureReplies => await _submitSignatureReplies(
          SignaturesReplies.fromBuffer(body),
        ),
        RoastOperation.shareSecretShare => await _shareSecretShare(
          SecretShare.fromBuffer(body),
        ),
        RoastOperation.ackKeyConstructed => await _ackKeyConstructed(
          ConstructedKey.fromBuffer(body),
        ),
        RoastOperation.startSession => throw StateError(
          'session operation reached RPC dispatcher',
        ),
      };
    } on Exception catch (error) {
      await _writeError(
        send,
        ProtocolError(
          code: ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
          message: '$error',
        ),
      );
      return;
    }
    await _writeResponse(send, response);
  }

  Future<LoginResponse> _login(LoginRequest login) async {
    final challenge = await dispatcher.beginAuthentication(
      groupFingerprint: login.groupFingerprint,
      participantId: Identifier.fromBytes(
        Uint8List.fromList(login.participantId),
      ),
      connection: context,
      protocolVersion: login.protocolVersion,
    );
    return LoginResponse(challenge: challenge.toBytes());
  }

  Future<RespondToChallengeResponse> _authenticate(
    SignedAuthChallenge signed,
  ) async {
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
    return RespondToChallengeResponse(authenticated: EmptySuccess());
  }

  Future<ExtendSessionResponse> _extendSession(Bytes request) async {
    final group = context.groupFingerprint;
    if (group == null) throw StateError('connection is not authenticated');
    final dispatched = await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        final expiry = await handler.extendSession(_sessionId(request.data));
        return IrohDispatchResult(expiry);
      },
    );
    return ExtendSessionResponse(expiry: dispatched.value.toBytes());
  }

  Future<RequestNewDkgResponse> _requestNewDkg(DkgRequest rpc) async {
    final group = _readyGroup();
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
    return RequestNewDkgResponse(success: EmptySuccess());
  }

  Future<RejectDkgResponse> _rejectDkg(DkgToReject rpc) async {
    final group = _readyGroup();
    await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        await handler.rejectDkg(sid: _sessionId(rpc.sid), name: rpc.name);
        return IrohDispatchResult(null);
      },
    );
    return RejectDkgResponse(success: EmptySuccess());
  }

  Future<SubmitDkgCommitmentResponse> _submitDkgCommitment(
    DkgCommitment rpc,
  ) async {
    final group = _readyGroup();
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
    return SubmitDkgCommitmentResponse(success: EmptySuccess());
  }

  Future<SubmitDkgRound2Response> _submitDkgRound2(DkgRound2 rpc) async {
    final group = _readyGroup();
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
    return SubmitDkgRound2Response(success: EmptySuccess());
  }

  Future<SendDkgAcksResponse> _sendDkgAcks(DkgAcks rpc) async {
    final group = _readyGroup();
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
    return SendDkgAcksResponse(success: EmptySuccess());
  }

  Future<RequestDkgAcksResponse> _requestDkgAcks(DkgAckRequest rpc) async {
    final group = _readyGroup();
    final dispatched = await dispatcher.invokeReady(
      groupFingerprint: group,
      connection: context,
      operation: (handler, _) async {
        final acks = await handler.requestDkgAcks(
          sid: _sessionId(rpc.sid),
          requests: rpc.requests
              .map(
                (request) =>
                    domain.DkgAckRequest.fromBytes(Uint8List.fromList(request)),
              )
              .toSet(),
        );
        return IrohDispatchResult(acks);
      },
    );
    return RequestDkgAcksResponse(
      acks: dispatched.value.map((ack) => ack.toBytes()),
    );
  }

  Future<RequestSignaturesResponse> _requestSignatures(
    SignaturesRequest rpc,
  ) async {
    final group = _readyGroup();
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
    return RequestSignaturesResponse(success: EmptySuccess());
  }

  Future<RejectSignaturesRequestResponse> _rejectSignaturesRequest(
    SignaturesRejection rpc,
  ) async {
    final group = _readyGroup();
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
    return RejectSignaturesRequestResponse(success: EmptySuccess());
  }

  Future<SubmitSignatureRepliesResponse> _submitSignatureReplies(
    SignaturesReplies rpc,
  ) async {
    final group = _readyGroup();
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
    return switch (dispatched.value) {
      SignatureNewRoundsResponse response => SubmitSignatureRepliesResponse(
        newRound: NewSignatureRound(data: response.toBytes()),
      ),
      SignaturesCompleteResponse response => SubmitSignatureRepliesResponse(
        completed: CompletedSignatures(data: response.toBytes()),
      ),
      null => SubmitSignatureRepliesResponse(noUpdate: NoSignatureUpdate()),
    };
  }

  Future<ShareSecretShareResponse> _shareSecretShare(SecretShare rpc) async {
    final group = _readyGroup();
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
    return ShareSecretShareResponse(
      constructedKeyEvents: dispatched.value.map(encodeConstructedKeyEvent),
    );
  }

  Future<AckKeyConstructedResponse> _ackKeyConstructed(
    ConstructedKey rpc,
  ) async {
    final group = _readyGroup();
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
    return AckKeyConstructedResponse(success: EmptySuccess());
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

  Future<void> _handleStartSession(SendStream send) async {
    final group = context.groupFingerprint;
    if (group == null) throw StateError('connection is not authenticated');
    final started = await dispatcher
        .startSession(groupFingerprint: group, connection: context)
        .timeout(config.authTimeout);
    final events = await dispatcher
        .ready(groupFingerprint: group, connection: context)
        .timeout(config.authTimeout);
    await _writePersistentMessage(send, started);
    await for (final event in events) {
      await _writePersistentMessage(send, event);
    }
  }

  Future<void> _writeResponse(
    SendStream send,
    GeneratedMessage response,
  ) async {
    final body = response.writeToBuffer();
    if (body.length > config.maxMessageLength) {
      throw FrameTooLargeException(
        length: body.length,
        maximum: config.maxMessageLength,
      );
    }
    await send
        .writeAll(encodeQuicVarInt(RpcResponseStatus.success))
        .timeout(config.rpcTimeout);
    await send.writeAll(body).timeout(config.rpcTimeout);
  }

  Future<void> _writeError(SendStream send, ProtocolError error) async {
    final body = error.writeToBuffer();
    await send
        .writeAll(encodeQuicVarInt(RpcResponseStatus.error))
        .timeout(config.rpcTimeout);
    await send.writeAll(body).timeout(config.rpcTimeout);
  }

  Future<void> _writePersistentMessage(
    SendStream send,
    GeneratedMessage message,
  ) => send
      .writeAll(
        encodeLengthPrefixedMessage(
          message.writeToBuffer(),
          maxMessageLength: config.maxMessageLength,
        ),
      )
      .timeout(config.rpcTimeout);

  ProtocolError _protocolError(Object error) => ProtocolError(
    code: switch (error) {
      FrameTooLargeException() =>
        ProtocolErrorCode.PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
      TimeoutException() => ProtocolErrorCode.PROTOCOL_ERROR_DEADLINE_EXCEEDED,
      _ => ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
    },
    message: '$error',
  );
}

Stream<List<int>> _readChunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(64 * 1024);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

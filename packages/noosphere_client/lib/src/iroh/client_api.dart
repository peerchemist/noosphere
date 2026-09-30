import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:frosty/frosty.dart';
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/noosphere.dart' as protocol;
import 'package:noosphere/noosphere.dart' show decodeEnvelopes, encodeEnvelope;
import 'package:noosphere/api/events.dart';
import 'package:noosphere/api/request_interface.dart';
import 'package:noosphere/api/responses/expirable_auth_challenge.dart';
import 'package:noosphere/api/responses/login_complete.dart';
import 'package:noosphere/api/responses/signatures.dart';
import 'package:noosphere/api/types/dkg_ack_request.dart';
import 'package:noosphere/api/types/dkg_encrypted_secret.dart';
import 'package:noosphere/api/types/encrypted_key_share.dart';
import 'package:noosphere/api/types/expiry.dart';
import 'package:noosphere/api/types/key_was_constructed.dart';
import 'package:noosphere/api/types/new_dkg_details.dart';
import 'package:noosphere/api/types/onetime_numbers.dart';
import 'package:noosphere/api/types/signature_reply.dart';
import 'package:noosphere/api/types/signatures_request_details.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/api/types/signed_dkg_ack.dart';
import 'package:noosphere/domain.dart' show noosphereRoastProtocolVersion;

import 'config.dart';
import 'endpoint.dart';

final class IrohProtocolException implements Exception {
  const IrohProtocolException(this.message, {this.error});

  final String message;
  final protocol.ProtocolError? error;

  @override
  String toString() => 'IrohProtocolException: $message';
}

final class IrohClientClosedException implements Exception {
  const IrohClientClosedException();

  @override
  String toString() => 'IrohClientClosedException';
}

/// Iroh implementation of authentication, session events, and domain RPCs.
final class IrohClientApi implements ApiRequestInterface {
  IrohClientApi._({
    required this.config,
    required this._endpoint,
    required this._connection,
  });

  static Future<IrohClientApi> connect(
    IrohClientTransportConfig config, {
    IrohClientEndpoint? endpoint,
  }) async {
    final wrapper = endpoint ?? await IrohClientEndpoint.bind(config);
    try {
      final connection = await wrapper.connect(config);
      return IrohClientApi._(
        config: config,
        endpoint: wrapper,
        connection: connection,
      );
    } catch (_) {
      if (endpoint == null) await wrapper.close();
      rethrow;
    }
  }

  final IrohClientTransportConfig config;
  final IrohClientEndpoint _endpoint;
  final Connection _connection;
  late final _AsyncSemaphore _rpcStreams = _AsyncSemaphore(
    config.maxConcurrentStreams,
  );
  SendStream? _sessionSend;
  bool _closed = false;
  Uint8List? _groupFingerprint;
  Identifier? _participantId;

  bool get isClosed => _closed;

  @override
  Future<ExpirableAuthChallengeResponse> login({
    required Uint8List groupFingerprint,
    required Identifier participantId,
    int protocolVersion = noosphereRoastProtocolVersion,
  }) async {
    final response = await _rpc(
      protocol.RpcRequest(
        login: protocol.LoginRequest(
          groupFingerprint: groupFingerprint,
          participantId: participantId.toBytes(),
          protocolVersion: protocolVersion,
        ),
      ),
      protocol.RpcResponse_Response.login,
      timeout: config.authTimeout,
    );
    _groupFingerprint = Uint8List.fromList(groupFingerprint);
    _participantId = participantId;
    return ExpirableAuthChallengeResponse.fromBytes(
      Uint8List.fromList(response.login.challenge),
    );
  }

  @override
  Future<LoginCompleteResponse> respondToChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) async {
    if (_groupFingerprint == null || _participantId == null) {
      throw StateError('login must be called before respondToChallenge');
    }
    await _rpc(
      protocol.RpcRequest(
        respondToChallenge: protocol.SignedAuthChallenge(
          challenge: signedChallenge.obj.toBytes(),
          signature: signedChallenge.signature.data,
        ),
      ),
      protocol.RpcResponse_Response.respondToChallenge,
      timeout: config.authTimeout,
    );

    final (send, receive) = await _connection.openBi();
    _sessionSend = send;
    await _write(
      send,
      protocol.Envelope(
        wireVersion: noosphereIrohWireVersion,
        startSession: protocol.StartSession(),
      ),
    );
    final iterator = StreamIterator(
      decodeEnvelopes(
        _readChunks(receive),
        maxEnvelopeLength: config.maxEnvelopeLength,
      ),
    );
    if (!await iterator.moveNext().timeout(config.authTimeout)) {
      throw const IrohProtocolException('session stream ended before snapshot');
    }
    final envelope = iterator.current;
    _validateEnvelope(envelope);
    if (envelope.whichPayload() != protocol.Envelope_Payload.sessionStarted) {
      throw IrohProtocolException(
        'expected SessionStarted, got ${envelope.whichPayload()}',
      );
    }

    late final StreamController<Event> events;
    events = StreamController<Event>(onCancel: () => logout());
    unawaited(_pumpEvents(iterator, events));
    await _write(
      send,
      protocol.Envelope(
        wireVersion: noosphereIrohWireVersion,
        ready: protocol.Ready(),
      ),
    );
    return LoginCompleteResponse.fromBytes(
      Uint8List.fromList(envelope.sessionStarted.snapshot),
      events.stream,
    );
  }

  Future<void> logout() async {
    if (_closed) return;
    _closed = true;
    final send = _sessionSend;
    if (send != null) {
      try {
        await _write(
          send,
          protocol.Envelope(
            wireVersion: noosphereIrohWireVersion,
            logout: protocol.Logout(),
          ),
        );
        await send.finish();
      } on Exception {
        // Connection loss is equivalent to logout from the caller's view.
      }
    }
    _connection.close(reason: 'client logout'.codeUnits);
    await _endpoint.close();
  }

  Future<void> close() => logout();

  Future<protocol.RpcResponse> _rpc(
    protocol.RpcRequest request,
    protocol.RpcResponse_Response expected, {
    Duration? timeout,
  }) async {
    if (_closed) throw const IrohClientClosedException();
    return _rpcStreams.run(() async {
      if (_closed) throw const IrohClientClosedException();
      final requestId = coinlib.generateRandomBytes(16);
      request.requestId = requestId;
      final (send, receive) = await _connection.openBi();
      try {
        await _write(
          send,
          protocol.Envelope(
            wireVersion: noosphereIrohWireVersion,
            rpcRequest: request,
          ),
        );
        await send.finish();
        final response = await decodeEnvelopes(
          _readChunks(receive),
          maxEnvelopeLength: config.maxEnvelopeLength,
        ).single.timeout(timeout ?? config.rpcTimeout);
        _validateEnvelope(response);
        if (response.whichPayload() != protocol.Envelope_Payload.rpcResponse) {
          throw IrohProtocolException(
            'expected RpcResponse, got ${response.whichPayload()}',
          );
        }
        final rpc = response.rpcResponse;
        if (!_sameBytes(rpc.requestId, requestId)) {
          throw const IrohProtocolException('response request_id mismatch');
        }
        if (rpc.whichResponse() == protocol.RpcResponse_Response.error) {
          throw IrohProtocolException(rpc.error.message, error: rpc.error);
        }
        if (rpc.whichResponse() != expected) {
          throw IrohProtocolException(
            'expected $expected, got ${rpc.whichResponse()}',
          );
        }
        return rpc;
      } on TimeoutException {
        await send.reset(1);
        await receive.stop(1);
        rethrow;
      }
    });
  }

  Future<void> _pumpEvents(
    StreamIterator<protocol.Envelope> iterator,
    StreamController<Event> output,
  ) async {
    try {
      while (await iterator.moveNext()) {
        final envelope = iterator.current;
        _validateEnvelope(envelope);
        switch (envelope.whichPayload()) {
          case protocol.Envelope_Payload.event:
            output.add(_decodeEvent(envelope.event));
          case protocol.Envelope_Payload.error:
            throw IrohProtocolException(
              envelope.error.message,
              error: envelope.error,
            );
          default:
            throw IrohProtocolException(
              'unexpected session payload ${envelope.whichPayload()}',
            );
        }
      }
    } catch (error, stackTrace) {
      if (!_closed) output.addError(error, stackTrace);
    } finally {
      await iterator.cancel();
      if (!output.isClosed) await output.close();
    }
  }

  Future<void> _write(SendStream send, protocol.Envelope envelope) =>
      send.writeAll(
        encodeEnvelope(envelope, maxEnvelopeLength: config.maxEnvelopeLength),
      );

  void _validateEnvelope(protocol.Envelope envelope) {
    if (envelope.wireVersion != noosphereIrohWireVersion) {
      throw IrohProtocolException(
        'unsupported wire version ${envelope.wireVersion}',
      );
    }
    if (envelope.whichPayload() == protocol.Envelope_Payload.error) {
      throw IrohProtocolException(
        envelope.error.message,
        error: envelope.error,
      );
    }
  }

  @override
  Future<Expiry> extendSession(SessionID sid) async {
    final response = await _rpc(
      protocol.RpcRequest(extendSession: protocol.Bytes(data: sid.toBytes())),
      protocol.RpcResponse_Response.extendSession,
    );
    return Expiry.fromBytes(Uint8List.fromList(response.extendSession.expiry));
  }

  @override
  Future<void> requestNewDkg({
    required SessionID sid,
    required Signed<NewDkgDetails> signedDetails,
    required DkgPublicCommitment commitment,
  }) async {
    await _rpc(
      protocol.RpcRequest(
        requestNewDkg: protocol.DkgRequest(
          sid: sid.toBytes(),
          signedDetails: signedDetails.toBytes(),
          commitment: commitment.toBytes(),
        ),
      ),
      protocol.RpcResponse_Response.requestNewDkg,
    );
  }

  @override
  Future<void> rejectDkg({required SessionID sid, required String name}) async {
    await _rpc(
      protocol.RpcRequest(
        rejectDkg: protocol.DkgToReject(sid: sid.toBytes(), name: name),
      ),
      protocol.RpcResponse_Response.rejectDkg,
    );
  }

  @override
  Future<void> submitDkgCommitment({
    required SessionID sid,
    required String name,
    required DkgPublicCommitment commitment,
  }) async {
    await _rpc(
      protocol.RpcRequest(
        submitDkgCommitment: protocol.DkgCommitment(
          sid: sid.toBytes(),
          name: name,
          commitment: commitment.toBytes(),
        ),
      ),
      protocol.RpcResponse_Response.submitDkgCommitment,
    );
  }

  @override
  Future<void> submitDkgRound2({
    required SessionID sid,
    required String name,
    required coinlib.SchnorrSignature commitmentSetSignature,
    required Map<Identifier, DkgEncryptedSecret> secrets,
  }) async {
    await _rpc(
      protocol.RpcRequest(
        submitDkgRound2: protocol.DkgRound2(
          sid: sid.toBytes(),
          name: name,
          commitmentSetSignature: commitmentSetSignature.data,
          secrets: secrets.entries.map(
            (entry) => protocol.DkgSecret(
              id: entry.key.toBytes(),
              secret: entry.value.ciphertext.toBytes(),
            ),
          ),
        ),
      ),
      protocol.RpcResponse_Response.submitDkgRound2,
    );
  }

  @override
  Future<void> sendDkgAcks({
    required SessionID sid,
    required Set<SignedDkgAck> acks,
  }) async {
    await _rpc(
      protocol.RpcRequest(
        sendDkgAcks: protocol.DkgAcks(
          sid: sid.toBytes(),
          acks: acks.map((ack) => ack.toBytes()),
        ),
      ),
      protocol.RpcResponse_Response.sendDkgAcks,
    );
  }

  @override
  Future<Set<SignedDkgAck>> requestDkgAcks({
    required SessionID sid,
    required Set<DkgAckRequest> requests,
  }) async {
    final response = await _rpc(
      protocol.RpcRequest(
        requestDkgAcks: protocol.DkgAckRequest(
          sid: sid.toBytes(),
          requests: requests.map((request) => request.toBytes()),
        ),
      ),
      protocol.RpcResponse_Response.requestDkgAcks,
    );
    return response.requestDkgAcks.acks
        .map((ack) => SignedDkgAck.fromBytes(Uint8List.fromList(ack)))
        .toSet();
  }

  @override
  Future<void> requestSignatures({
    required SessionID sid,
    required Set<AggregateKeyInfo> keys,
    required Signed<SignaturesRequestDetails> signedDetails,
    required List<SigningCommitment> commitments,
  }) async {
    await _rpc(
      protocol.RpcRequest(
        requestSignatures: protocol.SignaturesRequest(
          sid: sid.toBytes(),
          keys: keys.map((key) => key.toBytes()),
          signedDetails: signedDetails.toBytes(),
          commitments: commitments.map((commitment) => commitment.toBytes()),
        ),
      ),
      protocol.RpcResponse_Response.requestSignatures,
    );
  }

  @override
  Future<void> rejectSignaturesRequest({
    required SessionID sid,
    required SignaturesRequestId reqId,
  }) async {
    await _rpc(
      protocol.RpcRequest(
        rejectSignaturesRequest: protocol.SignaturesRejection(
          sid: sid.toBytes(),
          reqId: reqId.toBytes(),
        ),
      ),
      protocol.RpcResponse_Response.rejectSignaturesRequest,
    );
  }

  @override
  Future<SignaturesResponse?> submitSignatureReplies({
    required SessionID sid,
    required SignaturesRequestId reqId,
    required List<SignatureReply> replies,
  }) async {
    final response = await _rpc(
      protocol.RpcRequest(
        submitSignatureReplies: protocol.SignaturesReplies(
          sid: sid.toBytes(),
          reqId: reqId.toBytes(),
          replies: replies.map((reply) => reply.toBytes()),
        ),
      ),
      protocol.RpcResponse_Response.submitSignatureReplies,
    );
    final outcome = response.submitSignatureReplies;
    return switch (outcome.whichOutcome()) {
      protocol.SubmitSignatureRepliesResponse_Outcome.noUpdate => null,
      protocol.SubmitSignatureRepliesResponse_Outcome.newRound =>
        SignatureNewRoundsResponse.fromBytes(
          Uint8List.fromList(outcome.newRound.data),
        ),
      protocol.SubmitSignatureRepliesResponse_Outcome.completed =>
        SignaturesCompleteResponse.fromBytes(
          Uint8List.fromList(outcome.completed.data),
        ),
      protocol.SubmitSignatureRepliesResponse_Outcome.notSet =>
        throw const IrohProtocolException('signature response has no outcome'),
    };
  }

  @override
  Future<List<ConstructedKeyEvent>> shareSecretShare({
    required SessionID sid,
    required coinlib.ECCompressedPublicKey groupKey,
    required Map<Identifier, EncryptedKeyShare> encryptedSecrets,
  }) async {
    final response = await _rpc(
      protocol.RpcRequest(
        shareSecretShare: protocol.SecretShare(
          sid: sid.toBytes(),
          groupKey: groupKey.data,
          secrets: encryptedSecrets.entries.map(
            (entry) => protocol.EncryptedSecret(
              id: entry.key.toBytes(),
              share: entry.value.ciphertext.toBytes(),
            ),
          ),
        ),
      ),
      protocol.RpcResponse_Response.shareSecretShare,
    );
    return response.shareSecretShare.constructedKeyEvents
        .map(
          (event) => ConstructedKeyEvent.fromBytes(Uint8List.fromList(event)),
        )
        .toList();
  }

  @override
  Future<void> ackKeyConstructed({
    required SessionID sid,
    required Signed<KeyWasConstructed> constructedKey,
  }) async {
    await _rpc(
      protocol.RpcRequest(
        ackKeyConstructed: protocol.ConstructedKey(
          sid: sid.toBytes(),
          constructedKey: constructedKey.toBytes(),
        ),
      ),
      protocol.RpcResponse_Response.ackKeyConstructed,
    );
  }
}

final class _AsyncSemaphore {
  _AsyncSemaphore(this.maximum);

  final int maximum;
  final Queue<Completer<void>> _waiting = Queue();
  int _active = 0;

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_active >= maximum) {
      final permit = Completer<void>();
      _waiting.add(permit);
      await permit.future;
    }
    _active++;
    try {
      return await operation();
    } finally {
      _active--;
      if (_waiting.isNotEmpty) _waiting.removeFirst().complete();
    }
  }
}

Event _decodeEvent(protocol.Events event) {
  final bytes = Uint8List.fromList(event.data);
  return switch (event.type) {
    protocol.EventType.PARTICIPANT_STATUS_EVENT =>
      ParticipantStatusEvent.fromBytes(bytes),
    protocol.EventType.NEW_DKG_EVENT => NewDkgEvent.fromBytes(bytes),
    protocol.EventType.DKG_COMMITMENT_EVENT => DkgCommitmentEvent.fromBytes(
      bytes,
    ),
    protocol.EventType.DKG_REJECT_EVENT => DkgRejectEvent.fromBytes(bytes),
    protocol.EventType.DKG_ROUND2_SHARE_EVENT => DkgRound2ShareEvent.fromBytes(
      bytes,
    ),
    protocol.EventType.DKG_ACK_EVENT => DkgAckEvent.fromBytes(bytes),
    protocol.EventType.DKG_ACK_REQUEST_EVENT => DkgAckRequestEvent.fromBytes(
      bytes,
    ),
    protocol.EventType.SIG_REQ_EVENT => SignaturesRequestEvent.fromBytes(bytes),
    protocol.EventType.SIG_NEW_ROUNDS_EVENT =>
      SignatureNewRoundsEvent.fromBytes(bytes),
    protocol.EventType.SIG_COMPLETE_EVENT => SignaturesCompleteEvent.fromBytes(
      bytes,
    ),
    protocol.EventType.SIG_FAILURE_EVENT => SignaturesFailureEvent.fromBytes(
      bytes,
    ),
    protocol.EventType.SIG_PROGRESS_EVENT => SignaturesProgressEvent.fromBytes(
      bytes,
    ),
    protocol.EventType.SECRET_SHARE_EVENT => SecretShareEvent.fromBytes(bytes),
    protocol.EventType.CONSTRUCTED_KEY_EVENT => ConstructedKeyEvent.fromBytes(
      bytes,
    ),
    protocol.EventType.KEEPALIVE_EVENT => KeepaliveEvent(),
    _ => throw IrohProtocolException('unknown event type ${event.type}'),
  };
}

Stream<List<int>> _readChunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(64 * 1024);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

bool _sameBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

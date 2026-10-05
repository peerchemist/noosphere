import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:frosty/frosty.dart';
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/wire.dart' as protocol;
import 'package:protobuf/protobuf.dart';
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
      protocol.RoastOperation.login,
      protocol.LoginRequest(
        groupFingerprint: groupFingerprint,
        participantId: participantId.toBytes(),
        protocolVersion: protocolVersion,
      ),
      protocol.LoginResponse.fromBuffer,
      timeout: config.authTimeout,
    );
    _groupFingerprint = Uint8List.fromList(groupFingerprint);
    _participantId = participantId;
    return ExpirableAuthChallengeResponse.fromBytes(
      Uint8List.fromList(response.challenge),
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
      protocol.RoastOperation.respondToChallenge,
      protocol.SignedAuthChallenge(
        challenge: signedChallenge.obj.toBytes(),
        signature: signedChallenge.signature.data,
      ),
      protocol.RespondToChallengeResponse.fromBuffer,
      timeout: config.authTimeout,
    );

    final (send, receive) = await _connection.openBi();
    await _writeRequest(
      send,
      protocol.RoastOperation.startSession.id,
      protocol.StartSession(),
    );
    await send.finish();
    final iterator = StreamIterator(
      protocol.decodeLengthPrefixedMessages(
        _readChunks(receive),
        maxMessageLength: config.maxMessageLength,
      ),
    );
    if (!await iterator.moveNext().timeout(config.authTimeout)) {
      throw const IrohProtocolException('session stream ended before snapshot');
    }
    final started = protocol.SessionStarted.fromBuffer(iterator.current);

    late final StreamController<Event> events;
    events = StreamController<Event>(onCancel: () => logout());
    unawaited(_pumpEvents(iterator, events));
    return LoginCompleteResponse.fromBytes(
      Uint8List.fromList(started.snapshot),
      events.stream,
    );
  }

  Future<void> logout() async {
    if (_closed) return;
    _closed = true;
    _connection.close(reason: 'client logout'.codeUnits);
    await _endpoint.close();
  }

  Future<void> close() => logout();

  Future<T> _rpc<T extends GeneratedMessage>(
    protocol.RoastOperation operation,
    GeneratedMessage request,
    T Function(List<int>) decodeResponse, {
    Duration? timeout,
  }) async {
    if (_closed) throw const IrohClientClosedException();
    return _rpcStreams.run(() async {
      if (_closed) throw const IrohClientClosedException();
      final (send, receive) = await _connection.openBi();
      try {
        await _writeRequest(send, operation.id, request);
        await send.finish();
        final reader = protocol.QuicStreamReader(_readChunks(receive));
        final status = await reader.readVarInt().timeout(
          timeout ?? config.rpcTimeout,
        );
        final body = await reader
            .readToEnd(maxLength: config.maxMessageLength)
            .timeout(timeout ?? config.rpcTimeout);
        if (status == protocol.RpcResponseStatus.error) {
          final error = protocol.ProtocolError.fromBuffer(body);
          throw IrohProtocolException(error.message, error: error);
        }
        if (status != protocol.RpcResponseStatus.success) {
          throw IrohProtocolException('unknown response status $status');
        }
        return decodeResponse(body);
      } on TimeoutException {
        await send.reset(1);
        await receive.stop(1);
        rethrow;
      }
    });
  }

  Future<void> _pumpEvents(
    StreamIterator<Uint8List> iterator,
    StreamController<Event> output,
  ) async {
    try {
      while (await iterator.moveNext()) {
        output.add(
          protocol.decodeEvent(
            protocol.EventMessage.fromBuffer(iterator.current),
          ),
        );
      }
    } catch (error, stackTrace) {
      if (!_closed) output.addError(error, stackTrace);
    } finally {
      await iterator.cancel();
      if (!output.isClosed) await output.close();
    }
  }

  Future<void> _writeRequest(
    SendStream send,
    int operationId,
    GeneratedMessage request,
  ) async {
    final body = request.writeToBuffer();
    if (body.length > config.maxMessageLength) {
      throw protocol.FrameTooLargeException(
        length: body.length,
        maximum: config.maxMessageLength,
      );
    }
    await send.writeAll(protocol.encodeQuicVarInt(operationId));
    await send.writeAll(body);
  }

  @override
  Future<Expiry> extendSession(SessionID sid) async {
    final response = await _rpc(
      protocol.RoastOperation.extendSession,
      protocol.Bytes(data: sid.toBytes()),
      protocol.ExtendSessionResponse.fromBuffer,
    );
    return Expiry.fromBytes(Uint8List.fromList(response.expiry));
  }

  @override
  Future<void> requestNewDkg({
    required SessionID sid,
    required Signed<NewDkgDetails> signedDetails,
    required DkgPublicCommitment commitment,
  }) async {
    await _rpc(
      protocol.RoastOperation.requestNewDkg,
      protocol.DkgRequest(
        sid: sid.toBytes(),
        signedDetails: signedDetails.toBytes(),
        commitment: commitment.toBytes(),
      ),
      protocol.RequestNewDkgResponse.fromBuffer,
    );
  }

  @override
  Future<void> rejectDkg({required SessionID sid, required String name}) async {
    await _rpc(
      protocol.RoastOperation.rejectDkg,
      protocol.DkgToReject(sid: sid.toBytes(), name: name),
      protocol.RejectDkgResponse.fromBuffer,
    );
  }

  @override
  Future<void> submitDkgCommitment({
    required SessionID sid,
    required String name,
    required DkgPublicCommitment commitment,
  }) async {
    await _rpc(
      protocol.RoastOperation.submitDkgCommitment,
      protocol.DkgCommitment(
        sid: sid.toBytes(),
        name: name,
        commitment: commitment.toBytes(),
      ),
      protocol.SubmitDkgCommitmentResponse.fromBuffer,
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
      protocol.RoastOperation.submitDkgRound2,
      protocol.DkgRound2(
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
      protocol.SubmitDkgRound2Response.fromBuffer,
    );
  }

  @override
  Future<void> sendDkgAcks({
    required SessionID sid,
    required Set<SignedDkgAck> acks,
  }) async {
    await _rpc(
      protocol.RoastOperation.sendDkgAcks,
      protocol.DkgAcks(
        sid: sid.toBytes(),
        acks: acks.map((ack) => ack.toBytes()),
      ),
      protocol.SendDkgAcksResponse.fromBuffer,
    );
  }

  @override
  Future<Set<SignedDkgAck>> requestDkgAcks({
    required SessionID sid,
    required Set<DkgAckRequest> requests,
  }) async {
    final response = await _rpc(
      protocol.RoastOperation.requestDkgAcks,
      protocol.DkgAckRequest(
        sid: sid.toBytes(),
        requests: requests.map((request) => request.toBytes()),
      ),
      protocol.RequestDkgAcksResponse.fromBuffer,
    );
    return response.acks
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
      protocol.RoastOperation.requestSignatures,
      protocol.SignaturesRequest(
        sid: sid.toBytes(),
        keys: keys.map((key) => key.toBytes()),
        signedDetails: signedDetails.toBytes(),
        commitments: commitments.map((commitment) => commitment.toBytes()),
      ),
      protocol.RequestSignaturesResponse.fromBuffer,
    );
  }

  @override
  Future<void> rejectSignaturesRequest({
    required SessionID sid,
    required SignaturesRequestId reqId,
  }) async {
    await _rpc(
      protocol.RoastOperation.rejectSignaturesRequest,
      protocol.SignaturesRejection(sid: sid.toBytes(), reqId: reqId.toBytes()),
      protocol.RejectSignaturesRequestResponse.fromBuffer,
    );
  }

  @override
  Future<SignaturesResponse?> submitSignatureReplies({
    required SessionID sid,
    required SignaturesRequestId reqId,
    required List<SignatureReply> replies,
  }) async {
    final response = await _rpc(
      protocol.RoastOperation.submitSignatureReplies,
      protocol.SignaturesReplies(
        sid: sid.toBytes(),
        reqId: reqId.toBytes(),
        replies: replies.map((reply) => reply.toBytes()),
      ),
      protocol.SubmitSignatureRepliesResponse.fromBuffer,
    );
    final outcome = response;
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
      protocol.RoastOperation.shareSecretShare,
      protocol.SecretShare(
        sid: sid.toBytes(),
        groupKey: groupKey.data,
        secrets: encryptedSecrets.entries.map(
          (entry) => protocol.EncryptedSecret(
            id: entry.key.toBytes(),
            share: entry.value.ciphertext.toBytes(),
          ),
        ),
      ),
      protocol.ShareSecretShareResponse.fromBuffer,
    );
    return response.constructedKeyEvents
        .map(protocol.decodeConstructedKeyEvent)
        .toList();
  }

  @override
  Future<void> ackKeyConstructed({
    required SessionID sid,
    required Signed<KeyWasConstructed> constructedKey,
  }) async {
    await _rpc(
      protocol.RoastOperation.ackKeyConstructed,
      protocol.ConstructedKey(
        sid: sid.toBytes(),
        constructedKey: constructedKey.toBytes(),
      ),
      protocol.AckKeyConstructedResponse.fromBuffer,
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

Stream<List<int>> _readChunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(64 * 1024);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

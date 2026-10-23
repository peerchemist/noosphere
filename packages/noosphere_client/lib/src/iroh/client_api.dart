import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:frosty/frosty.dart';
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/api/events.dart';
import 'package:noosphere_protocol/api/request_interface.dart';
import 'package:noosphere_protocol/api/responses/expirable_auth_challenge.dart';
import 'package:noosphere_protocol/api/responses/login_complete.dart';
import 'package:noosphere_protocol/api/responses/signatures.dart';
import 'package:noosphere_protocol/api/types/dkg_ack_request.dart';
import 'package:noosphere_protocol/api/types/dkg_ceremony_snapshot.dart';
import 'package:noosphere_protocol/api/types/dkg_encrypted_secret.dart';
import 'package:noosphere_protocol/api/types/encrypted_key_share.dart';
import 'package:noosphere_protocol/api/types/expiry.dart';
import 'package:noosphere_protocol/api/types/key_was_constructed.dart';
import 'package:noosphere_protocol/api/types/new_dkg_details.dart';
import 'package:noosphere_protocol/api/types/onetime_numbers.dart';
import 'package:noosphere_protocol/api/types/signature_reply.dart';
import 'package:noosphere_protocol/api/types/signatures_request_details.dart';
import 'package:noosphere_protocol/api/types/signed.dart';
import 'package:noosphere_protocol/api/types/signed_dkg_ack.dart';
import 'package:noosphere_protocol/domain.dart' show noosphereProtocolVersion;
import 'package:noosphere_protocol/wire.dart' as protocol;
import 'package:protobuf/protobuf.dart';

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
    int protocolVersion = noosphereProtocolVersion,
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

    final body = _requestBody(protocol.StartSession());
    final deadline = _OperationDeadline(config.authTimeout);
    SendStream? send;
    RecvStream? receive;
    StreamIterator<Uint8List>? iterator;
    var requestFinished = false;
    try {
      (send, receive) = await deadline.run(_connection.openBi);
      await deadline.run(
        () =>
            _writeRequest(send!, protocol.RoastOperation.startSession.id, body),
      );
      await deadline.run(send!.finish);
      requestFinished = true;
      iterator = StreamIterator(
        protocol.decodeLengthPrefixedMessages(
          _readChunks(receive!),
          maxMessageLength: config.maxMessageLength,
        ),
      );
      if (!await deadline.run(iterator.moveNext)) {
        throw const IrohProtocolException(
          'session stream ended before snapshot',
        );
      }
      final started = protocol.SessionStarted.fromBuffer(iterator.current);

      late final StreamController<Event> events;
      events = StreamController<Event>(onCancel: () => logout());
      unawaited(_pumpEvents(iterator, events));
      return LoginCompleteResponse.fromBytes(
        Uint8List.fromList(started.snapshot),
        events.stream,
      );
    } on Object catch (error) {
      if (send == null || receive == null) {
        if (error is TimeoutException) {
          _connection.close(reason: 'session stream open timed out'.codeUnits);
        }
      } else {
        await _cleanupStream(
          send: send,
          receive: receive,
          readerCancel: iterator?.cancel,
          resetSend: !requestFinished,
          stopReceive: true,
          timeout: config.authTimeout,
        );
      }
      rethrow;
    }
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
    final body = _requestBody(request);
    return _rpcStreams.run(() async {
      if (_closed) throw const IrohClientClosedException();
      final operationTimeout = timeout ?? config.rpcTimeout;
      final deadline = _OperationDeadline(operationTimeout);
      SendStream? send;
      RecvStream? receive;
      protocol.QuicStreamReader? reader;
      var requestFinished = false;
      var responseFinished = false;
      try {
        (send, receive) = await deadline.run(_connection.openBi);
        await deadline.run(() => _writeRequest(send!, operation.id, body));
        await deadline.run(send!.finish);
        requestFinished = true;
        reader = protocol.QuicStreamReader(_readChunks(receive!));
        final status = await deadline.run(reader.readVarInt);
        final responseBody = await deadline.run(
          () => reader!.readToEnd(maxLength: config.maxMessageLength),
        );
        responseFinished = true;
        if (status == protocol.RpcResponseStatus.error) {
          final error = protocol.ProtocolError.fromBuffer(responseBody);
          throw IrohProtocolException(error.message, error: error);
        }
        if (status != protocol.RpcResponseStatus.success) {
          throw IrohProtocolException('unknown response status $status');
        }
        return decodeResponse(responseBody);
      } on Object catch (error) {
        if (send == null || receive == null) {
          if (error is TimeoutException) {
            _connection.close(reason: 'RPC stream open timed out'.codeUnits);
          }
        } else {
          await _cleanupStream(
            send: send,
            receive: receive,
            readerCancel: reader?.cancel,
            resetSend: !requestFinished,
            stopReceive: !responseFinished,
            timeout: operationTimeout,
          );
        }
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

  Uint8List _requestBody(GeneratedMessage request) {
    final body = request.writeToBuffer();
    if (body.length > config.maxMessageLength) {
      throw protocol.FrameTooLargeException(
        length: body.length,
        maximum: config.maxMessageLength,
      );
    }
    return body;
  }

  Future<void> _writeRequest(
    SendStream send,
    int operationId,
    List<int> body,
  ) async {
    await send.writeAll(protocol.encodeQuicVarInt(operationId));
    await send.writeAll(body);
  }

  Future<void> _cleanupStream({
    required SendStream send,
    required RecvStream receive,
    required Future<void> Function()? readerCancel,
    required bool resetSend,
    required bool stopReceive,
    required Duration timeout,
  }) async {
    Future<void> ignoreFailure(Future<void> operation) async {
      try {
        await operation;
      } on Object {
        // Preserve the request failure if the stream is already closed.
      }
    }

    final cleanup = () async {
      if (resetSend) await ignoreFailure(send.reset(1));
      if (stopReceive) await ignoreFailure(receive.stop(1));
      if (readerCancel != null) await ignoreFailure(readerCancel());
    }();
    final cleanupTimeout = timeout < const Duration(seconds: 1)
        ? timeout
        : const Duration(seconds: 1);
    try {
      await cleanup.timeout(cleanupTimeout);
    } on TimeoutException {
      _connection.close(reason: 'RPC stream cleanup timed out'.codeUnits);
    } on Object {
      _connection.close(reason: 'RPC stream cleanup failed'.codeUnits);
    }
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
  Future<void> rejectDkg({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
  }) async {
    await _rpc(
      protocol.RoastOperation.rejectDkg,
      protocol.DkgReference(
        sid: sid.toBytes(),
        name: name,
        ceremonyId: ceremonyId,
      ),
      protocol.RejectDkgResponse.fromBuffer,
    );
  }

  @override
  Future<void> submitDkgCommitment({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
    required DkgPublicCommitment commitment,
  }) async {
    await _rpc(
      protocol.RoastOperation.submitDkgCommitment,
      protocol.DkgCommitment(
        sid: sid.toBytes(),
        name: name,
        commitment: commitment.toBytes(),
        ceremonyId: ceremonyId,
      ),
      protocol.SubmitDkgCommitmentResponse.fromBuffer,
    );
  }

  @override
  Future<void> submitDkgRound2({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
    required coinlib.SchnorrSignature commitmentSetSignature,
    required Map<Identifier, DkgEncryptedSecret> secrets,
  }) async {
    await _rpc(
      protocol.RoastOperation.submitDkgRound2,
      protocol.DkgRound2(
        sid: sid.toBytes(),
        name: name,
        ceremonyId: ceremonyId,
        commitmentSetSignature: commitmentSetSignature.data,
        secrets: secrets.entries.map(
          (entry) => protocol.DkgSecret(
            id: entry.key.toBytes(),
            secret: entry.value.toBytes(),
          ),
        ),
      ),
      protocol.SubmitDkgRound2Response.fromBuffer,
    );
  }

  @override
  Future<DkgCeremonySnapshot?> getDkg({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
  }) async {
    final response = await _rpc(
      protocol.RoastOperation.getDkg,
      protocol.DkgReference(
        sid: sid.toBytes(),
        name: name,
        ceremonyId: ceremonyId,
      ),
      protocol.Bytes.fromBuffer,
    );
    return response.data.isEmpty
        ? null
        : DkgCeremonySnapshot.fromBytes(Uint8List.fromList(response.data));
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
  Future<CancelSignaturesRequestResponse> cancelSignaturesRequest({
    required SessionID sid,
    required SignaturesRequestId reqId,
  }) async {
    final protocol.CancelSignaturesRequestResponse response;
    try {
      response = await _rpc(
        protocol.RoastOperation.cancelSignaturesRequest,
        protocol.CancelSignaturesRequest(
          sessionId: sid.toBytes(),
          requestId: reqId.toBytes(),
        ),
        protocol.CancelSignaturesRequestResponse.fromBuffer,
      );
    } on IrohProtocolException catch (error) {
      if (error.error?.code ==
          protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST) {
        // A confirmed rejection (including authorization denial) has a known
        // outcome and must not trigger cancellation reconciliation.
        throw InvalidRequest(error.message);
      }
      rethrow;
    }
    if (!response.hasResult()) {
      throw const IrohProtocolException('cancellation response has no result');
    }
    final result = switch (response.result) {
      protocol.CancelSignaturesRequestResult.CANCEL_SIGNATURES_CANCELLED =>
        CancelSignaturesRequestResult.cancelled,
      protocol
          .CancelSignaturesRequestResult
          .CANCEL_SIGNATURES_ALREADY_CANCELLED =>
        CancelSignaturesRequestResult.alreadyCancelled,
      protocol
          .CancelSignaturesRequestResult
          .CANCEL_SIGNATURES_ALREADY_COMPLETED =>
        CancelSignaturesRequestResult.alreadyCompleted,
      protocol
          .CancelSignaturesRequestResult
          .CANCEL_SIGNATURES_ALREADY_TERMINAL =>
        CancelSignaturesRequestResult.alreadyTerminal,
      protocol.CancelSignaturesRequestResult.CANCEL_SIGNATURES_NOT_FOUND =>
        CancelSignaturesRequestResult.notFound,
      _ => throw const IrohProtocolException('unknown cancellation result'),
    };
    return CancelSignaturesRequestResponse(
      result,
      expiresAt: response.expiresAt.isEmpty
          ? null
          : Expiry.fromBytes(Uint8List.fromList(response.expiresAt)),
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

final class _OperationDeadline {
  _OperationDeadline(this.timeout) : _elapsed = (Stopwatch()..start());

  final Duration timeout;
  final Stopwatch _elapsed;

  Future<T> run<T>(Future<T> Function() operation) {
    final remaining = timeout - _elapsed.elapsed;
    if (remaining <= Duration.zero) {
      return Future.error(
        TimeoutException('Iroh operation timed out', timeout),
      );
    }
    return operation().timeout(remaining);
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

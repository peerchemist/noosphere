import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';

import '../iroh/dispatcher.dart';
import 'api_handler.dart';

/// In-process participant API for a group hosted by the same server instance.
///
/// Calls use the server dispatcher's per-group serial lane, so local and Iroh
/// participants observe the same state ordering. Authentication, sessions and
/// event delivery still use the ordinary domain API; only wire encoding and
/// QUIC transport are bypassed.
final class LocalCoordinatorApi implements ApiRequestInterface {
  LocalCoordinatorApi._(
    this._dispatcher,
    Uint8List groupFingerprint,
    this._onClose,
  ) : _groupFingerprint = Uint8List.fromList(groupFingerprint);

  static LocalCoordinatorApi attach({
    required IrohDispatcher dispatcher,
    required Uint8List groupFingerprint,
    required void Function(LocalCoordinatorApi api) onClose,
  }) {
    if (!dispatcher.hasGroup(groupFingerprint)) {
      throw const UnknownIrohGroupException();
    }
    return LocalCoordinatorApi._(dispatcher, groupFingerprint, onClose);
  }

  final IrohDispatcher _dispatcher;
  final Uint8List _groupFingerprint;
  final void Function(LocalCoordinatorApi api) _onClose;
  SessionID? _sessionId;
  bool _loginStarted = false;
  bool _closed = false;
  Future<void>? _closing;

  bool get isClosed => _closed;

  @override
  Future<ExpirableAuthChallengeResponse> login({
    required Uint8List groupFingerprint,
    required Identifier participantId,
    int protocolVersion = noosphereRoastProtocolVersion,
  }) {
    _ensureOpen();
    if (_loginStarted) throw StateError('login has already started');
    if (!_sameBytes(groupFingerprint, _groupFingerprint)) {
      throw InvalidRequest.groupMismatch();
    }
    _loginStarted = true;
    return _invoke(
      (handler) => handler.login(
        groupFingerprint: groupFingerprint,
        participantId: participantId,
        protocolVersion: protocolVersion,
      ),
    );
  }

  @override
  Future<LoginCompleteResponse> respondToChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) async {
    _ensureOpen();
    if (!_loginStarted || _sessionId != null) {
      throw StateError('login must precede challenge response');
    }
    final response = await _invoke(
      (handler) => handler.respondToChallenge(signedChallenge),
    );
    _sessionId = response.id;
    return response;
  }

  @override
  Future<Expiry> extendSession(SessionID sid) =>
      _ready(sid, (handler) => handler.extendSession(sid));

  @override
  Future<void> requestNewDkg({
    required SessionID sid,
    required Signed<NewDkgDetails> signedDetails,
    required DkgPublicCommitment commitment,
  }) => _ready(
    sid,
    (handler) => handler.requestNewDkg(
      sid: sid,
      signedDetails: signedDetails,
      commitment: commitment,
    ),
  );

  @override
  Future<void> rejectDkg({required SessionID sid, required String name}) =>
      _ready(sid, (handler) => handler.rejectDkg(sid: sid, name: name));

  @override
  Future<void> submitDkgCommitment({
    required SessionID sid,
    required String name,
    required DkgPublicCommitment commitment,
  }) => _ready(
    sid,
    (handler) => handler.submitDkgCommitment(
      sid: sid,
      name: name,
      commitment: commitment,
    ),
  );

  @override
  Future<void> submitDkgRound2({
    required SessionID sid,
    required String name,
    required cl.SchnorrSignature commitmentSetSignature,
    required Map<Identifier, DkgEncryptedSecret> secrets,
  }) => _ready(
    sid,
    (handler) => handler.submitDkgRound2(
      sid: sid,
      name: name,
      commitmentSetSignature: commitmentSetSignature,
      secrets: secrets,
    ),
  );

  @override
  Future<void> sendDkgAcks({
    required SessionID sid,
    required Set<SignedDkgAck> acks,
  }) => _ready(sid, (handler) => handler.sendDkgAcks(sid: sid, acks: acks));

  @override
  Future<Set<SignedDkgAck>> requestDkgAcks({
    required SessionID sid,
    required Set<DkgAckRequest> requests,
  }) => _ready(
    sid,
    (handler) => handler.requestDkgAcks(sid: sid, requests: requests),
  );

  @override
  Future<void> requestSignatures({
    required SessionID sid,
    required Set<AggregateKeyInfo> keys,
    required Signed<SignaturesRequestDetails> signedDetails,
    required List<SigningCommitment> commitments,
  }) => _ready(
    sid,
    (handler) => handler.requestSignatures(
      sid: sid,
      keys: keys,
      signedDetails: signedDetails,
      commitments: commitments,
    ),
  );

  @override
  Future<void> rejectSignaturesRequest({
    required SessionID sid,
    required SignaturesRequestId reqId,
  }) => _ready(
    sid,
    (handler) => handler.rejectSignaturesRequest(sid: sid, reqId: reqId),
  );

  @override
  Future<SignaturesResponse?> submitSignatureReplies({
    required SessionID sid,
    required SignaturesRequestId reqId,
    required List<SignatureReply> replies,
  }) => _ready(
    sid,
    (handler) => handler.submitSignatureReplies(
      sid: sid,
      reqId: reqId,
      replies: replies,
    ),
  );

  @override
  Future<List<ConstructedKeyEvent>> shareSecretShare({
    required SessionID sid,
    required cl.ECCompressedPublicKey groupKey,
    required Map<Identifier, EncryptedKeyShare> encryptedSecrets,
  }) => _ready(
    sid,
    (handler) => handler.shareSecretShare(
      sid: sid,
      groupKey: groupKey,
      encryptedSecrets: encryptedSecrets,
    ),
  );

  @override
  Future<void> ackKeyConstructed({
    required SessionID sid,
    required Signed<KeyWasConstructed> constructedKey,
  }) => _ready(
    sid,
    (handler) =>
        handler.ackKeyConstructed(sid: sid, constructedKey: constructedKey),
  );

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    final sessionId = _sessionId;
    _sessionId = null;
    try {
      if (sessionId != null && _dispatcher.hasGroup(_groupFingerprint)) {
        await _invoke((handler) async {
          final session = handler.sessionForTransport(sessionId);
          if (session != null) await handler.endSessionForTransport(session);
        }, allowClosed: true);
      }
    } finally {
      _onClose(this);
    }
  }

  Future<T> _ready<T>(
    SessionID sid,
    FutureOr<T> Function(ServerApiHandler handler) operation,
  ) {
    _ensureOpen();
    if (sid != _sessionId) throw InvalidRequest.noSession();
    return _invoke(operation);
  }

  Future<T> _invoke<T>(
    FutureOr<T> Function(ServerApiHandler handler) operation, {
    bool allowClosed = false,
  }) {
    if (!allowClosed) _ensureOpen();
    return _dispatcher.invokeGroup(
      groupFingerprint: _groupFingerprint,
      operation: operation,
    );
  }

  void _ensureOpen() {
    if (_closed) throw StateError('local coordinator API is closed');
  }
}

bool _sameBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

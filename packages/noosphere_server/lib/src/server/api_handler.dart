import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:noosphere_server/src/config/server.dart';
import 'package:noosphere_server/src/server/state/key_sharing.dart';
import 'package:meta/meta.dart';

import 'state/signatures_coordination.dart';
import 'state/client_session.dart';
import 'state/dkg.dart';
import 'state/state.dart';
import 'persistence.dart';

part 'api_sessions.dart';
part 'api_dkg.dart';
part 'api_signing.dart';
part 'api_key_sharing.dart';

/// Provides the logic of the server, implementing the [ApiRequestInterface].
/// Throws an [InvalidRequest] when the server cannot satisfy the request.
///
/// There is no anti-DoS protection.
///
/// The methods should be called sequentially without concurrency.
class ServerApiHandler implements ApiRequestInterface {
  static const currentProtocolVersion = noosphereRoastProtocolVersion;

  final ServerConfig config;
  final ServerState _state;
  late ServerStateSnapshot _publishedState = _state.snapshot();
  ServerStateSnapshot get state => _publishedState;

  @visibleForTesting
  ServerState get debugState => _state;

  ClientSession? sessionForTransport(SessionID id) => _state.clientSessions[id];

  Future<void> endSessionForTransport(ClientSession session) =>
      _endSession(session);

  Future<void> _endSession(ClientSession session) async {
    await _prepare();
    if (!_state.endSession(session, publish: false)) return;
    await _persist();
    _state.publishSessionEnded(session);
  }

  final ServerPersistence persistence;
  final DateTime startTime = DateTime.now();
  late final Future<void> ready = _restore();
  bool _writeOutcomeUnknown = false;

  ServerApiHandler({
    required this.config,
    required this.persistence,
    ServerState? state,
  }) : _state = state ?? ServerState();

  Future<void> _restore() async {
    final snapshot = await persistence.load(config.group.id);
    if (snapshot == null) {
      final initial = _state.snapshot();
      await persistence.write(config.group.id, initial);
      _publishedState = initial;
      return;
    }
    if (_state.restore(snapshot)) {
      // Recovery status is durable before the handler accepts requests, so
      // delayed messages from pre-restart attempts cannot revive them.
      final recovered = _state.snapshot();
      await persistence.write(config.group.id, recovered);
      _publishedState = recovered;
    } else {
      _publishedState = snapshot;
    }
  }

  Future<void> _prepare() async {
    await ready;
    if (_writeOutcomeUnknown) {
      throw StateError(
        'Server persistence outcome is unknown; recreate the handler.',
      );
    }
    await _expireSessions();
    await _expirePersistentState();
  }

  Future<void> _expireSessions() async {
    final expired = _state.clientSessions.removeExpired();
    if (expired.isEmpty) return;
    final ended = <ClientSession>[];
    for (final entry in expired) {
      if (_state.endSession(entry.value, publish: false)) {
        ended.add(entry.value);
      }
    }
    if (ended.isEmpty) return;
    await _persist();
    for (final session in ended) {
      _state.publishSessionEnded(session);
    }
  }

  Future<void> _expirePersistentState() async {
    var changed = false;
    changed = _state.nameToDkg.removeExpired().isNotEmpty || changed;
    changed = _state.sigRequests.removeExpired().isNotEmpty || changed;
    changed = _state.completedSigs.removeExpired().isNotEmpty || changed;
    final interruptedBefore = _state.persistent.interruptedDkgs.length;
    _state.persistent.interruptedDkgs.removeWhere(
      (_, event) => event.expiry.isExpired,
    );
    changed =
        _state.persistent.interruptedDkgs.length != interruptedBefore ||
        changed;
    final blockedBefore = _state.persistent.blockedSignatures.length;
    _state.persistent.blockedSignatures.removeWhere(
      (_, event) => event.expiry.isExpired,
    );
    changed =
        _state.persistent.blockedSignatures.length != blockedBefore || changed;
    if (changed) await _persist();
  }

  Future<void> _persist() async {
    final next = _state.snapshot();
    try {
      await persistence.write(config.group.id, next);
    } catch (_) {
      _writeOutcomeUnknown = true;
      rethrow;
    }
    _publishedState = next;
  }

  int get _participantN => config.group.participants.length;

  ClientSession getSession(SessionID id) {
    final session = _state.clientSessions[id];
    if (session == null) throw InvalidRequest.noSession();
    return session;
  }

  cl.ECPublicKey _getParticipantPubkeyForId(Identifier id) {
    final pubkey = config.group.participants[id];
    if (pubkey == null) throw InvalidRequest.noParticipant();
    return pubkey;
  }

  cl.ECPublicKey _getParticipantPubkeyForSession(ClientSession session) =>
      _getParticipantPubkeyForId(session.participantId);

  void _checkParticipantId(Identifier id) => _getParticipantPubkeyForId(id);

  DkgState _getDkg(String name) {
    final dkg = _state.nameToDkg[name];
    if (dkg == null) throw InvalidRequest.noDkg();
    return dkg;
  }

  void _verifyExpiry(Expiry expiry, Duration minTTL, Duration maxTTL) {
    if (expiry.ttl.compareTo(minTTL) < 0) throw InvalidRequest.expiryTooSoon();
    if (expiry.ttl.compareTo(maxTTL) > 0) throw InvalidRequest.expiryTooLate();
  }

  @override
  Future<ExpirableAuthChallengeResponse> login({
    required Uint8List groupFingerprint,
    required Identifier participantId,
    int protocolVersion = currentProtocolVersion,
  }) => _login(
    groupFingerprint: groupFingerprint,
    participantId: participantId,
    protocolVersion: protocolVersion,
  );

  @override
  Future<LoginCompleteResponse> respondToChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) => _respondToChallenge(signedChallenge);

  /// Verifies and consumes a challenge without creating a session.
  Future<Identifier> verifyChallenge(Signed<AuthChallenge> signedChallenge) =>
      _verifyChallenge(signedChallenge);

  /// Creates a fresh logical session for an authenticated participant.
  Future<LoginCompleteResponse> startSession(Identifier pid) =>
      _startSession(pid);

  @override
  Future<Expiry> extendSession(SessionID sid) => _extendSession(sid);

  @override
  Future<void> requestNewDkg({
    required SessionID sid,
    required Signed<NewDkgDetails> signedDetails,
    required DkgPublicCommitment commitment,
  }) => _requestNewDkg(
    sid: sid,
    signedDetails: signedDetails,
    commitment: commitment,
  );

  @override
  Future<void> rejectDkg({required SessionID sid, required String name}) =>
      _rejectDkg(sid: sid, name: name);

  @override
  Future<void> submitDkgCommitment({
    required SessionID sid,
    required String name,
    required DkgPublicCommitment commitment,
  }) => _submitDkgCommitment(sid: sid, name: name, commitment: commitment);

  @override
  Future<void> submitDkgRound2({
    required SessionID sid,
    required String name,
    required cl.SchnorrSignature commitmentSetSignature,
    required Map<Identifier, DkgEncryptedSecret> secrets,
  }) => _submitDkgRound2(
    sid: sid,
    name: name,
    commitmentSetSignature: commitmentSetSignature,
    secrets: secrets,
  );

  @override
  Future<void> sendDkgAcks({
    required SessionID sid,
    required Set<SignedDkgAck> acks,
  }) => _sendDkgAcks(sid: sid, acks: acks);

  @override
  Future<Set<SignedDkgAck>> requestDkgAcks({
    required SessionID sid,
    required Set<DkgAckRequest> requests,
  }) => _requestDkgAcks(sid: sid, requests: requests);

  @override
  Future<void> requestSignatures({
    required SessionID sid,
    required Set<AggregateKeyInfo> keys,
    required Signed<SignaturesRequestDetails> signedDetails,
    required List<SigningCommitment> commitments,
  }) => _requestSignatures(
    sid: sid,
    keys: keys,
    signedDetails: signedDetails,
    commitments: commitments,
  );

  @override
  Future<void> rejectSignaturesRequest({
    required SessionID sid,
    required SignaturesRequestId reqId,
  }) => _rejectSignaturesRequest(sid: sid, reqId: reqId);

  @override
  Future<SignaturesResponse?> submitSignatureReplies({
    required SessionID sid,
    required SignaturesRequestId reqId,
    required List<SignatureReply> replies,
  }) => _submitSignatureReplies(sid: sid, reqId: reqId, replies: replies);

  @override
  Future<List<ConstructedKeyEvent>> shareSecretShare({
    required SessionID sid,
    required cl.ECCompressedPublicKey groupKey,
    required Map<Identifier, EncryptedKeyShare> encryptedSecrets,
  }) => _shareSecretShare(
    sid: sid,
    groupKey: groupKey,
    encryptedSecrets: encryptedSecrets,
  );

  @override
  Future<void> ackKeyConstructed({
    required SessionID sid,
    required Signed<KeyWasConstructed> constructedKey,
  }) => _ackKeyConstructed(sid: sid, constructedKey: constructedKey);

  /// Closes all client session streams
  Future<void> shutdown() => Future.wait(
    _state.clientSessions.values.map(
      (session) => session.eventController.close(),
    ),
  );
}

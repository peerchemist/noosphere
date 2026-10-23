import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:noosphere_protocol/domain.dart';
import 'package:noosphere_protocol/public_feed.dart';
import 'package:noosphere_server/src/config/server.dart';
import 'package:noosphere_server/src/server/state/key_sharing.dart';

import 'persistence.dart';
import 'state/client_session.dart';
import 'state/dkg.dart';
import 'state/signatures_coordination.dart';
import 'state/state.dart';

part 'api_dkg.dart';
part 'api_key_sharing.dart';
part 'api_sessions.dart';
part 'api_signing.dart';

typedef _PublicFeedView = ({List<PublicFeedEntry> entries, int latestCursor});

/// Provides the logic of the server, implementing the [ApiRequestInterface].
/// Throws an [InvalidRequest] when the server cannot satisfy the request.
///
/// Authenticated DKG creation and retained payloads are bounded by
/// [ServerConfig]. Transport-level connection limits are enforced separately.
///
/// The methods should be called sequentially without concurrency.
class ServerApiHandler implements ApiRequestInterface {
  static const currentProtocolVersion = noosphereProtocolVersion;

  final ServerConfig config;
  final ServerState _state;
  late ServerStateSnapshot _publishedState = _state.snapshot();
  ServerStateSnapshot get state => _publishedState;
  // Immutable committed view; never expose an in-flight or failed write.
  _PublicFeedView? _committedFeed;

  /// No _prepare, session creation, expiration, or protocol mutation on reads.
  Future<PublicFeedPage?> getPublicFeed(
    PublicFeedId feedId,
    int afterCursor,
    int limit,
  ) async {
    await ready;
    if (config.publicFeed?.feedId != feedId || _writeOutcomeUnknown) {
      return null;
    }
    final committed = _committedFeed;
    if (committed == null) return null;
    RangeError.checkValueInInterval(
      afterCursor,
      0,
      publicFeedMaxCursor,
      'afterCursor',
    );
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(config.publicFeed!.maxAge);
    // Retain a cursor-contiguous suffix even if the wall clock moves backward.
    final retained = committed.entries.skipWhile(
      (e) => e.observedAt.isBefore(cutoff),
    );
    final oldest = retained.firstOrNull?.cursor ?? committed.latestCursor + 1;
    final entries = retained
        .where((e) => e.cursor > afterCursor)
        .take(limit.clamp(1, publicFeedMaxPageEntries))
        .toList();
    final next =
        entries.lastOrNull?.cursor ?? max(afterCursor, committed.latestCursor);
    return PublicFeedPage(
      feedId: feedId,
      entries: entries,
      oldestAvailableCursor: oldest,
      latestCursor: committed.latestCursor,
      nextCursor: next,
      hasMore: next < committed.latestCursor,
      historyGap: afterCursor < oldest - 1,
      generatedAt: now,
      afterCursor: afterCursor,
    );
  }

  _PublicFeedView? _captureFeed() {
    final feed = _state.persistent.publicFeed;
    return feed == null
        ? null
        : (
            entries: List.unmodifiable(feed.entries),
            latestCursor: feed.nextCursor - 1,
          );
  }

  void _publish(ServerStateSnapshot snapshot, _PublicFeedView? feed) {
    _publishedState = snapshot;
    _committedFeed = feed;
  }

  @visibleForTesting
  ServerState get debugState => _state;

  Future<void> Function(ClientSession session)? _sessionLostHandler;

  @internal
  void attachSessionLostHandler(
    Future<void> Function(ClientSession session) handler,
  ) {
    if (_sessionLostHandler != null) {
      throw StateError('server handler already has a session owner');
    }
    _sessionLostHandler = handler;
  }

  @internal
  void detachSessionLostHandler() => _sessionLostHandler = null;

  Future<void> _handleLostSession(ClientSession session) =>
      _sessionLostHandler?.call(session) ?? _endSession(session);

  ClientSession? sessionForTransport(SessionID id) => _state.clientSessions[id];

  Future<void> endSessionForTransport(ClientSession session) =>
      _endSession(session);

  Future<void> _endSession(ClientSession session) async {
    await ready;
    if (_writeOutcomeUnknown) {
      // Closing a transport must remain possible after a write failed closed.
      // Only discard runtime authentication; do not mutate protocol state or
      // publish events based on an unknown durable outcome.
      session.end();
      _state.clientSessions.remove(session.sessionID);
      if (identical(
        _state.participantToSession[session.participantId],
        session,
      )) {
        _state.participantToSession.remove(session.participantId);
      }
      return;
    }
    await _prepare();
    if (!_state.endSession(session, publish: false)) return;
    _state.publishSessionEnded(session);
  }

  final ServerPersistence persistence;
  final DateTime startTime = DateTime.now();
  late final Future<void> ready = _restore();
  bool _writeOutcomeUnknown = false;
  Future<void> _writing = Future.value();

  ServerApiHandler({
    required this.config,
    required this.persistence,
    ServerState? state,
  }) : _state = state ?? ServerState();

  Future<void> _restore() async {
    final snapshot = await persistence.load(config.group.id);
    if (snapshot == null) {
      _state.configurePublicFeed(config.publicFeed);
      final initial = _state.snapshot();
      await persistence.write(config.group.id, initial);
      _publish(initial, _captureFeed());
      return;
    }
    if (_state.restore(snapshot, config: config)) {
      // Recovery status is durable before the handler accepts requests, so
      // delayed messages from pre-restart attempts cannot revive them.
      final recovered = _state.snapshot();
      await persistence.write(config.group.id, recovered);
      _publish(recovered, _captureFeed());
    } else {
      _publish(snapshot, _captureFeed());
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
    for (final session in ended) {
      _state.publishSessionEnded(session);
    }
  }

  Future<void> _expirePersistentState() async {
    var changed = false;
    final expiredDkgs = _state.nameToDkg.removeExpired();
    for (final entry in expiredDkgs) {
      _retainTerminalDkg(entry.value);
      _state.persistent.publicFeed?.finish(
        'dkg:${entry.key}',
        PublicFeedLifecycle.expired,
      );
    }
    changed = expiredDkgs.isNotEmpty || changed;
    final terminalDkgBefore = _state.persistent.terminalDkgs.length;
    _state.persistent.terminalDkgs.removeWhere(
      (_, value) => value.expiry.isExpired,
    );
    changed =
        _state.persistent.terminalDkgs.length != terminalDkgBefore || changed;
    final expiredSigning = _state.sigRequests.removeExpired();
    for (final entry in expiredSigning) {
      _state.persistent.publicFeed?.finish(
        'signing:${entry.key}',
        PublicFeedLifecycle.expired,
      );
    }
    changed = expiredSigning.isNotEmpty || changed;
    changed = _state.completedSigs.removeExpired().isNotEmpty || changed;
    changed =
        _state.persistent.cancelledSignatures.removeExpired().isNotEmpty ||
        changed;
    final terminalBefore = _state.persistent.terminalSignatures.length;
    _state.persistent.terminalSignatures.removeWhere(
      (_, value) => value.expiry.isExpired,
    );
    changed =
        _state.persistent.terminalSignatures.length != terminalBefore ||
        changed;
    final blockedBefore = _state.persistent.blockedSignatures.length;
    _state.persistent.blockedSignatures.removeWhere(
      (_, event) => event.expiry.isExpired,
    );
    changed =
        _state.persistent.blockedSignatures.length != blockedBefore || changed;
    changed = (_state.persistent.publicFeed?.expire() ?? false) || changed;
    changed = (_state.persistent.publicFeed?.prune() ?? false) || changed;
    if (changed) await _persist();
  }

  /// Called by the coordinator's serial maintenance lane, independently of
  /// public polling. Standalone API hosts may also schedule this method.
  Future<void> maintainPublicFeed() async {
    await ready;
    if (_writeOutcomeUnknown) return;
    await _expirePersistentState();
  }

  Future<void> _persist() async {
    // Lost-session callbacks can arrive outside the transport's serial lane.
    // Keep host writes in capture order, and publish exactly the view that was
    // captured with this snapshot, even if another callback has since run.
    final preceding = _writing;
    final completed = Completer<void>();
    _writing = completed.future;
    try {
      // Live state has already changed. Capture failures must fail closed too,
      // even when no host write has begun.
      final next = _state.snapshot();
      final feed = _captureFeed();
      await preceding;
      if (_writeOutcomeUnknown) {
        throw StateError('Server persistence outcome is unknown');
      }
      await persistence.write(config.group.id, next);
      _publish(next, feed);
    } catch (_) {
      _writeOutcomeUnknown = true;
      rethrow;
    } finally {
      completed.complete();
    }
  }

  int get _participantN => config.group.participants.length;

  void _admitRequestRate(
    Map<Identifier, List<DateTime>> times,
    Identifier participant,
    int maximum,
  ) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 1));
    final requests = times.putIfAbsent(participant, () => []);
    requests.removeWhere((time) => !time.isAfter(cutoff));
    if (requests.length >= maximum) {
      throw InvalidRequest('Request rate exceeded');
    }
    requests.add(now);
  }

  void _checkDkgAdmission(Identifier creator) {
    if (_state.nameToDkg.values.length >= ServerConfig.maxActiveDkgs) {
      throw InvalidRequest.dkgCapacityExceeded();
    }

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 1));
    final requests = _state.runtime.dkgRequestTimes[creator] ??= [];
    requests.removeWhere((time) => !time.isAfter(cutoff));
    if (requests.length >= ServerConfig.maxDkgRequestsPerMinute) {
      throw InvalidRequest.dkgRateLimited();
    }
    requests.add(now);
  }

  void _requireDkgStateWithinLimit() {
    if (_state.dkgPayloadBytes > ServerConfig.maxDkgStateBytes) {
      throw InvalidRequest.dkgCapacityExceeded();
    }
  }

  String _dkgCeremonyKey(Uint8List ceremonyId) => cl.bytesToHex(ceremonyId);

  void _retainTerminalDkg(DkgState dkg) {
    // Every accepted proposal expires within maxDkgRequestTTL, so retaining
    // its ID for that duration makes replay impossible until its signature is
    // also unusable by the normal expiry checks.
    final key = _dkgCeremonyKey(dkg.details.obj.ceremonyId);
    _state.persistent.terminalDkgs[key] = FinalExpirable(
      Expiry(config.maxDkgRequestTTL),
    );
  }

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

  DkgState _getDkgForCeremony(String name, Uint8List ceremonyId) {
    final dkg = _getDkg(name);
    if (!cl.bytesEqual(dkg.details.obj.ceremonyId, ceremonyId)) {
      throw InvalidRequest.noDkg();
    }
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
  Future<void> rejectDkg({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
  }) => _rejectDkg(sid: sid, name: name, ceremonyId: ceremonyId);

  @override
  Future<void> submitDkgCommitment({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
    required DkgPublicCommitment commitment,
  }) => _submitDkgCommitment(
    sid: sid,
    name: name,
    ceremonyId: ceremonyId,
    commitment: commitment,
  );

  @override
  Future<void> submitDkgRound2({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
    required cl.SchnorrSignature commitmentSetSignature,
    required Map<Identifier, DkgEncryptedSecret> secrets,
  }) => _submitDkgRound2(
    sid: sid,
    name: name,
    ceremonyId: ceremonyId,
    commitmentSetSignature: commitmentSetSignature,
    secrets: secrets,
  );

  @override
  Future<DkgCeremonySnapshot?> getDkg({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
  }) => _getDkgSnapshot(sid: sid, name: name, ceremonyId: ceremonyId);

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
  Future<CancelSignaturesRequestResponse> cancelSignaturesRequest({
    required SessionID sid,
    required SignaturesRequestId reqId,
  }) => _cancelSignaturesRequest(sid: sid, reqId: reqId);

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

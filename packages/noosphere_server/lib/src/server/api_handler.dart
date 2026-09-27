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
  }) async {
    await _prepare();
    // Only accept the current development protocol.
    if (protocolVersion != currentProtocolVersion) {
      throw InvalidRequest.invalidProtoVersion();
    }

    // Check fingerprint
    if (!cl.bytesEqual(groupFingerprint, config.group.fingerprint)) {
      throw InvalidRequest.groupMismatch();
    }

    _checkParticipantId(participantId);

    // Create challenge
    final challenge = AuthChallenge();
    final expiry = Expiry(config.challengeTTL);

    _state.challenges[challenge] = ChallengeDetails(
      id: participantId,
      expiry: expiry,
    );

    return ExpirableAuthChallengeResponse(challenge: challenge, expiry: expiry);
  }

  @override
  Future<LoginCompleteResponse> respondToChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) async {
    final participant = await verifyChallenge(signedChallenge);
    return startSession(participant);
  }

  /// Verifies and consumes a challenge without creating a session.
  Future<Identifier> verifyChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) async {
    await _prepare();
    // Get participant id for challenge and check expiry
    final details = _state.challenges[signedChallenge.obj];
    if (details == null) throw InvalidRequest.noChallenge();
    final pid = details.id;

    // Verify participant has signed the challenge
    if (!signedChallenge.verify(_getParticipantPubkeyForId(pid))) {
      throw InvalidRequest.invalidChallengeSig();
    }

    // Success

    // Remove challenge
    _state.challenges.remove(signedChallenge.obj);

    return pid;
  }

  /// Creates a fresh logical session for an already authenticated participant.
  /// Legacy gRPC calls this immediately after challenge verification; Iroh
  /// calls it only after receiving StartSession.
  Future<LoginCompleteResponse> startSession(Identifier pid) async {
    await _prepare();
    _checkParticipantId(pid);

    // Remove any old session
    final oldSession = _state.participantToSession[pid];
    if (oldSession != null) {
      await _endSession(oldSession);
    }

    // Obtain other logged in participants
    final online = _state.clientSessions.values
        .map((sess) => sess.participantId)
        .toSet();

    // Notify other sessions of login before new session is added
    _state.sendEventToAll(ParticipantStatusEvent(id: pid, loggedIn: true));

    // Create session
    final sessionId = SessionID();
    final expiry = Expiry(config.sessionTTL);

    late final ClientSession session;
    session = _state.participantToSession[pid] =
        _state.clientSessions[sessionId] = ClientSession(
          participantId: pid,
          sessionID: sessionId,
          expiry: expiry,
          // When the session stream is lost, remove the session and process the
          // logout immediately
          onLostStream: () {
            unawaited(_endSession(session));
          },
        );

    // If using keepalive, send periodic events
    if (config.keepAliveFreq != null) {
      Timer.periodic(config.keepAliveFreq!, (timer) {
        final session = _state.clientSessions[sessionId];
        if (session == null) timer.cancel();
        session?.sendEvent(KeepaliveEvent());
      });
    }

    return LoginCompleteResponse(
      id: sessionId,
      expiry: expiry,
      startTime: startTime,
      onlineParticipants: online,
      events: session.eventController.stream,

      newDkgs: _state.round1Dkgs
          .map(
            (dkg) => NewDkgEvent(
              details: dkg.details,
              creator: dkg.creator,
              commitments: dkg.round1.commitments,
            ),
          )
          .toList(),

      sigRequests: _state.sigRequests.values
          .map(
            (sig) => SignaturesRequestEvent(
              details: sig.details,
              creator: sig.creator,
            ),
          )
          .toList(),

      // Find rounds that the user is part of and hasn't provided a share yet
      sigRounds: _state.sigRequests.values
          .map(
            (sigReq) => SignatureNewRoundsEvent(
              reqId: sigReq.details.obj.id,
              rounds: sigReq.pendingRoundsForId(pid),
            ),
          )
          .where((newRounds) => newRounds.rounds.isNotEmpty)
          .toList(),

      completedSigs: _state.completedSigs.values
          .where((sigs) => !sigs.acks.contains(pid))
          .map(
            (sigs) => CompletedSignaturesRequest(
              details: sigs.details,
              signatures: sigs.signatures,
              creator: sigs.creator,
            ),
          )
          .toList(),

      secretShares: [
        for (final MapEntry(key: groupKey, value: sharingState)
            in _state.secretShares.entries)
          ...sharingState
              .getSharesForReceiver(pid)
              .map(
                (share) => SecretShareEvent(
                  sender: share.sender,
                  keyShare: share.share,
                  groupKey: groupKey,
                ),
              ),
      ],
    );
  }

  @override
  Future<Expiry> extendSession(SessionID sid) async {
    await _prepare();
    final session = getSession(sid);
    return session.expiry = Expiry(config.sessionTTL);
  }

  @override
  Future<void> requestNewDkg({
    required SessionID sid,
    required Signed<NewDkgDetails> signedDetails,
    required DkgPublicCommitment commitment,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final details = signedDetails.obj;

    // Check threshold
    if (details.threshold > _participantN) {
      throw InvalidRequest.invalidThreshold();
    }

    // Check expiry is within bounds
    _verifyExpiry(
      details.expiry,
      config.minDkgRequestTTL,
      config.maxDkgRequestTTL,
    );

    // Verify details
    if (!signedDetails.verify(_getParticipantPubkeyForSession(session))) {
      throw InvalidRequest.invalidDkgReqSig();
    }

    // Active attempts cannot be replaced. A creator may, however, atomically
    // replace their own interrupted attempt after a server restart because it
    // can no longer be resumed.
    final interrupted = _state.persistent.interruptedDkgs[details.name];
    if (_state.nameToDkg.containsKey(details.name) ||
        (interrupted != null && interrupted.creator != session.participantId)) {
      throw InvalidRequest.dkgRequestExists();
    }
    _state.persistent.interruptedDkgs.remove(details.name);

    // Create event to share with participants
    final commitments = [(session.participantId, commitment)];
    final dkgEvent = NewDkgEvent(
      details: signedDetails,
      creator: session.participantId,
      commitments: commitments,
    );

    // Store request
    _state.nameToDkg[details.name] = DkgState(
      details: dkgEvent.details,
      creator: dkgEvent.creator,
      commitments: commitments,
    );

    await _persist();

    // Broadcast to other participants
    _state.sendEventToOthers(dkgEvent, sid);
  }

  @override
  Future<void> rejectDkg({required SessionID sid, required String name}) async {
    await _prepare();
    final participantId = getSession(sid).participantId;
    if (_state.nameToDkg.remove(name) != null) {
      await _persist();
      // Send an event to all other participants that the DKG was removed
      _state.sendEventToOthers(
        DkgRejectEvent(name: name, participant: participantId),
        sid,
      );
    }
  }

  @override
  Future<void> submitDkgCommitment({
    required SessionID sid,
    required String name,
    required DkgPublicCommitment commitment,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final pid = session.participantId;

    // Look for round1 DKG of the name
    final dkg = _getDkg(name);
    if (dkg.round is! DkgRound1State) throw InvalidRequest.notRound1Dkg();

    // Add commitment if it doesn't already exist for this participant
    final commitments = dkg.round1.commitments;
    if (commitments.any((c) => c.$1 == pid)) {
      throw InvalidRequest.dkgCommitmentExists();
    }
    commitments.add((pid, commitment));

    // If all commitments have been received, move onto round 2
    if (commitments.length == _participantN) {
      final commitmentSet = DkgCommitmentSet(commitments);
      dkg.round = DkgRound2State(
        expectedHash: dkg.details.obj.hashWithCommitments(commitmentSet),
      );
    }

    await _persist();

    // Send commitment to other participants
    _state.sendEventToOthers(
      DkgCommitmentEvent(name: name, participant: pid, commitment: commitment),
      sid,
    );
  }

  @override
  Future<void> submitDkgRound2({
    required SessionID sid,
    required String name,
    required cl.SchnorrSignature commitmentSetSignature,
    required Map<Identifier, DkgEncryptedSecret> secrets,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final dkg = _getDkg(name);
    if (dkg.round is! DkgRound2State) throw InvalidRequest.notRound2Dkg();
    final round = dkg.round2;

    // Verify signature
    if (!commitmentSetSignature.verify(
      _getParticipantPubkeyForSession(session),
      round.expectedHash,
    )) {
      throw InvalidRequest.invalidDkgCommitmentSetSignature();
    }

    // Do not allow a participant to submit round2 twice
    if (round.participantsProvided.contains(session.participantId)) {
      throw InvalidRequest.dkgRound2Sent();
    }

    if (secrets.length != _participantN - 1) {
      throw InvalidRequest.invalidSecretMap();
    }

    for (final otherSess in _state.clientSessions.values) {
      if (otherSess.sessionID != sid &&
          !secrets.containsKey(otherSess.participantId)) {
        throw InvalidRequest.invalidSecretMap();
      }
    }

    // If all participants have provided a signature, the DKG is complete
    if (round.participantsProvided.length == _participantN - 1) {
      // Remove DKG
      _state.nameToDkg.remove(name);
      // No details of the key are stored on the server as only the participants
      // can generate the public information at this point.
    } else {
      // Record that the participant has provided round 2
      round.participantsProvided.add(session.participantId);
    }

    await _persist();

    // Publish round data only after its state transition is durable.
    for (final otherSess in _state.clientSessions.values) {
      if (otherSess.sessionID != sid) {
        otherSess.sendEvent(
          DkgRound2ShareEvent(
            name: name,
            commitmentSetSignature: commitmentSetSignature,
            sender: session.participantId,
            secret: secrets[otherSess.participantId]!,
          ),
        );
      }
    }
  }

  @override
  Future<void> sendDkgAcks({
    required SessionID sid,
    required Set<SignedDkgAck> acks,
  }) async {
    await _prepare();
    getSession(sid);

    // Verify signatures
    if (acks.any(
      (ack) => !ack.signed.verify(_getParticipantPubkeyForId(ack.signer)),
    )) {
      throw InvalidRequest.invalidDkgAckSignature();
    }

    final Set<SignedDkgAck> newAcks = {};

    for (final ack in acks) {
      final ackCache = _state.dkgAckCache[ack.signed.obj.groupKey] ??=
          DkgAckCache(Expiry(config.ackCacheTTL));

      // If ACK already exists in cache, override if changing from false to true
      // Otherwise do nothing and continue
      final prevAck = ackCache.acks[ack.signer]?.obj;
      if (prevAck != null && (prevAck.accepted || !ack.signed.obj.accepted)) {
        continue;
      }

      // Add new ACK to cache
      ackCache.acks[ack.signer] = ack.signed;

      // Record as new ACK to send
      newAcks.add(ack);
    }

    // Do not send events if there are no new ACKs
    if (newAcks.isEmpty) return;

    // Send ACKs to participants, ensuring that their own ACKs aren't sent
    // Do not send to calling participant
    for (final session in _state.clientSessions.values.where(
      (s) => s.sessionID != sid,
    )) {
      final toSend = newAcks
          .where((ack) => ack.signer != session.participantId)
          .toSet();
      if (toSend.isNotEmpty) session.sendEvent(DkgAckEvent(toSend));
    }
  }

  @override
  Future<Set<SignedDkgAck>> requestDkgAcks({
    required SessionID sid,
    required Set<DkgAckRequest> requests,
  }) async {
    await _prepare();
    final session = getSession(sid);

    // Ensure all ids exist
    for (final id in [for (final req in requests) ...req.ids]) {
      _checkParticipantId(id);
      if (id == session.participantId) {
        throw InvalidRequest.cannotRequestSelfAck();
      }
    }

    // Record ACKs that the server has
    final Set<SignedDkgAck> have = {};

    // Add requests for ACKs we do not have
    final Set<DkgAckRequest> need = {};

    for (final request in requests) {
      // Get cache for this key
      final cache = _state.dkgAckCache[request.groupPublicKey];

      if (cache == null) {
        // No DKGs for this key so pass full request
        need.add(request);
        continue;
      }

      // Obtain those we have and request what we don't
      final Set<Identifier> idsToReq = {};
      for (final id in request.ids) {
        final ack = cache.acks[id];
        if (ack == null) {
          idsToReq.add(id);
        } else {
          have.add(SignedDkgAck(signer: id, signed: ack));
        }
      }

      // If we have any missing ACKs, add a request
      if (idsToReq.isNotEmpty) {
        need.add(
          DkgAckRequest(ids: idsToReq, groupPublicKey: request.groupPublicKey),
        );
      }
    }

    if (need.isNotEmpty) {
      // Send DkgAckRequestEvents for missing ACKs
      _state.sendEventToOthers(DkgAckRequestEvent(need), sid);
    }

    // Return found ACKS
    return have;
  }

  @override
  Future<void> requestSignatures({
    required SessionID sid,
    required Set<AggregateKeyInfo> keys,
    required Signed<SignaturesRequestDetails> signedDetails,
    required List<SigningCommitment> commitments,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final details = signedDetails.obj;
    final pid = session.participantId;

    // Require commitments for all signatures
    final numSigs = details.requiredSigs.length;
    if (commitments.length != numSigs) {
      throw InvalidRequest.wrongCommitmentNum();
    }

    // Require all keys for requested signatures and no more
    if (!SetEquality<cl.ECCompressedPublicKey>().equals(
      keys.map((info) => info.groupKey).toSet(),
      details.requiredSigs.map((sig) => sig.groupKey).toSet(),
    )) {
      throw InvalidRequest.wrongSigKeys();
    }

    // Verify expiry
    _verifyExpiry(
      details.expiry,
      config.minSignaturesRequestTTL,
      config.maxSignaturesRequestTTL,
    );

    // Verify request doesn't already exist
    if (_state.sigRequests.containsKey(details.id) ||
        _state.persistent.blockedSignatures.containsKey(details.id)) {
      throw InvalidRequest.sigRequestExists();
    }

    // Verify request signature
    if (!signedDetails.verify(_getParticipantPubkeyForSession(session))) {
      throw InvalidRequest.invalidSigReqSignature();
    }

    // Create state for request
    final reqState = _state.sigRequests[details.id] =
        SignaturesCoordinationState(
          details: signedDetails,
          creator: pid,
          keys: keys,
        );

    // Add commitments from creator
    for (int i = 0; i < numSigs; i++) {
      (reqState.sigs[i] as SingleSignatureInProgressState)
              .nextCommitments[pid] =
          commitments[i];
    }

    await _persist();

    // Send request event to participants
    _state.sendEventToOthers(
      SignaturesRequestEvent(
        details: signedDetails,
        creator: session.participantId,
      ),
      sid,
    );
  }

  SignaturesRequestId? _checkSigReqFail(
    SignaturesCoordinationState sigReqState,
  ) {
    final malAndRej =
        sigReqState.malicious.length + sigReqState.rejectors.length;
    final available = _participantN - malAndRej;

    final maxThreshold = sigReqState.sigs
        .whereType<SingleSignatureInProgressState>()
        .fold(0, (v, e) => max(v, e.key.group.threshold));

    if (available < maxThreshold) {
      // Cannot sign one of the signatures as threshold is too high
      final id = sigReqState.details.obj.id;
      _state.sigRequests.remove(id);
      return id;
    }
    return null;
  }

  @override
  Future<void> rejectSignaturesRequest({
    required SessionID sid,
    required SignaturesRequestId reqId,
  }) async {
    await _prepare();
    final pid = getSession(sid).participantId;

    final sigReq = _state.sigRequests[reqId];
    // Ignore if the request doesn't exist as this may have been previously
    // rejected or completed before the client knows
    if (sigReq == null) return;

    // If already malicious, do not consider as rejector
    if (sigReq.malicious.contains(pid)) return;

    sigReq.rejectors.add(pid);
    final failed = _checkSigReqFail(sigReq);
    await _persist();
    if (failed != null) {
      _state.sendEventToAll(SignaturesFailureEvent(failed));
    }
  }

  @override
  Future<SignaturesResponse?> submitSignatureReplies({
    required SessionID sid,
    required SignaturesRequestId reqId,
    required List<SignatureReply> replies,
  }) async {
    await _prepare();
    final pid = getSession(sid).participantId;

    final sigReq = _state.sigRequests[reqId];
    // Ignore if the request doesn't exist in case it was rejected or completed
    if (sigReq == null) return null;

    final sigDetails = sigReq.details.obj;

    Future<Never> throwMalicious(InvalidRequest exp) async {
      sigReq.malicious.add(pid);
      final failed = _checkSigReqFail(sigReq);
      await _persist();
      if (failed != null) {
        _state.sendEventToAll(SignaturesFailureEvent(failed));
      }
      throw exp;
    }

    if (sigReq.malicious.contains(pid)) {
      throw InvalidRequest.markedMalicious();
    }

    // No longer consider a rejector if it was
    sigReq.rejectors.remove(pid);

    if (replies.isEmpty) {
      await throwMalicious(InvalidRequest.emptySigReply());
    }

    // Ensure no duplicate replies
    if (replies.map((resp) => resp.sigI).toSet().length != replies.length) {
      await throwMalicious(InvalidRequest.duplicateSigReply());
    }

    // Record new rounds that are started for each participant
    final Map<Identifier, List<SignatureRoundStart>> newRounds = {};

    // Loop through provided replies and process for each signature
    for (final reply in replies) {
      final sigI = reply.sigI;

      if (sigI >= sigDetails.requiredSigs.length) {
        await throwMalicious(InvalidRequest.invalidSigIndex());
      }

      var sigState = sigReq.sigs[sigI];

      if (sigState is! SingleSignatureInProgressState) {
        // Ignore signatures that are done
        continue;
      }

      if (sigState.nextCommitments.containsKey(pid)) {
        // Already have commitment waiting for complete set
        await throwMalicious(InvalidRequest.nextCommitmentExists());
      }

      final round = sigState.roundForId[pid];
      final threshold = sigState.key.group.threshold;

      if (round == null) {
        if (reply.share != null) {
          await throwMalicious(InvalidRequest.unsolicitedShare());
        }
      } else {
        // Process signature share

        final share = reply.share;
        if (share == null) {
          await throwMalicious(InvalidRequest.missingShare());
        }

        final singleSigDetails = sigDetails.requiredSigs[sigI];
        final derivedKey = singleSigDetails.derive(
          HDAggregateKeyInfo.masterFromInfo(sigState.key),
        );

        // ShareVal: validation of provided signature share
        if (!verifySignatureShare(
          commitments: round.commitments,
          details: singleSigDetails.signDetails,
          id: pid,
          share: share,
          publicShare: derivedKey.publicShares.list
              .firstWhere((share) => share.$1 == pid)
              .$2,
          groupKey: derivedKey.groupKey,
        )) {
          await throwMalicious(InvalidRequest.invalidShare());
        }

        // Share is OK. Add share for round
        round.shares.add((pid, share));

        // If all shares have been received, aggregate and complete this
        // signature
        if (round.shares.length == threshold) {
          final signature = SignatureAggregation(
            commitments: round.commitments,
            details: singleSigDetails.signDetails,
            shares: round.shares,
            info: derivedKey,
          ).signature;

          sigState = sigReq.sigs[sigI] = SingleSignatureFinishedState(
            signature,
          );
        }
      }

      // Add next commitment if not already finished
      if (sigState is SingleSignatureInProgressState) {
        final commitments = sigState.nextCommitments;
        commitments[pid] = reply.nextCommitment;

        // If we have enough commitments, create new round
        if (commitments.length == threshold) {
          final commitmentSet = SigningCommitmentSet(commitments);
          final round = SignatureRoundState(commitmentSet);

          final roundStart = SignatureRoundStart(
            sigI: sigI,
            commitments: commitmentSet,
          );

          // Store round information for all included participants
          for (final id in commitments.keys) {
            sigState.roundForId[id] = round;
            if (newRounds.containsKey(id)) {
              newRounds[id]!.add(roundStart);
            } else {
              newRounds[id] = [roundStart];
            }
          }

          // Clear next commitments to collect for next round
          sigState.nextCommitments.clear();
        }
      }
    }

    // If all signatures have been completed, submit event and respond with them
    if (sigReq.sigs.every((sig) => sig is SingleSignatureFinishedState)) {
      final signatures = sigReq.sigs
          .cast<SingleSignatureFinishedState>()
          .map((sig) => sig.signature)
          .toList();

      // The expiry of the completed signatures should be at least the minimum
      final completedExpiry =
          sigReq.expiry.ttl < config.minCompletedSignaturesTTL
          ? Expiry(config.minCompletedSignaturesTTL)
          : sigReq.expiry;

      // Store signatures to share with other participants when they are online
      // and wait to receive enough ACKs before deleting from server.
      _state.completedSigs[reqId] = CompletedSignatures(
        details: sigReq.details,
        signatures: signatures,
        expiry: completedExpiry,
        creator: sigReq.creator,
      );

      // Remove signature request as it is completed now
      _state.sigRequests.remove(reqId);

      await _persist();

      _state.sendEventToOthers(
        SignaturesCompleteEvent(reqId: reqId, signatures: signatures),
        sid,
      );

      return SignaturesCompleteResponse(signatures);
    }

    // If there are any new rounds, return them and send events to round
    // participants
    if (newRounds.isNotEmpty) {
      await _persist();
      for (final id in newRounds.keys.where((id) => id != pid)) {
        _state.participantToSession[id]?.sendEvent(
          SignatureNewRoundsEvent(reqId: reqId, rounds: newRounds[id]!),
        );
      }

      return SignatureNewRoundsResponse(newRounds[pid]!);
    }

    // Nothing to provide otherwise
    await _persist();
    return null;
  }

  @override
  Future<List<ConstructedKeyEvent>> shareSecretShare({
    required SessionID sid,
    required cl.ECCompressedPublicKey groupKey,
    required Map<Identifier, EncryptedKeyShare> encryptedSecrets,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final pid = session.participantId;

    // Cannot be empty
    if (encryptedSecrets.isEmpty) throw InvalidRequest.invalidKeyShareMap();

    // Cannot send to self
    if (encryptedSecrets.containsKey(pid)) {
      throw InvalidRequest.invalidKeyShareMap();
    }

    // Must contain identifiers in group
    if (encryptedSecrets.keys.any(
      (id) => !config.group.participants.containsKey(id),
    )) {
      throw InvalidRequest.invalidKeyShareMap();
    }

    // Store ciphertexts
    // For each entry, store shares that haven't been received and send them as
    // events.

    final secrets = _state.secretSharesForKey(groupKey);

    final added = <(Identifier, EncryptedKeyShare)>[];
    for (final MapEntry(key: id, value: share) in encryptedSecrets.entries) {
      if (secrets.maybeAddShare(pid, id, share)) {
        added.add((id, share));
      }
    }

    if (added.isNotEmpty) await _persist();
    for (final (id, share) in added) {
      _state.participantToSession[id]?.sendEvent(
        SecretShareEvent(sender: pid, keyShare: share, groupKey: groupKey),
      );
    }

    // Return cached ConstructedKeyEvents for unneeded secrets
    return secrets.eventsForCompleted(encryptedSecrets.keys);
  }

  @override
  Future<void> ackKeyConstructed({
    required SessionID sid,
    required Signed<KeyWasConstructed> constructedKey,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final pid = session.participantId;

    if (!constructedKey.verify(_getParticipantPubkeyForId(pid))) {
      throw InvalidRequest.invalidKeyConstructedSig();
    }

    // Get state for key's secret shares
    final pubkey = constructedKey.obj.publicKey;
    final secrets = _state.secretSharesForKey(pubkey);

    if (secrets.receiverShares[pid] is ParticipantDoneShareState) {
      throw InvalidRequest.haveKeyConstructedAck();
    }

    // Set as done for participant and send event to everyone else
    final event = ConstructedKeyEvent(
      participant: pid,
      constructedKey: constructedKey,
    );

    secrets.receiverShares[pid] = ParticipantDoneShareState(event);

    await _persist();

    // Send event to other participants
    _state.sendEventToOthers(event, sid);
  }

  /// Closes all client session streams
  Future<void> shutdown() => Future.wait(
    _state.clientSessions.values.map(
      (session) => session.eventController.close(),
    ),
  );
}

part of 'api_handler.dart';

extension _ServerDkg on ServerApiHandler {
  Future<void> _requestNewDkg({
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

  Future<void> _rejectDkg({
    required SessionID sid,
    required String name,
  }) async {
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

  Future<void> _submitDkgCommitment({
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

  Future<void> _submitDkgRound2({
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

  Future<void> _sendDkgAcks({
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

  Future<Set<SignedDkgAck>> _requestDkgAcks({
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
}

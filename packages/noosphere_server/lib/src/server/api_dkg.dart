part of 'api_handler.dart';

extension _ServerDkg on ServerApiHandler {
  DkgCeremonySnapshot _dkgSnapshot(DkgState dkg, Identifier recipient) {
    final round2 = dkg.round is DkgRound2State ? dkg.round2 : null;
    final stage = dkg.completed
        ? DkgCeremonyStage.completed
        : dkg.awaitingCompletion
        ? DkgCeremonyStage.awaitingCompletion
        : round2 == null
        ? DkgCeremonyStage.collectingCommitments
        : DkgCeremonyStage.collectingShares;
    return DkgCeremonySnapshot(
      details: dkg.details,
      creator: dkg.creator,
      commitments: dkg.commitments,
      stage: stage,
      shareContributors: round2?.contributions.keys.toSet() ?? const {},
      shares: [
        if (round2 != null)
          for (final contribution in round2.contributions.entries)
            if (contribution.key != recipient)
              contribution.value.shareFor(
                dkg.details.obj.name,
                dkg.details.obj.ceremonyId,
                contribution.key,
                recipient,
              ),
      ],
      completedParticipants: dkg.completionAcks.keys.toSet(),
      groupPublicKey: dkg.completedGroupKey,
    );
  }

  Future<DkgCeremonySnapshot?> _getDkgSnapshot({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
  }) async {
    await _prepare();
    final recipient = getSession(sid).participantId;
    final dkg = _state.nameToDkg[name];
    return dkg == null || !cl.bytesEqual(dkg.details.obj.ceremonyId, ceremonyId)
        ? null
        : _dkgSnapshot(dkg, recipient);
  }

  Future<void> _requestNewDkg({
    required SessionID sid,
    required Signed<NewDkgDetails> signedDetails,
    required DkgPublicCommitment commitment,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final details = signedDetails.obj;

    if (details.protocolVersion != ServerApiHandler.currentProtocolVersion) {
      throw InvalidRequest.invalidProtoVersion();
    }
    if (!cl.bytesEqual(details.groupFingerprint, config.group.fingerprint)) {
      throw InvalidRequest.groupMismatch();
    }

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
    if (_state.persistent.terminalDkgs.containsKey(
      _dkgCeremonyKey(details.ceremonyId),
    )) {
      throw InvalidRequest.dkgRequestExists();
    }

    if (_state.nameToDkg.containsKey(details.name)) {
      throw InvalidRequest.dkgRequestExists();
    }

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

    _state.persistent.publicFeed?.requested(
      'dkg:${details.name}',
      PublicFeedCategory.dkg,
      details.expiry.time,
    );

    await _persist();

    // Broadcast to other participants
    _state.sendEventToOthers(dkgEvent, sid);
  }

  Future<void> _rejectDkg({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
  }) async {
    await _prepare();
    final participantId = getSession(sid).participantId;
    final dkg = _state.nameToDkg[name];
    if (dkg == null || !cl.bytesEqual(dkg.details.obj.ceremonyId, ceremonyId)) {
      // Rejection retries remain successful without affecting a replacement.
      return;
    }
    _retainTerminalDkg(dkg, DkgTerminalOutcome.rejected);
    if (_state.nameToDkg.remove(name) != null) {
      _state.persistent.publicFeed?.finish(
        'dkg:$name',
        PublicFeedLifecycle.rejected,
      );
      await _persist();
      // Send an event to all other participants that the DKG was removed
      _state.sendEventToOthers(
        DkgRejectEvent(
          name: name,
          ceremonyId: dkg.details.obj.ceremonyId,
          participant: participantId,
        ),
        sid,
      );
    }
  }

  Future<void> _submitDkgCommitment({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
    required DkgPublicCommitment commitment,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final pid = session.participantId;

    // Identical retries are successful even after the ceremony advanced. A
    // conflicting retry can only be a changed local secret and must abort.
    final dkg = _getDkgForCeremony(name, ceremonyId);
    final existing = dkg.commitments.where((c) => c.$1 == pid).firstOrNull;
    if (existing != null) {
      if (cl.bytesEqual(existing.$2.toBytes(), commitment.toBytes())) return;
      throw InvalidRequest.dkgCommitmentExists();
    }
    if (dkg.round is! DkgRound1State) throw InvalidRequest.notRound1Dkg();

    final commitments = dkg.round1.commitments;
    commitments.add((pid, commitment));

    // If all commitments have been received, move onto round 2
    if (commitments.length == _participantN) {
      final commitmentSet = DkgCommitmentSet(commitments);
      dkg.round = DkgRound2State(
        expectedHash: dkg.details.obj.hashWithCommitments(commitmentSet),
        commitments: commitments,
        participantCount: _participantN,
      );
    }

    await _persist();

    // Send commitment to other participants
    _state.sendEventToOthers(
      DkgCommitmentEvent(
        name: name,
        ceremonyId: dkg.details.obj.ceremonyId,
        participant: pid,
        commitment: commitment,
      ),
      sid,
    );
  }

  Future<void> _submitDkgRound2({
    required SessionID sid,
    required String name,
    required Uint8List ceremonyId,
    required cl.SchnorrSignature commitmentSetSignature,
    required Map<Identifier, DkgEncryptedSecret> secrets,
  }) async {
    await _prepare();
    final session = getSession(sid);
    final dkg = _getDkgForCeremony(name, ceremonyId);
    if (dkg.round is! DkgRound2State) throw InvalidRequest.notRound2Dkg();
    final round = dkg.round2;
    final pid = session.participantId;

    final previous = round.contributions[pid];
    if (previous != null) {
      final sameSignature = cl.bytesEqual(
        previous.commitmentSetSignature.data,
        commitmentSetSignature.data,
      );
      final sameRecipients =
          previous.secrets.keys.toSet().containsAll(secrets.keys) &&
          secrets.keys.toSet().containsAll(previous.secrets.keys);
      final sameSecrets =
          sameRecipients &&
          secrets.entries.every(
            (entry) => cl.bytesEqual(
              previous.secrets[entry.key]!.ciphertext.toBytes(),
              entry.value.ciphertext.toBytes(),
            ),
          );
      if (sameSignature && sameSecrets) return;
      throw InvalidRequest.dkgRound2Sent();
    }

    // Verify signature
    if (!commitmentSetSignature.verify(
      _getParticipantPubkeyForSession(session),
      round.expectedHash,
    )) {
      throw InvalidRequest.invalidDkgCommitmentSetSignature();
    }

    final expectedRecipients = config.group.participants.keys.toSet()
      ..remove(pid);
    if (secrets.keys.toSet().length != expectedRecipients.length ||
        !secrets.keys.toSet().containsAll(expectedRecipients) ||
        !expectedRecipients.containsAll(secrets.keys)) {
      throw InvalidRequest.invalidSecretMap();
    }

    round.contributions[pid] = DkgRound2Contribution(
      commitmentSetSignature: commitmentSetSignature,
      secrets: secrets,
    );

    await _persist();

    // Publish round data only after its state transition is durable.
    for (final otherSess in _state.clientSessions.values) {
      if (otherSess.sessionID != sid) {
        otherSess.sendEvent(
          DkgRound2ShareEvent(
            name: name,
            ceremonyId: dkg.details.obj.ceremonyId,
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

    final batchByKey = <String, SignedDkgAck>{};
    final completionAdds = <DkgState, Map<Identifier, Signed<DkgAck>>>{};
    for (final ack in acks) {
      if (!ack.signed.verify(_getParticipantPubkeyForId(ack.signer))) {
        throw InvalidRequest.invalidDkgAckSignature();
      }
      final value = ack.signed.obj;
      final batchKey = '${ack.signer}:${value.groupKey.hex}';
      final inBatch = batchByKey[batchKey];
      if (inBatch != null && !cl.bytesEqual(inBatch.toBytes(), ack.toBytes())) {
        throw InvalidRequest.invalidDkgAckSignature();
      }
      batchByKey[batchKey] = ack;

      final dkg = _state.nameToDkg.values.firstWhereOrNull(
        (candidate) =>
            cl.bytesEqual(candidate.details.obj.ceremonyId, value.ceremonyId),
      );
      // Only positive acknowledgements can claim completion. A negative
      // possession response is valid even while the ceremony is retained,
      // and must never remove or alter a durable completion acknowledgement.
      if (dkg != null && value.accepted) {
        if (dkg.round is! DkgRound2State ||
            !dkg.round2.allSharesSubmitted ||
            !dkg.round2.contributions.containsKey(ack.signer) ||
            !cl.bytesEqual(dkg.round2.expectedHash, value.transcriptHash)) {
          throw InvalidRequest.invalidDkgAckSignature();
        }
        final planned = completionAdds[dkg] ??= {};
        final expectedKey =
            dkg.completedGroupKey ?? planned.values.firstOrNull?.obj.groupKey;
        if (expectedKey != null && expectedKey != value.groupKey) {
          throw InvalidRequest.invalidDkgAckSignature();
        }
        final previous = dkg.completionAcks[ack.signer] ?? planned[ack.signer];
        if (previous != null &&
            !cl.bytesEqual(previous.toBytes(), ack.signed.toBytes())) {
          throw InvalidRequest.invalidDkgAckSignature();
        }
        if (previous == null) planned[ack.signer] = ack.signed;
      }
    }

    final cacheAdds =
        <cl.ECCompressedPublicKey, Map<Identifier, Signed<DkgAck>>>{};
    final Set<SignedDkgAck> newAcks = {};
    for (final ack in acks) {
      final key = ack.signed.obj.groupKey;
      final prevAck = _state.dkgAckCache[key]?.acks[ack.signer]?.obj;
      final sameContext =
          prevAck != null &&
          cl.bytesEqual(prevAck.ceremonyId, ack.signed.obj.ceremonyId) &&
          cl.bytesEqual(prevAck.transcriptHash, ack.signed.obj.transcriptHash);
      if (sameContext && (prevAck.accepted || !ack.signed.obj.accepted)) {
        continue;
      }
      (cacheAdds[key] ??= {})[ack.signer] = ack.signed;
      newAcks.add(ack);
    }

    for (final entry in completionAdds.entries) {
      entry.key.completionAcks.addAll(entry.value);
      if (entry.key.completed) {
        _state.persistent.publicFeed?.finish(
          'dkg:${entry.key.details.obj.name}',
          PublicFeedLifecycle.completed,
        );
      }
    }
    for (final entry in cacheAdds.entries) {
      final cache = _state.dkgAckCache[entry.key] ??= DkgAckCache(
        Expiry(config.ackCacheTTL),
      );
      cache.acks.addAll(entry.value);
    }

    if (completionAdds.values.any((values) => values.isNotEmpty)) {
      await _persist();
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
        if (ack == null ||
            !cl.bytesEqual(ack.obj.ceremonyId, request.ceremonyId) ||
            !cl.bytesEqual(ack.obj.transcriptHash, request.transcriptHash)) {
          idsToReq.add(id);
        } else {
          have.add(SignedDkgAck(signer: id, signed: ack));
        }
      }

      // If we have any missing ACKs, add a request
      if (idsToReq.isNotEmpty) {
        need.add(
          DkgAckRequest(
            ids: idsToReq,
            groupPublicKey: request.groupPublicKey,
            ceremonyId: request.ceremonyId,
            transcriptHash: request.transcriptHash,
          ),
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

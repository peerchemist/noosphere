part of 'client.dart';

extension _ClientDkg on Client {
  DkgPart1 _getDkgPart1(int threshold) =>
      DkgPart1(identifier: config.id, threshold: threshold, n: config.groupN);

  Future<void> _rejectDkgWithoutSync(String name) async {
    await api.rejectDkg(sid: _state.sessionID, name: name);
    _state.nameToDkg.remove(name);
  }

  Future<void> _rejectBadDkg({
    required NewDkgDetails details,
    required Identifier? culprit,
    required DkgFault fault,
  }) async {
    // Send rejection to server and remove from state
    await _rejectDkgWithoutSync(details.name);

    // Send event of the rejection
    _sendEvent(
      RejectedDkgClientEvent(
        details: details,
        participant: culprit,
        fault: fault,
      ),
    );
  }

  // Return true on rejection
  Future<bool> _doPart2IfReady(ClientDkgState dkg) async {
    final round1 = dkg.round1;

    // Not ready until all commitments received
    if (round1.commitments.length != config.groupN) return false;

    final commitmentSet = DkgCommitmentSet(round1.commitments);

    late DkgPart2 part2;
    try {
      part2 = DkgPart2(
        identifier: config.id,
        round1Secret: round1.ourSecret!,
        commitments: commitmentSet,
      );
    } on InvalidPart2ProofOfKnowledge catch (e) {
      await _rejectBadDkg(
        details: dkg.details,
        culprit: e.culprit,
        fault: DkgFault.proofOfKnowledge,
      );
      return true;
    }

    final key = await getPrivateKey(KeyPurpose.dkgPart2);

    await api.submitDkgRound2(
      sid: _state.sessionID,
      name: dkg.details.name,
      commitmentSetSignature: cl.SchnorrSignature.sign(
        key,
        dkg.details.hashWithCommitments(commitmentSet),
      ),
      secrets: part2.sharesToGive.map(
        (id, share) => MapEntry(
          id,
          DkgEncryptedSecret.encrypt(
            secretShare: share,
            recipientKey: Client._getParticipantPubkeyForId(config, id),
            senderKey: key,
          ),
        ),
      ),
    );

    // Move state to round 2
    dkg.round = ClientDkgRound2State(part2.secret, commitmentSet);

    return false;
  }

  Future<void> _doPart3(ClientDkgState dkg) async {
    final round2 = dkg.round2;

    late ParticipantKeyInfo keyInfo;
    try {
      keyInfo = DkgPart3(
        identifier: config.id,
        round2Secret: round2.ourSecret,
        commitments: round2.commitmentSet,
        receivedShares: round2.secretShares,
      ).participantInfo;
    } on InvalidPart3 {
      await _rejectBadDkg(
        details: dkg.details,
        // Frosty does not provide participant with invalid secret
        culprit: null,
        fault: DkgFault.secret,
      );
      return;
    }

    // Store new FROST key
    await _store.addOrReplaceFrostKey(
      FrostKeyWithDetails(
        keyInfo: keyInfo,
        name: dkg.details.name,
        description: dkg.details.description,
      ),
    );

    // Remove DKG which is complete
    _state.nameToDkg.remove(dkg.details.name);

    // Store and send our ACK
    await api.sendDkgAcks(
      sid: _state.sessionID,
      acks: {await _createDkgAck(keyInfo.groupKey, true)},
    );
  }

  Future<SignedDkgAck> _createDkgAck(
    cl.ECCompressedPublicKey groupKey,
    bool accept,
  ) async {
    final ack = SignedDkgAck(
      signer: config.id,
      signed: Signed.sign(
        obj: DkgAck(groupKey: groupKey, accepted: accept),
        key: await getPrivateKey(KeyPurpose.signAck),
      ),
    );

    // Store if we are accepting (and therefore have) the key
    final key = _keys[groupKey];
    if (accept && key != null) {
      await _store.addOrReplaceFrostKey(_keys[groupKey]!.addOrReplaceAck(ack));
    }

    return ack;
  }

  Future<void> _verifyAndAddAck(SignedDkgAck ack) async {
    Client._checkOtherParticipantId(config, ack.signer);

    await _runKeyDetailsSyncIfExists(ack.signed.obj.groupKey, (key) async {
      // Only do the expensive signature check if we have the key
      Client._checkSigned(config, ack.signed, ack.signer);

      // Add/Update ACK for key
      await _store.addOrReplaceFrostKey(key.addOrReplaceAck(ack));
    });
  }

  Future<void> _requestAcks(Set<Identifier> ids) =>
      _dkgAckLock.synchronized(() async {
        // Obtain requests for missing ACKS for ids
        final requests = _store.getAckRequestsForMissing(ids);

        // If nothing is needed, then return
        if (requests.isEmpty) return;

        // Request ACKs we need
        final acks = await api.requestDkgAcks(
          sid: _state.sessionID,
          requests: requests,
        );

        // Add received acks
        for (final ack in acks) {
          // Verify that we requested it
          if (!requests.any(
            (req) =>
                req.groupPublicKey == ack.signed.obj.groupKey &&
                req.ids.contains(ack.signer),
          )) {
            throw ServerMisbehaviour.ackNotRequested();
          }

          // Verify signature and add if OK
          await _verifyAndAddAck(ack);
        }
      });

  Future<void> _requestDkg(NewDkgDetails details) async {
    // Check expiry
    if (!config.dkgExpiryAcceptable(details.expiry)) {
      throw ArgumentError.value(
        details.expiry,
        "details.expiry",
        "not in range",
      );
    }

    // Wait until request is fully handled, before handling another to avoid
    // trying to submit DKG with same name more than once.
    await _dkgReqLock.synchronized(() async {
      // Check if exists
      if (dkgExists(details.name)) {
        throw ArgumentError.value(details.name, "details.name", "exists");
      }

      // Sign details
      final key = await getPrivateKey(KeyPurpose.dkgDetails);
      final signedDetails = Signed.sign(obj: details, key: key);

      // Create commitment and part 1 secret
      final part1 = _getDkgPart1(details.threshold);

      // Submit to server
      await api.requestNewDkg(
        sid: _state.sessionID,
        signedDetails: signedDetails,
        commitment: part1.public,
      );

      // Update state
      _state.nameToDkg[details.name] = ClientDkgState(
        details: details,
        creator: config.id,
        commitments: [(config.id, part1.public)],
        ourSecret: part1.secret,
        expiry: details.expiry,
      );
    });
  }

  Future<void> _acceptDkg(String name) =>
      _runDkgSyncIfExists(name, (dkg) async {
        if (_dkgIsAccepted(dkg)) {
          throw ArgumentError.value(name, "name", "not an unaccepted DKG");
        }

        final part1 = _getDkgPart1(dkg.details.threshold);

        await api.submitDkgCommitment(
          sid: _state.sessionID,
          name: name,
          commitment: part1.public,
        );

        dkg.round1
          ..ourSecret = part1.secret
          ..commitments.add((config.id, part1.public));

        await _doPart2IfReady(dkg);
      });

  ClientDkgState _addDkgToState({
    required ClientConfig config,
    required NewDkgDetails details,
    required Identifier creator,
    required DkgCommitmentList commitments,
  }) => _state.nameToDkg[details.name] = ClientDkgState(
    details: details,
    creator: creator,
    commitments: commitments,
    // Clamp TTL to max
    expiry: details.expiry.clampUpperTTL(config.maxDkgRequestTTL),
  );

  // If the DKG with the name exists, it shall run the criticalSection with the
  // DKG state. The sections will be run synchronously for the DKG.
  Future<void> _runDkgSyncIfExists(
    String name,
    FutureOr<void> Function(ClientDkgState) criticalSection,
  ) async {
    // Ignore non-existing DKG, in case ours expired before server's
    final dkg = _state.nameToDkg[name];

    await dkg?.synchronized(() async {
      // Check again if removed before start of async critical section
      if (!dkgExists(name)) return;
      await criticalSection(dkg);
    });
  }

  bool _dkgIsAccepted(ClientDkgState dkg) =>
      dkg.round is! ClientDkgRound1State ||
      dkg.round1.commitments.any((c) => c.$1 == config.id);
}

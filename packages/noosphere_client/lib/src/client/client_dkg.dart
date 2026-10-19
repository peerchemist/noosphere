part of 'client.dart';

extension _ClientDkg on Client {
  DkgPart1 _getDkgPart1(int threshold) =>
      DkgPart1(identifier: config.id, threshold: threshold, n: config.groupN);

  Future<void> _rejectDkgWithoutSync(String name) async {
    final dkg = _state.nameToDkg[name];
    if (dkg == null) return;
    await api.rejectDkg(
      sid: _state.sessionID,
      name: name,
      ceremonyId: dkg.details.ceremonyId,
    );
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
    if (dkg.missingSecret) return false;

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
    final signature = cl.SchnorrSignature.sign(
      key,
      dkg.details.hashWithCommitments(commitmentSet),
    );
    final secrets = part2.sharesToGive.map(
      (id, share) => MapEntry(
        id,
        DkgEncryptedSecret.encrypt(
          secretShare: share,
          recipientKey: Client._getParticipantPubkeyForId(config, id),
          senderKey: key,
        ),
      ),
    );

    // Keep the exact prepared payload before crossing the transport boundary
    // so an uncertain response can be retried byte-for-byte.
    dkg.round = ClientDkgRound2State(
      part2.secret,
      commitmentSet,
      outgoingSignature: signature,
      outgoingSecrets: secrets,
    );

    await api.submitDkgRound2(
      sid: _state.sessionID,
      name: dkg.details.name,
      ceremonyId: dkg.details.ceremonyId,
      commitmentSetSignature: signature,
      secrets: secrets,
    );

    return false;
  }

  Future<void> _retryRound2(ClientDkgState dkg) async {
    final round2 = dkg.round2;
    await api.submitDkgRound2(
      sid: _state.sessionID,
      name: dkg.details.name,
      ceremonyId: dkg.details.ceremonyId,
      commitmentSetSignature: round2.outgoingSignature,
      secrets: round2.outgoingSecrets,
    );
  }

  Future<void> _resumeDkg(
    String name, {
    bool tolerateMissingSecret = false,
  }) async {
    final local = _state.nameToDkg[name];
    if (local == null) return;
    final snapshot = await api.getDkg(
      sid: _state.sessionID,
      name: name,
      ceremonyId: local.details.ceremonyId,
    );
    if (snapshot == null || snapshot.expiry.isExpired) return;
    Client._checkSigned(config, snapshot.details, snapshot.creator);
    if (snapshot.details.obj.protocolVersion != noosphereRoastProtocolVersion ||
        !cl.bytesEqual(
          snapshot.details.obj.groupFingerprint,
          config.group.fingerprint,
        ) ||
        !cl.bytesEqual(
          local.details.ceremonyId,
          snapshot.details.obj.ceremonyId,
        )) {
      throw ServerMisbehaviour.changedDkgTranscript();
    }
    Client._checkIdentifierSet(
      config,
      Client._idsFromCommitments(snapshot.commitments),
    );
    Client._checkIdentifierSet(config, snapshot.shareContributors);
    Client._checkIdentifierSet(config, snapshot.completedParticipants);

    await local.synchronized(() async {
      // Rejection may have completed while the snapshot RPC was in flight.
      if (!identical(_state.nameToDkg[name], local)) return;

      final commitments = DkgCommitmentSet(snapshot.commitments);
      final transcriptHash = snapshot.details.obj.hashWithCommitments(
        commitments,
      );
      final storedKey = _keys.values
          .where(
            (key) =>
                cl.bytesEqual(key.ceremonyId, snapshot.ceremonyId) &&
                cl.bytesEqual(key.transcriptHash, transcriptHash) &&
                (snapshot.groupPublicKey == null ||
                    key.groupKey == snapshot.groupPublicKey),
          )
          .firstOrNull;
      if (storedKey != null) {
        await api.sendDkgAcks(
          sid: _state.sessionID,
          acks: {
            await _createDkgAck(
              storedKey.groupKey,
              true,
              ceremonyId: snapshot.ceremonyId,
              transcriptHash: transcriptHash,
            ),
          },
        );
        _state.nameToDkg.remove(name);
        return;
      }

      final dkg = local;
      if (!cl.bytesEqual(
        dkg.details.ceremonyId,
        snapshot.details.obj.ceremonyId,
      )) {
        throw ServerMisbehaviour.changedDkgTranscript();
      }

      final localCommitments = {
        for (final commitment in dkg.commitments) commitment.$1: commitment.$2,
      };
      for (final commitment in snapshot.commitments) {
        final previous = localCommitments[commitment.$1];
        if (previous != null &&
            !cl.bytesEqual(previous.toBytes(), commitment.$2.toBytes())) {
          throw ServerMisbehaviour.changedDkgTranscript();
        }
      }

      if (dkg.round is ClientDkgRound1State) {
        final round1 = dkg.round1;
        final localContribution = round1.commitments
            .where((c) => c.$1 == config.id)
            .firstOrNull;
        final serverContributed = snapshot.commitments.any(
          (c) => c.$1 == config.id,
        );
        // Events may have delivered newer commitments while the snapshot RPC
        // was in flight. Contributions are immutable, so reconcile by union
        // after checking conflicts above rather than rolling local state back.
        round1.commitments.addAll(
          snapshot.commitments.where(
            (entry) => !localCommitments.containsKey(entry.$1),
          ),
        );
        if (serverContributed && round1.ourSecret == null) {
          dkg
            ..missingSecret = true
            ..unavailableStage = switch (snapshot.stage) {
              DkgCeremonyStage.collectingCommitments => DkgStage.round1,
              _ => DkgStage.round2,
            }
            ..unavailableCompleted = switch (snapshot.stage) {
              DkgCeremonyStage.collectingCommitments =>
                round1.commitments.map((commitment) => commitment.$1).toSet(),
              DkgCeremonyStage.collectingShares => snapshot.shareContributors,
              _ => snapshot.completedParticipants,
            };
          if (!tolerateMissingSecret) throw MissingDkgSecret(name);
          return;
        }
        if (!serverContributed && localContribution != null) {
          await api.submitDkgCommitment(
            sid: _state.sessionID,
            name: name,
            ceremonyId: dkg.details.ceremonyId,
            commitment: localContribution.$2,
          );
        }
        if (serverContributed || localContribution != null) {
          await _doPart2IfReady(dkg);
        }
      } else if (!snapshot.shareContributors.contains(config.id)) {
        await _retryRound2(dkg);
      }
    });

    for (final share in snapshot.shares) {
      await _handleEvent(share);
    }
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
        ceremonyId: dkg.details.ceremonyId,
        transcriptHash: dkg.details.hashWithCommitments(round2.commitmentSet),
      ),
    );

    // Remove DKG which is complete
    _state.nameToDkg.remove(dkg.details.name);

    // Store and send our ACK
    await api.sendDkgAcks(
      sid: _state.sessionID,
      acks: {
        await _createDkgAck(
          keyInfo.groupKey,
          true,
          ceremonyId: dkg.details.ceremonyId,
          transcriptHash: dkg.details.hashWithCommitments(round2.commitmentSet),
        ),
      },
    );
    _sendEvent(CompletedDkgClientEvent(_keys[keyInfo.groupKey]!));
  }

  Future<SignedDkgAck> _createDkgAck(
    cl.ECCompressedPublicKey groupKey,
    bool accept, {
    required Uint8List ceremonyId,
    required Uint8List transcriptHash,
  }) async {
    final ack = SignedDkgAck(
      signer: config.id,
      signed: Signed.sign(
        obj: DkgAck(
          groupKey: groupKey,
          accepted: accept,
          ceremonyId: ceremonyId,
          transcriptHash: transcriptHash,
        ),
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
      if (!cl.bytesEqual(ack.signed.obj.ceremonyId, key.ceremonyId) ||
          !cl.bytesEqual(ack.signed.obj.transcriptHash, key.transcriptHash)) {
        throw ServerMisbehaviour.changedDkgTranscript();
      }

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
                cl.bytesEqual(req.ceremonyId, ack.signed.obj.ceremonyId) &&
                cl.bytesEqual(
                  req.transcriptHash,
                  ack.signed.obj.transcriptHash,
                ) &&
                req.ids.contains(ack.signer),
          )) {
            throw ServerMisbehaviour.ackNotRequested();
          }

          // Verify signature and add if OK
          await _verifyAndAddAck(ack);
        }
      });

  Future<void> _requestDkg(NewDkgDetails details) async {
    if (details.protocolVersion != noosphereRoastProtocolVersion ||
        !cl.bytesEqual(details.groupFingerprint, config.group.fingerprint)) {
      throw ArgumentError.value(details, 'details', 'wrong group or protocol');
    }
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

        dkg.round1
          ..ourSecret = part1.secret
          ..commitments.add((config.id, part1.public));

        await api.submitDkgCommitment(
          sid: _state.sessionID,
          name: name,
          ceremonyId: dkg.details.ceremonyId,
          commitment: part1.public,
        );

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

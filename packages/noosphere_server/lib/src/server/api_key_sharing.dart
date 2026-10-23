part of 'api_handler.dart';

extension _ServerKeySharing on ServerApiHandler {
  Future<List<ConstructedKeyEvent>> _shareSecretShare({
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

    if (encryptedSecrets.values.any(
      (share) =>
          share.ciphertext.toBytes().length >
          ServerConfig.maxEncryptedRecoveryShareBytes,
    )) {
      throw InvalidRequest('Recovery share is too large');
    }

    final existing = _state.secretShares[groupKey];
    if (existing == null) {
      if (_state.secretShares.length >= ServerConfig.maxRecoveryKeys) {
        throw InvalidRequest('Recovery resource capacity exceeded');
      }
      // One participant's signed construction claim is not evidence that this
      // is a roster key. Require unanimous, context-matching possession ACKs.
      final acks = _state.dkgAckCache[groupKey]?.acks;
      if (acks == null || acks.length != _participantN) {
        throw InvalidRequest(
          'Recovery key requires all participant acknowledgements',
        );
      }
      final context = acks.values.first.obj;
      if (config.group.participants.keys.any((id) {
        final ack = acks[id]?.obj;
        return ack == null ||
            !ack.accepted ||
            ack.groupKey != groupKey ||
            !cl.bytesEqual(ack.ceremonyId, context.ceremonyId) ||
            !cl.bytesEqual(ack.transcriptHash, context.transcriptHash);
      })) {
        throw InvalidRequest('Recovery key acknowledgements disagree');
      }
    }
    final secrets = existing ?? KeySharingState();
    final added = <(Identifier, EncryptedKeyShare)>[];
    var extraBytes = existing == null ? 33 : 0;
    for (final MapEntry(key: id, value: share) in encryptedSecrets.entries) {
      final receiver = secrets.receiverShares[id];
      if (receiver is ParticipantDoneShareState ||
          (receiver is ParticipantPendingShareState &&
              receiver.haveForSender(pid))) {
        continue;
      }
      added.add((id, share));
      extraBytes +=
          32 +
          SecretShareEvent(
            sender: pid,
            keyShare: share,
            groupKey: groupKey,
          ).toBytes().length;
    }
    if (_state.recoveryPayloadBytes + extraBytes >
        ServerConfig.maxRecoveryStateBytes) {
      throw InvalidRequest('Recovery resource capacity exceeded');
    }
    if (added.isNotEmpty) {
      _admitRequestRate(
        _state.runtime.recoveryRequestTimes,
        pid,
        ServerConfig.maxRecoveryRequestsPerMinute,
      );
      _state.secretShares[groupKey] = secrets;
      for (final (id, share) in added) {
        secrets.maybeAddShare(pid, id, share);
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

  Future<void> _ackKeyConstructed({
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
    final secrets = _state.secretShares[pubkey];
    final receiver = secrets?.receiverShares[pid];
    if (secrets == null || receiver == null) {
      throw InvalidRequest('No recovery shares for this participant and key');
    }

    if (secrets.receiverShares[pid] is ParticipantDoneShareState) {
      throw InvalidRequest.haveKeyConstructedAck();
    }

    // Set as done for participant and send event to everyone else
    final event = ConstructedKeyEvent(
      participant: pid,
      constructedKey: constructedKey,
    );

    final done = ParticipantDoneShareState(event);
    if (_state.recoveryPayloadBytes -
            receiver.payloadBytes(pubkey) +
            done.payloadBytes(pubkey) >
        ServerConfig.maxRecoveryStateBytes) {
      throw InvalidRequest('Recovery resource capacity exceeded');
    }
    _admitRequestRate(
      _state.runtime.recoveryRequestTimes,
      pid,
      ServerConfig.maxRecoveryRequestsPerMinute,
    );
    secrets.receiverShares[pid] = done;

    await _persist();

    // Send event to other participants
    _state.sendEventToOthers(event, sid);
  }
}

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
}

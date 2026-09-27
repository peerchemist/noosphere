part of 'client.dart';

extension _ClientKeySharing on Client {
  Future<void> _processSecretSharing(
    FrostKeyWithDetails key,
    Set<Identifier> sendTo,
  ) async {
    // Do not send to those who have claimed to have constructed the key already
    sendTo = sendTo.where((id) => !key.claimedToHave.contains(id)).toSet();
    if (sendTo.isEmpty) return;

    final ourKey = await getPrivateKey(KeyPurpose.secretShare);
    final shareTime = DateTime.now();

    await api.shareSecretShare(
      sid: _state.sessionID,
      groupKey: key.groupKey,
      encryptedSecrets: {
        for (final id in sendTo)
          id: EncryptedKeyShare.encrypt(
            keyShare: key.keyInfo.private.share,
            recipientKey: Client._getParticipantPubkeyForId(config, id),
            senderKey: ourKey,
          ),
      },
    );

    await _store.addOrReplaceFrostKey(
      key.addOrReplaceSecretShareTimes(sendTo, shareTime),
    );
  }

  Future<void> _processSecretShareEvent(
    SecretShareEvent ev, {
    bool sendClientEvent = false,
  }) => _runKeyDetailsSyncIfExists(ev.groupKey, (keyDetails) async {
    final sender = ev.sender;

    // Do not process if we have this secret or the constructed key
    if (keyDetails.keyConstruction.haveForParticipant(sender)) return;

    // Decrypt secret share and check against public share
    final key = await getPrivateKey(KeyPurpose.decryptSecretShare);
    final secret = ev.keyShare.decrypt(
      recipientKey: key,
      senderKey: Client._getParticipantPubkeyForId(config, sender),
    );

    // If the secret was invalid then the participant is misbehaving
    // This is an example of where DoS protection is needed.
    if (secret == null) return;

    // Add secret to storage if it correctly belongs to the key
    final newDetails = keyDetails.addSecretShare(sender, secret);
    if (newDetails == null) return;
    await _store.addOrReplaceFrostKey(newDetails);

    if (sendClientEvent) {
      _sendEvent(
        SecretShareClientEvent(keyDetails: newDetails, sender: sender),
      );
    }

    // If completed, let server know
    if (newDetails.keyConstruction is KeyConstructionComplete) {
      await api.ackKeyConstructed(
        sid: _state.sessionID,
        constructedKey: Signed.sign(
          obj: KeyWasConstructed(ev.groupKey),
          key: key,
        ),
      );
    }
  });

  Future<void> _shareKeySecret(
    cl.ECCompressedPublicKey groupKey, {
    Set<Identifier>? toWhom,
  }) async {
    final toWhomFinal = toWhom ?? config.otherIds;

    if (!_keys.containsKey(groupKey)) {
      throw ArgumentError.value(groupKey, "groupKey", "doesn't exist");
    }
    if (!config.otherIds.containsAll(toWhomFinal)) {
      throw ArgumentError.value(
        toWhom,
        "toWhom",
        "has non-existing identifier",
      );
    }

    await _runKeyDetailsSyncIfExists(groupKey, (keyDetails) async {
      // Share with those we haven't shared with before
      final needToShare = toWhomFinal
          .where((id) => !keyDetails.secretShareTimes.containsKey(id))
          .toSet();

      await _processSecretSharing(keyDetails, needToShare);
    });
  }

  Future<void> _runKeyDetailsSyncIfExists(
    cl.ECCompressedPublicKey groupKey,
    FutureOr<void> Function(FrostKeyWithDetails) criticalSection,
  ) async {
    if (!_keys.containsKey(groupKey)) return;
    final lock = _keyLocks.putIfAbsent(groupKey, () => Object());

    await lock.synchronized(() async {
      final key = _keys[groupKey];
      if (key == null) return;
      await criticalSection(key);
    });
  }
}

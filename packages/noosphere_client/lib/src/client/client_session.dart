part of 'client.dart';

Future<Client> _loginClient({
  required ClientConfig config,
  required ApiRequestInterface api,
  required ClientStorageInterface store,
  required GetPrivateKey getPrivateKey,
  void Function()? onDisconnect,
}) async {
  // Get key and load storage
  final key = await getPrivateKey(KeyPurpose.login);
  final cachedStore = await ClientCachedStorage.load(store);

  // Login with server
  final resp1 = await api.login(
    groupFingerprint: config.group.fingerprint,
    participantId: config.id,
  );
  final resp2 = await api.respondToChallenge(
    Signed.sign(obj: resp1.challenge, key: key),
  );

  // Do verification of details without state processing first

  // Verify online participants
  Client._checkIdentifierSet(config, resp2.onlineParticipants);

  // Verify DKGs
  for (final dkg in resp2.newDkgs) {
    Client._checkNewDkg(config, dkg);
  }

  // Check there are no duplicates
  final names = resp2.newDkgs.map((dkg) => dkg.details.obj.name);
  if (names.length != names.toSet().length) {
    throw ServerMisbehaviour.duplicateDkg();
  }

  // Verify Signatures Requests
  for (final req in resp2.sigRequests) {
    Client._checkDetailsEvent(config, req);
    Client._checkSignaturesProgress(config, req.progress);
  }

  // Check for duplicate requests
  {
    final ids = resp2.sigRequests.map((req) => req.details.obj.id);
    if (ids.length != ids.toSet().length) {
      throw ServerMisbehaviour.duplicateSigsReq();
    }
  }

  // Check duplicate signature request in rounds
  {
    final ids = resp2.sigRounds.map((rounds) => rounds.reqId);
    if (ids.length != ids.toSet().length) {
      throw ServerMisbehaviour.duplicateSigsReqRounds();
    }
  }

  // Check signature rounds
  for (final round in resp2.sigRounds) {
    Client._checkRounds(config, round.rounds);
    // Must have signature request for rounds
    if (!resp2.sigRequests.any((req) => req.details.obj.id == round.reqId)) {
      throw ServerMisbehaviour.missingSigsReq();
    }
  }

  // Check completed signature details
  for (final completedSig in resp2.completedSigs) {
    Client._checkSigned(config, completedSig.details, completedSig.creator);
  }

  // Check secret share events
  for (final secretShare in resp2.secretShares) {
    Client._checkOtherParticipantId(config, secretShare.sender);
  }

  final client = Client._(
    config: config,
    api: api,
    store: cachedStore,
    sessionID: resp2.id,
    sessionExpiry: resp2.expiry,
    events: resp2.events,
    getPrivateKey: getPrivateKey,
    onDisconnect: onDisconnect ?? () {},
  );

  // Add the online participants
  client._state.onlineParticipants = resp2.onlineParticipants;

  // Add DKGs to state
  for (final dkg in resp2.newDkgs) {
    final details = dkg.details.obj;
    if (details.expiry.isExpired) continue;
    client._addDkgToState(
      config: config,
      details: details,
      creator: dkg.creator,
      commitments: dkg.commitments,
    );
  }

  // Add signature requests to state
  for (final req in resp2.sigRequests) {
    await client._handleSigsReq(
      signed: req.details,
      creator: req.creator,
      progress: req.progress,
    );
  }

  // Handle signature rounds
  for (final round in resp2.sigRounds) {
    final sigReq = client._state.sigRequests[round.reqId];
    // It may be null if expired or otherwise rejected so ignore in those
    // cases
    if (sigReq != null) await client._handleRounds(sigReq, round.rounds);
  }

  // Handle completed signatures as immediate events
  for (final completedSig in resp2.completedSigs) {
    await client._handleCompletedSignatures(
      details: completedSig.details.obj,
      signatures: completedSig.signatures,
      creator: completedSig.creator,
    );
  }

  // Request ACKs that are needed
  // Do not await for these ACKs but capture errors as events
  () async {
    try {
      await client._requestAcks(config.otherIds);
    } catch (e) {
      client._sendError(e);
    }
  }();

  // Resend secrets sent before the server start time
  for (final key in client._keys.values) {
    final toResend = {
      for (final MapEntry(key: id, value: time) in key.secretShareTimes.entries)
        if (time.isBefore(resp2.startTime)) id,
    };

    await client._processSecretSharing(key, toResend);
  }

  // Process secret shares
  for (final secret in resp2.secretShares) {
    await client._processSecretShareEvent(secret);
  }

  return client;
}

extension _ClientSession on Client {
  Future<void> _extendSession() async {
    try {
      _state.expiry = await api.extendSession(_state.sessionID);
      _setSessionExtendTimer();
    } catch (e) {
      // Emit error
      _sendError(e);
    }
  }

  void _setSessionExtendTimer() {
    final wait = _state.expiry.time
        .subtract(Client._extendBufferTime)
        .difference(DateTime.now());

    _state.sessionExtension = Timer(
      wait.compareTo(Client._minWait) < 0 ? Client._minWait : wait,
      () => _extendSession(),
    );
  }
}

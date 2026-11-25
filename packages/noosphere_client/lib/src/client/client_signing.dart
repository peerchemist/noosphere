part of 'client.dart';

final class _SigningSync {
  final id = OnetimeNumber();
  final applied = Completer<bool>();
  late final Future<bool> result;

  void fail(Object error) {
    if (!applied.isCompleted) applied.completeError(error);
  }
}

extension _ClientSigning on Client {
  Future<bool> _syncSigningRequests(Duration timeout) {
    if (_disconnecting || _state.expiry.isExpired) {
      return Future.error(StateError('Client is disconnected'));
    }
    if (_signingSnapshotUnsupported) return Future.value(false);
    if (_signingSync case final pending?) return pending.result;
    if (timeout <= Duration.zero) {
      return Future.error(ArgumentError.value(timeout, 'timeout'));
    }
    final sync = _SigningSync();
    _signingSync = sync;
    return sync.result = Future.any<bool>([
      sync.applied.future,
      Future.sync(
        () => api.getSigningSnapshot(
          sid: _state.sessionID,
          correlationId: sync.id,
        ),
      ).then<bool>((supported) {
        if (supported) return sync.applied.future;
        _signingSnapshotUnsupported = true;
        return false;
      }),
    ]).timeout(timeout).whenComplete(() => _signingSync = null);
  }

  Future<void> _applySigningSnapshot(SigningSnapshotEvent snapshot) =>
      _sigReqLock.synchronized(() async {
        final sync = _signingSync;
        if (sync == null ||
            sync.id != snapshot.correlationId ||
            sync.applied.isCompleted ||
            _disconnecting ||
            _state.expiry.isExpired) {
          return;
        }

        _store.requireReady();
        for (final tombstone in snapshot.cancellations) {
          if (!tombstone.expiry.isExpired) {
            await _handleCancellation(tombstone);
          }
        }
        if (!identical(sync, _signingSync) ||
            _disconnecting ||
            _state.expiry.isExpired) {
          return;
        }

        final seen = <SignaturesRequestId>{};
        for (final request in snapshot.requests) {
          final details = request.details.obj;
          final id = details.id;
          if (details.expiry.isExpired ||
              _store.cancelledRequests.containsKey(id)) {
            continue;
          }
          final existing = _state.sigRequests[id];
          if (_terminalSigningRequests.containsKey(id)) continue;
          if (!seen.add(id)) throw ServerMisbehaviour.duplicateSigsReq();
          Client._checkDetailsEvent(config, request);
          final progress = request.progress;
          Client._checkSignaturesProgress(config, progress);
          if (progress.stage != SignaturesProgressStage.collecting &&
              progress.stage != SignaturesProgressStage.signing) {
            throw ServerMisbehaviour('Terminal progress in pending snapshot');
          }

          if (existing != null &&
              (existing.creator != request.creator ||
                  !cl.bytesEqual(
                    existing.details.toBytes(),
                    details.toBytes(),
                  ))) {
            throw ServerMisbehaviour('Signing snapshot changed a proposal');
          }
          if (!_hasSigningKeys(details)) continue;
          _checkSigningThreshold(details, progress);
          if (existing == null) {
            // An ambiguous local RPC still requires the ordinary recovery path.
            if (_store.preparedSigOperations.containsKey(id)) continue;
            final state = _addPendingSigningRequest(
              details,
              request.creator,
              progress,
            );
            _sendEvent(SignaturesRequestClientEvent(_sigsStateToObj(state)));
          } else if (existing.progress.stage != progress.stage ||
              existing.progress.threshold != progress.threshold ||
              !const SetEquality<Identifier>().equals(
                existing.progress.contributingParticipants,
                progress.contributingParticipants,
              )) {
            _publishSigningProgress(existing, progress);
          }
        }
        if (!sync.applied.isCompleted) sync.applied.complete(true);
      });

  bool _hasSigningKeys(SignaturesRequestDetails details) =>
      details.requiredSigs.every((sig) => _keys.containsKey(sig.groupKey));

  void _publishSigningProgress(
    ClientSigsState request,
    SignaturesProgress progress,
  ) {
    request.progress = progress;
    _sendEvent(SignaturesProgressClientEvent(_sigsStateToObj(request)));
  }

  void _checkSigningThreshold(
    SignaturesRequestDetails details,
    SignaturesProgress progress,
  ) {
    if (!details.requiredSigs.any(
      (sig) =>
          _keys[sig.groupKey]!.keyInfo.group.threshold == progress.threshold,
    )) {
      throw ServerMisbehaviour('Invalid signatures progress threshold');
    }
  }

  ClientSigsState _addPendingSigningRequest(
    SignaturesRequestDetails details,
    Identifier creator,
    SignaturesProgress progress,
  ) => _state.sigRequests[details.id] = ClientSigsState(
    details: details,
    creator: creator,
    expiry: details.expiry.clampUpperTTL(config.maxSignaturesTTL),
    progress: progress,
  );

  // Caller holds the signing lane, shared with request/reply/round processing.
  Future<void> _handleCancellation(CancelledSignaturesRequest tombstone) async {
    _store.requireReady();
    if (_store.cancelledRequests.containsKey(tombstone.requestId)) return;
    try {
      await _store.cancelSignaturesRequest(tombstone);
    } catch (_) {
      _disconnect();
      rethrow;
    }
    final active = _state.sigRequests.remove(tombstone.requestId);
    active?.pendingRounds.clear();
    _sendEvent(
      SignaturesCancelledClientEvent(
        requestId: tombstone.requestId,
        expiresAt: tombstone.expiry,
      ),
    );
  }

  Future<ClientSigsState?> _handleSigsReq({
    required Signed<SignaturesRequestDetails> signed,
    required Identifier creator,
    required SignaturesProgress progress,
  }) async {
    final details = signed.obj;
    _store.requireReady();
    if (_store.cancelledRequests.containsKey(details.id)) return null;
    if (details.expiry.isExpired) return null;
    Client._checkSignaturesProgress(config, progress);

    // Reject if we do not own any one of the keys
    if (!_hasSigningKeys(details)) {
      await _store.addRejectedSigsRequest(
        details.id,
        details.expiry.clampUpperTTL(config.maxSignaturesTTL),
      );
      await api.rejectSignaturesRequest(
        sid: _state.sessionID,
        reqId: details.id,
      );
      return null;
    }

    _checkSigningThreshold(details, progress);
    final sigsState = _addPendingSigningRequest(details, creator, progress);

    // Re-deliver a durable rejection after reconnecting. The storage decision
    // remains authoritative if the previous RPC reply was lost.
    if (_store.sigsRejected.containsKey(details.id)) {
      await api.rejectSignaturesRequest(
        sid: _state.sessionID,
        reqId: details.id,
      );
      return sigsState;
    }

    // A previous operation without a confirmed response is unsafe to resume.
    // Reject it explicitly when it reappears in a new session snapshot.
    if (_store.preparedSigOperations.containsKey(details.id)) {
      await _rejectSigsReq(sigsState);
    }

    return sigsState;
  }

  SignPart1 _getSignPart1(SingleSignatureDetails details) =>
      SignPart1(privateShare: _keys[details.groupKey]!.keyInfo.private.share);

  List<SignPart1> _getSignPart1s(SignaturesRequestDetails details) =>
      details.requiredSigs.map(_getSignPart1).toList();

  PreparedSignaturesOperation _preparedSignaturesOperation({
    required SignaturesRequestDetails details,
    required PreparedSignaturesOperationKind kind,
    required List<Uint8List> payloads,
    required List<Uint8List> transcripts,
    required Map<int, SigningNonces> nextNonces,
  }) => PreparedSignaturesOperation(
    id: details.id,
    kind: kind,
    payloads: payloads,
    transcripts: transcripts,
    nextNonces: SignaturesNonces(nextNonces, details.expiry),
  );

  Future<void> _handlePossibleRoundsResponse(
    ClientSigsState sigsState,
    SignaturesResponse? resp,
  ) async {
    if (resp is SignatureNewRoundsResponse) {
      Client._checkRounds(config, resp.rounds);
      await _handleRounds(sigsState, resp.rounds);
    }
  }

  Future<void> _initialSigning(ClientSigsState sigsState) async {
    final details = sigsState.details;
    final numSigs = details.requiredSigs.length;
    final part1s = _getSignPart1s(details);
    final replies = List.generate(
      numSigs,
      (i) => SignatureReply(sigI: i, nextCommitment: part1s[i].commitment),
    );

    await _store.prepareSignaturesOperation(
      operation: _preparedSignaturesOperation(
        details: details,
        kind: PreparedSignaturesOperationKind.replies,
        payloads: replies.map((reply) => reply.toBytes()).toList(),
        transcripts: const [],
        nextNonces: {
          for (int i = 0; i < part1s.length; i++) i: part1s[i].nonces,
        },
      ),
      capacity: numSigs,
    );

    // Provide commitments to server
    final resp = await api.submitSignatureReplies(
      sid: _state.sessionID,
      reqId: details.id,
      replies: replies,
    );
    await _store.completeSignaturesOperation(details.id);

    // Shouldn't have a completed signatures after providing initial commitments
    if (resp is SignaturesCompleteResponse) {
      throw ServerMisbehaviour.prematureSigs();
    }

    await _handlePossibleRoundsResponse(sigsState, resp);
  }

  HDParticipantKeyInfo _infoForSig(SingleSignatureDetails details) =>
      details.derive(
        HDParticipantKeyInfo.masterFromInfo(_keys[details.groupKey]!.keyInfo),
      );

  Future<void> _handleRounds(
    ClientSigsState sigsState,
    List<SignatureRoundStart> rounds,
  ) async {
    final sigDetails = sigsState.details;
    final requiredSigs = sigDetails.requiredSigs;
    final reqId = sigDetails.id;

    for (final round in rounds) {
      // Check signature index
      if (round.sigI >= requiredSigs.length) {
        throw ServerMisbehaviour.sigRoundOutOfRange();
      }

      // If we already have a pending round, the server shouldn't have
      // sent this event
      if (sigsState.pendingRounds.any(
        (pending) => round.sigI == pending.sigI,
      )) {
        throw ServerMisbehaviour.duplicateSignRound();
      }

      // Check number of commitments equals threshold
      final key = _keys[requiredSigs[round.sigI].groupKey]!;
      final threshold = key.keyInfo.group.threshold;
      if (round.commitments.map.length != threshold) {
        throw ServerMisbehaviour.wrongCommitmentNum();
      }
    }

    final nonces = _store.sigNonces[reqId];

    // Check we have nonces. If we don't then either the server is
    // providing an invalid round or storage of the nonces failed.
    // In this case, reject the signature.
    if (nonces == null ||
        !rounds.every((round) => nonces.map.containsKey(round.sigI))) {
      await _rejectSigsReq(sigsState);
      return;
    }

    // Add pending rounds
    sigsState.pendingRounds.addAll(rounds);

    // If the request isn't in a rejected state, continue with signing
    if (!_store.sigsRejected.containsKey(reqId)) {
      await _continueSigning(sigsState);
    }
  }

  void _checkSigsNotEmpty(List<cl.SchnorrSignature> signatures) {
    if (signatures.isEmpty) throw ServerMisbehaviour.emptySignatures();
  }

  // Continue processing ROAST, providing commitments and signature shares if
  // required.
  Future<void> _continueSigning(ClientSigsState sigsState) async {
    final details = sigsState.details;
    final reqId = details.id;
    final nonces = _store.sigNonces[reqId];

    // A prepared operation means that a previous network outcome is unknown.
    // Do not risk advancing this request with state the server may not share.
    if (_store.preparedSigOperations.containsKey(reqId)) {
      await _rejectSigsReq(sigsState);
      return;
    }

    // If no nonces have been produced yet, generate nonces and provide the
    // commitments
    if (nonces == null) {
      await _initialSigning(sigsState);
      return;
    }

    // There are nonces, so continue with rounds if there are any pending
    if (sigsState.pendingRounds.isEmpty) return;

    final Map<int, SigningNonces> newNonces = {};
    final List<SignatureReply> replies = [];

    for (final round in sigsState.pendingRounds) {
      final i = round.sigI;
      final requiredSig = details.requiredSigs[i];
      final sigNonces = nonces.map[i]!;

      late SignatureShare share;
      try {
        share = SignPart2(
          identifier: config.id,
          details: requiredSig.signDetails,
          ourNonces: sigNonces,
          commitments: round.commitments,
          info: _infoForSig(requiredSig).signing,
        ).share;
      } on InvalidSignPart2 {
        // If there is a failure, then it may be due to old nonces not having
        // been replaced due to previous network failure or client crash, so
        // reject signature.
        await _rejectSigsReq(sigsState);
        return;
      }

      // Get next part 1 including nonce
      final part1 = _getSignPart1(requiredSig);
      newNonces[i] = part1.nonces;

      replies.add(
        SignatureReply(sigI: i, nextCommitment: part1.commitment, share: share),
      );
    }

    await _store.prepareSignaturesOperation(
      operation: _preparedSignaturesOperation(
        details: details,
        kind: PreparedSignaturesOperationKind.replies,
        payloads: replies.map((reply) => reply.toBytes()).toList(),
        transcripts: sigsState.pendingRounds
            .map((round) => round.toBytes())
            .toList(),
        nextNonces: newNonces,
      ),
      capacity: details.requiredSigs.length,
    );

    final resp = await api.submitSignatureReplies(
      sid: _state.sessionID,
      reqId: reqId,
      replies: replies,
    );
    await _store.completeSignaturesOperation(reqId);

    // Handled pending rounds, so remove them from the state
    sigsState.pendingRounds.clear();

    if (resp is SignaturesCompleteResponse) {
      // Signatures are complete so end here
      _checkSigsNotEmpty(resp.signatures);
      await _handleCompletedSignatures(
        details: sigsState.details,
        signatures: resp.signatures,
        creator: sigsState.creator,
      );
      return;
    }

    await _handlePossibleRoundsResponse(sigsState, resp);
  }

  Future<void> _handleCompletedSignatures({
    required SignaturesRequestDetails details,
    required List<cl.SchnorrSignature> signatures,
    required Identifier creator,
  }) async {
    _store.requireReady();
    if (_store.cancelledRequests.containsKey(details.id)) {
      throw ServerMisbehaviour(
        'Completed signatures received for a cancelled request',
      );
    }
    if (signatures.length != details.requiredSigs.length) {
      throw ServerMisbehaviour.wrongSigNum();
    }

    // Verify signatures
    for (int i = 0; i < signatures.length; i++) {
      final sigDetails = details.requiredSigs[i];
      final signDetails = sigDetails.signDetails;
      var key = _infoForSig(sigDetails).groupKey;

      if (signDetails.mastHash != null) {
        // Get tweaked BIP341 (Taproot) public key
        key = key.xonly.tweak(
          cl.Taproot.tweakHash(
            Uint8List.fromList([...key.x, ...signDetails.mastHash!]),
          ),
        )!;
      }

      if (!signatures[i].verify(key, signDetails.message)) {
        throw ServerMisbehaviour.invalidCompleteSig();
      }
    }

    // Durable cleanup must complete before the request disappears from the
    // cache or a completion event is published. A failed/unknown write leaves
    // the request blocked and recoverable after reconnecting.
    await _store.removeSigsRequest(details.id);

    // Remove signatures request state
    _state.sigRequests.remove(details.id);
    _terminalSigningRequests[details.id] = FinalExpirable(details.expiry);

    // Provide completed signatures as client event
    _sendEvent(
      SignaturesCompleteClientEvent(
        details: details,
        creator: creator,
        signatures: signatures,
      ),
    );
  }

  Future<void> _rejectSigsReq(ClientSigsState sigsState) async {
    final id = sigsState.details.id;
    if (_store.sigsRejected.containsKey(id)) return;
    // Record the decision before sending it. If the RPC outcome is unknown,
    // reconnecting still observes a rejected request and cannot consume its
    // nonce material by accepting it accidentally.
    await _store.addRejectedSigsRequest(id, sigsState.expiry);
    await api.rejectSignaturesRequest(sid: _state.sessionID, reqId: id);
  }

  Future<void> _requestSignatures(SignaturesRequestDetails details) async {
    // Check expiry
    if (!config.signaturesExpiryAcceptable(details.expiry)) {
      throw ArgumentError.value(
        details.expiry,
        "details.expiry",
        "not in range",
      );
    }

    // Avoid race conditions, trying to submit the same request multiple times
    await _sigReqLock.synchronized(() async {
      _store.requireReady();
      if (_disconnecting || _state.expiry.isExpired) {
        throw StateError('Client is disconnected');
      }
      // Check if exists
      if (_sigReqExists(details.id) ||
          _store.cancelledRequests.containsKey(details.id) ||
          _store.preparedSigOperations.containsKey(details.id)) {
        throw ArgumentError.value(details.id, "details.id", "exists");
      }

      // Obtain keys, ensuring they all exist
      final requiredKeys = details.requiredSigs
          .map((sig) => _keys[sig.groupKey])
          .toSet();
      if (requiredKeys.contains(null)) {
        throw ArgumentError("Signature requires non-existant key");
      }
      final aggregateKeys = requiredKeys
          .map((key) => key!.keyInfo.aggregate)
          .toSet();

      // Sign details
      final key = await getPrivateKey(KeyPurpose.signaturesDetails);
      final signedDetails = Signed.sign(obj: details, key: key);

      // Create commitments for signatures
      final part1s = _getSignPart1s(details);

      await _store.prepareSignaturesOperation(
        operation: _preparedSignaturesOperation(
          details: details,
          kind: PreparedSignaturesOperationKind.request,
          payloads: [
            ...aggregateKeys.map((key) => key.toBytes()),
            signedDetails.toBytes(),
            ...part1s.map((part1) => part1.commitment.toBytes()),
          ],
          transcripts: const [],
          nextNonces: {
            for (int i = 0; i < part1s.length; i++) i: part1s[i].nonces,
          },
        ),
        capacity: part1s.length,
      );

      // Submit to server
      await api.requestSignatures(
        sid: _state.sessionID,
        keys: aggregateKeys,
        signedDetails: signedDetails,
        commitments: part1s.map((part1) => part1.commitment).toList(),
      );
      await _store.completeSignaturesOperation(details.id);

      // Update state
      _state.sigRequests[details.id] = ClientSigsState(
        details: details,
        creator: config.id,
        expiry: details.expiry,
        progress: SignaturesProgress(
          threshold: aggregateKeys.fold<int>(
            0,
            (threshold, key) => key.group.threshold > threshold
                ? key.group.threshold
                : threshold,
          ),
          contributingParticipants: [config.id],
          stage: SignaturesProgressStage.collecting,
        ),
      );
    });
  }

  bool _sigReqExists(SignaturesRequestId id) =>
      _state.sigRequests.containsKey(id);

  Future<void> _runSigsReqSyncIfExists(
    SignaturesRequestId reqId,
    FutureOr<void> Function(ClientSigsState) criticalSection,
  ) async {
    await _sigReqLock.synchronized(() async {
      _store.requireReady();
      if (_disconnecting ||
          _state.expiry.isExpired ||
          _store.cancelledRequests.containsKey(reqId)) {
        return;
      }
      final sigsState = _state.sigRequests[reqId];
      if (sigsState == null) return;
      await criticalSection(sigsState);
    });
  }
}

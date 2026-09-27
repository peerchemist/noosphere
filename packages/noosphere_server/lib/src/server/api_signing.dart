part of 'api_handler.dart';

extension _ServerSigning on ServerApiHandler {
  Future<void> _requestSignatures({
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

  Future<void> _rejectSignaturesRequest({
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

  Future<SignaturesResponse?> _submitSignatureReplies({
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
}

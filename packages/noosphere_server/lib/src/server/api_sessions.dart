part of 'api_handler.dart';

extension _ServerSessions on ServerApiHandler {
  Future<ExpirableAuthChallengeResponse> _login({
    required Uint8List groupFingerprint,
    required Identifier participantId,
    int protocolVersion = ServerApiHandler.currentProtocolVersion,
  }) async {
    await _prepare();
    // Only accept the current development protocol.
    if (protocolVersion != ServerApiHandler.currentProtocolVersion) {
      throw InvalidRequest.invalidProtoVersion();
    }

    // Check fingerprint
    if (!cl.bytesEqual(groupFingerprint, config.group.fingerprint)) {
      throw InvalidRequest.groupMismatch();
    }

    _checkParticipantId(participantId);

    // Create challenge
    final challenge = AuthChallenge();
    final expiry = Expiry(config.challengeTTL);

    _state.challenges[challenge] = ChallengeDetails(
      id: participantId,
      expiry: expiry,
    );

    return ExpirableAuthChallengeResponse(challenge: challenge, expiry: expiry);
  }

  Future<LoginCompleteResponse> _respondToChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) async {
    final participant = await verifyChallenge(signedChallenge);
    return startSession(participant);
  }

  /// Verifies and consumes a challenge without creating a session.
  Future<Identifier> _verifyChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) async {
    await _prepare();
    // Get participant id for challenge and check expiry
    final details = _state.challenges[signedChallenge.obj];
    if (details == null) throw InvalidRequest.noChallenge();
    final pid = details.id;

    // Verify participant has signed the challenge
    if (!signedChallenge.verify(_getParticipantPubkeyForId(pid))) {
      throw InvalidRequest.invalidChallengeSig();
    }

    // Success

    // Remove challenge
    _state.challenges.remove(signedChallenge.obj);

    return pid;
  }

  /// Creates a fresh logical session for an already authenticated participant.
  /// Direct API calls start the session after challenge verification; Iroh
  /// waits for StartSession on the session stream.
  Future<LoginCompleteResponse> _startSession(Identifier pid) async {
    await _prepare();
    _checkParticipantId(pid);

    // Remove any old session
    final oldSession = _state.participantToSession[pid];
    if (oldSession != null) {
      await _endSession(oldSession);
    }

    // Obtain other logged in participants
    final online = _state.clientSessions.values
        .map((sess) => sess.participantId)
        .toSet();

    // Notify other sessions of login before new session is added
    _state.sendEventToAll(ParticipantStatusEvent(id: pid, loggedIn: true));

    // Create session
    final sessionId = SessionID();
    final expiry = Expiry(config.sessionTTL);

    late final ClientSession session;
    session = _state.participantToSession[pid] =
        _state.clientSessions[sessionId] = ClientSession(
          participantId: pid,
          sessionID: sessionId,
          expiry: expiry,
          // When the session stream is lost, remove the session and process the
          // logout immediately
          onLostStream: () {
            unawaited(_endSession(session));
          },
        );

    // If using keepalive, send periodic events
    if (config.keepAliveFreq != null) {
      Timer.periodic(config.keepAliveFreq!, (timer) {
        final session = _state.clientSessions[sessionId];
        if (session == null) timer.cancel();
        session?.sendEvent(KeepaliveEvent());
      });
    }

    return LoginCompleteResponse(
      id: sessionId,
      expiry: expiry,
      startTime: startTime,
      onlineParticipants: online,
      events: session.eventController.stream,

      newDkgs: _state.round1Dkgs
          .map(
            (dkg) => NewDkgEvent(
              details: dkg.details,
              creator: dkg.creator,
              commitments: dkg.round1.commitments,
            ),
          )
          .toList(),

      sigRequests: _state.sigRequests.values
          .map(
            (sig) => SignaturesRequestEvent(
              details: sig.details,
              creator: sig.creator,
            ),
          )
          .toList(),

      // Find rounds that the user is part of and hasn't provided a share yet
      sigRounds: _state.sigRequests.values
          .map(
            (sigReq) => SignatureNewRoundsEvent(
              reqId: sigReq.details.obj.id,
              rounds: sigReq.pendingRoundsForId(pid),
            ),
          )
          .where((newRounds) => newRounds.rounds.isNotEmpty)
          .toList(),

      completedSigs: _state.completedSigs.values
          .where((sigs) => !sigs.acks.contains(pid))
          .map(
            (sigs) => CompletedSignaturesRequest(
              details: sigs.details,
              signatures: sigs.signatures,
              creator: sigs.creator,
            ),
          )
          .toList(),

      secretShares: [
        for (final MapEntry(key: groupKey, value: sharingState)
            in _state.secretShares.entries)
          ...sharingState
              .getSharesForReceiver(pid)
              .map(
                (share) => SecretShareEvent(
                  sender: share.sender,
                  keyShare: share.share,
                  groupKey: groupKey,
                ),
              ),
      ],
    );
  }

  Future<Expiry> _extendSession(SessionID sid) async {
    await _prepare();
    final session = getSession(sid);
    return session.expiry = Expiry(config.sessionTTL);
  }
}

part of 'client.dart';

extension _ClientEvents on Client {
  Future<void> _handleEvent(Event ev) async {
    // After logout, the session shall be expired and no more events can be
    // processed
    if (_state.expiry.isExpired) return;

    try {
      switch (ev) {
        case ParticipantStatusEvent():
          Client._checkOtherParticipantId(config, ev.id);

          if (!ev.loggedIn) {
            _state.onlineParticipants.remove(ev.id);
          } else {
            _state.onlineParticipants.add(ev.id);

            // Ask for ACKs for logged in participant plus any logged out
            // participants that the logged in participant might have.
            await _requestAcks(
              config.otherIds
                  .where(
                    (id) =>
                        id == ev.id || !_state.onlineParticipants.contains(id),
                  )
                  .toSet(),
            );
          }

          _sendEvent(
            ParticipantStatusClientEvent(id: ev.id, loggedIn: ev.loggedIn),
          );

        case NewDkgEvent():
          Client._checkOtherParticipantId(config, ev.creator);
          Client._checkNewDkg(config, ev);

          final details = ev.details.obj;
          if (details.expiry.isExpired) return;

          // If DKG name already exists, it will be replaced
          // Run synchronously with other code that works on an existing DKG so
          // that DKG is not removed half-way through asynchronous code

          final existing = _state.nameToDkg[ev.details.obj.name];

          ClientDkgState setNew() => _addDkgToState(
            config: config,
            details: details,
            creator: ev.creator,
            commitments: ev.commitments,
          );

          if (existing != null) {
            if (!cl.bytesEqual(
              existing.details.ceremonyId,
              details.ceremonyId,
            )) {
              // Delayed traffic for an attempt that has already been replaced.
              return;
            }
            await existing.synchronized(() {
              final known = {
                for (final entry in existing.commitments) entry.$1: entry.$2,
              };
              for (final entry in ev.commitments) {
                final previous = known[entry.$1];
                if (previous != null &&
                    !cl.bytesEqual(previous.toBytes(), entry.$2.toBytes())) {
                  throw ServerMisbehaviour.changedDkgTranscript();
                }
                if (previous == null &&
                    existing.round is ClientDkgRound1State) {
                  existing.round1.commitments.add(entry);
                }
              }
            });
            _sendEvent(UpdatedDkgClientEvent(existing.progress(config.id)));
            return;
          }

          final dkg = setNew();

          _sendEvent(UpdatedDkgClientEvent(dkg.progress(config.id)));

        case DkgRejectEvent():
          Client._checkOtherParticipantId(config, ev.participant);

          await _runDkgSyncIfExists(ev.name, (dkg) {
            if (!cl.bytesEqual(dkg.details.ceremonyId, ev.ceremonyId)) return;
            _state.nameToDkg.remove(ev.name);
            _sendEvent(
              RejectedDkgClientEvent(
                details: dkg.details,
                participant: ev.participant,
              ),
            );
          });

        case DkgCommitmentEvent():
          Client._checkOtherParticipantId(config, ev.participant);

          await _runDkgSyncIfExists(ev.name, (dkg) async {
            if (!cl.bytesEqual(dkg.details.ceremonyId, ev.ceremonyId)) return;
            final existing = dkg.commitments
                .where((c) => c.$1 == ev.participant)
                .firstOrNull;
            if (existing != null) {
              if (!cl.bytesEqual(
                existing.$2.toBytes(),
                ev.commitment.toBytes(),
              )) {
                throw ServerMisbehaviour.changedDkgTranscript();
              }
              return;
            }
            if (dkg.round is! ClientDkgRound1State) {
              throw ServerMisbehaviour.commitmentNotRound1();
            }

            final round1 = dkg.round1;

            round1.commitments.add((ev.participant, ev.commitment));

            // If all commitments have been received, do part 2
            // Returns true if rejected, so do not send update event
            if (await _doPart2IfReady(dkg)) return;

            _sendEvent(UpdatedDkgClientEvent(dkg.progress(config.id)));
          });

        case DkgRound2ShareEvent():
          Client._checkOtherParticipantId(config, ev.sender);

          // Synchronise with ACKs to ensure the key is processed before
          // processing ACKs for it
          await _dkgAckLock.synchronized(
            () => _runDkgSyncIfExists(ev.name, (dkg) async {
              if (!cl.bytesEqual(dkg.details.ceremonyId, ev.ceremonyId)) return;
              if (dkg.missingSecret) return;
              if (dkg.round is! ClientDkgRound2State) {
                throw ServerMisbehaviour.secretNotRound2();
              }

              final round2 = dkg.round2;

              final senderKey = Client._getParticipantPubkeyForId(
                config,
                ev.sender,
              );

              // Verify commitment set and decrypt secret
              if (!ev.commitmentSetSignature.verify(
                senderKey,
                dkg.details.hashWithCommitments(round2.commitmentSet),
              )) {
                throw ServerMisbehaviour.invalidSignature();
              }

              final key = await getPrivateKey(KeyPurpose.decryptDkgSecret);

              final secret = ev.secret.decrypt(
                recipientKey: key,
                senderKey: senderKey,
              );

              if (secret == null) {
                // Cannot decrypt share so reject DKG
                await _rejectBadDkg(
                  details: dkg.details,
                  culprit: ev.sender,
                  fault: DkgFault.secretCiphertext,
                );
                return;
              }

              final previous = round2.secretShares[ev.sender];
              if (previous != null) {
                if (!cl.bytesEqual(previous.toBytes(), secret.toBytes())) {
                  throw ServerMisbehaviour.alreadyHaveSecret();
                }
                return;
              }

              // Add secret
              round2.secretShares[ev.sender] = secret;

              // Attempt to complete key if all secrets have been received
              if (round2.secretShares.length == config.groupN - 1) {
                await _doPart3(dkg);
              } else {
                // If not completed, provide update event
                _sendEvent(UpdatedDkgClientEvent(dkg.progress(config.id)));
              }
            }),
          );

        case DkgAckEvent():
          await _dkgAckLock.synchronized(() async {
            // Process in series to ensure storage is updated correctly
            // for each ACK
            for (final ack in ev.acks) {
              await _verifyAndAddAck(ack);
            }
          });

        case DkgAckRequestEvent():
          await _dkgAckLock.synchronized(() async {
            final Set<SignedDkgAck> toSend = {};

            for (final req in ev.requests) {
              final DkgAckRequest(
                :ids,
                :groupPublicKey,
                :ceremonyId,
                :transcriptHash,
              ) = req;

              Client._checkIdentifierSet(config, ids);

              if (_store.keys.containsKey(groupPublicKey)) {
                // As we have the key, send the _stored acks that we have for it
                toSend.addAll(_store.getAcksForRequest(req));
              } else if (ids.contains(config.id)) {
                // Haven't got key so send our own NACK
                toSend.add(
                  await _createDkgAck(
                    groupPublicKey,
                    false,
                    ceremonyId: ceremonyId,
                    transcriptHash: transcriptHash,
                  ),
                );
              }
            }

            if (toSend.isNotEmpty) {
              await api.sendDkgAcks(sid: _state.sessionID, acks: toSend);
            }
          });

        case SignaturesRequestEvent():
          await _sigReqLock.synchronized(() async {
            _store.requireReady();
            if (_store.cancelledRequests.containsKey(ev.details.obj.id)) return;
            Client._checkOtherParticipantId(config, ev.creator);
            Client._checkDetailsEvent(config, ev);
            if (_sigReqExists(ev.details.obj.id)) {
              throw ServerMisbehaviour.duplicateSigsReq();
            }

            final sigsState = await _handleSigsReq(
              signed: ev.details,
              creator: ev.creator,
              progress: ev.progress,
            );
            if (sigsState == null) return;

            _sendEvent(
              SignaturesRequestClientEvent(
                SignaturesRequest(
                  details: ev.details.obj,
                  creator: ev.creator,
                  expiry: sigsState.expiry,
                  status: SignaturesRequestStatus.waiting,
                  progress: sigsState.progress,
                ),
              ),
            );
          });

        case SignaturesProgressEvent():
          await _runSigsReqSyncIfExists(ev.reqId, (sigsState) async {
            Client._checkSignaturesProgress(config, ev.progress);
            final validThresholds = sigsState.details.requiredSigs
                .map(
                  (signature) =>
                      _keys[signature.groupKey]!.keyInfo.group.threshold,
                )
                .toSet();
            if (!validThresholds.contains(ev.progress.threshold)) {
              throw ServerMisbehaviour('Invalid signatures progress threshold');
            }
            sigsState.progress = ev.progress;
            _sendEvent(
              SignaturesProgressClientEvent(_sigsStateToObj(sigsState)),
            );
          });

        case SignaturesFailureEvent():
          await _runSigsReqSyncIfExists(ev.reqId, (sigsState) async {
            final removedState = _state.sigRequests.remove(ev.reqId);
            if (removedState != null) {
              _sendEvent(
                SignaturesFailureClientEvent(_sigsStateToObj(removedState)),
              );
            }
            await _store.removeSigsRequest(ev.reqId);
          });

        case SignatureNewRoundsEvent():
          await _runSigsReqSyncIfExists(ev.reqId, (sigsState) async {
            Client._checkRounds(config, ev.rounds);
            await _handleRounds(sigsState, ev.rounds);
          });

        case SignaturesCancelledEvent():
          await _sigReqLock.synchronized(
            () => _handleCancellation(
              CancelledSignaturesRequest(ev.requestId, ev.expiresAt),
            ),
          );

        case SignaturesCompleteEvent():
          await _sigReqLock.synchronized(() async {
            _store.requireReady();
            if (_store.cancelledRequests.containsKey(ev.reqId)) {
              throw ServerMisbehaviour(
                'Completed signatures received for a cancelled request',
              );
            }
            _checkSigsNotEmpty(ev.signatures);
            final sigsState = _state.sigRequests[ev.reqId];
            if (sigsState == null) return;
            await _handleCompletedSignatures(
              details: sigsState.details,
              signatures: ev.signatures,
              creator: sigsState.creator,
            );
          });

        case SecretShareEvent():
          Client._checkOtherParticipantId(config, ev.sender);
          await _processSecretShareEvent(ev, sendClientEvent: true);

        case ConstructedKeyEvent():
          Client._checkOtherParticipantId(config, ev.participant);
          Client._checkSigned(config, ev.constructedKey, ev.participant);

          await _runKeyDetailsSyncIfExists(ev.constructedKey.obj.publicKey, (
            keyDetails,
          ) async {
            await _store.addOrReplaceFrostKey(
              keyDetails.addClaimedToHave(ev.participant),
            );
          });

        case KeepaliveEvent():
        // Do nothing, this is only to keep middleware happy
      }
    } catch (e) {
      _sendError(e);
    }
  }
}

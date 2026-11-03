import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/wire.dart' as wire;
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/server/state/snapshot_reservations.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'data.dart';
import 'sig_data.dart';
import 'test_keys.dart';

void main() {
  setUpAll(loadFrosty);

  Future<LoginCompleteResponse> login(ServerApiHandler api, int i) async {
    final challenge = await api.login(
      groupFingerprint: api.config.group.fingerprint,
      participantId: Identifier.fromUint16(i + 1),
    );
    final response = await api.respondToChallenge(
      signObject(challenge.challenge, i),
    );
    unawaited(response.events.drain<void>());
    final encoded = wire.SessionStarted(
      sessionId: response.id.toBytes(),
      snapshot: response.toBytes(),
    ).writeToBuffer();
    expect(encoded.length, lessThanOrEqualTo(api.maxSessionSnapshotBytes));
    expect(
      encoded.length,
      lessThanOrEqualTo(
        api.debugState.reservedSessionSnapshotBytes(
          api.config.group.participants.length,
        ),
      ),
    );
    wire.encodeLengthPrefixedMessage(
      encoded,
      maxMessageLength: api.maxSessionSnapshotBytes,
    );
    return response;
  }

  Future<void> expectCapacity(
    ServerApiHandler api,
    Future<void> Function() action,
  ) async {
    final before = api.state.toBytes();
    await expectLater(
      action(),
      throwsA(
        isA<InvalidRequest>().having(
          (error) => error.message,
          'message',
          'Session snapshot capacity exceeded',
        ),
      ),
    );
    expect(api.state.toBytes(), before);
  }

  test(
    'reserve full DKG growth before accepting the oversized reconnect workload',
    () async {
      final roster = List.generate(64, (i) => Identifier.fromUint16(i + 1));
      final config = ServerConfig(
        group: GroupConfig(
          id: 'snapshot-dkg',
          participants: {
            for (var i = 0; i < roster.length; i++)
              roster[i]: cl.ECCompressedPublicKey.fromPubkey(
                getPrivkey(i).pubkey,
              ),
          },
        ),
      );
      final persistence = InMemoryServerPersistence();
      var api = ServerApiHandler(config: config, persistence: persistence);
      addTearDown(() => api.shutdown());
      final sessions = [for (var i = 0; i < 64; i++) (await login(api, i)).id];
      final accepted = <(Signed<NewDkgDetails>, List<DkgPart1>)>[];
      Signed<NewDkgDetails>? denied;
      DkgPublicCommitment? deniedCommitment;
      for (var i = 0; i < 9; i++) {
        final signed = signObject(
          getDkgDetails(
            name: 'ceremony-$i',
            threshold: 64,
            groupFingerprint: config.group.fingerprint,
          ),
          i,
        );
        final parts = [
          for (final id in roster)
            DkgPart1(identifier: id, threshold: 64, n: 64),
        ];
        final before = api.state.toBytes();
        try {
          await api.requestNewDkg(
            sid: sessions[i],
            signedDetails: signed,
            commitment: parts[i].public,
          );
          accepted.add((signed, parts));
        } on InvalidRequest catch (error) {
          expect(error.message, 'Session snapshot capacity exceeded');
          expect(api.state.toBytes(), before);
          denied = signed;
          deniedCommitment = parts[i].public;
          break;
        }
      }
      expect(denied, isNotNull);
      expect(accepted.length, greaterThan(1));
      final reserved = api.debugState.reservedSessionSnapshotBytes(64);
      // Later contributions must fit even though almost all reserved space is
      // unused when admission first refuses the next ceremony.
      for (var creator = 0; creator < accepted.length; creator++) {
        final (signed, parts) = accepted[creator];
        for (var i = 0; i < 64; i++) {
          if (i == creator) continue;
          await api.submitDkgCommitment(
            sid: sessions[i],
            name: signed.obj.name,
            ceremonyId: signed.obj.ceremonyId,
            commitment: parts[i].public,
          );
        }
      }
      expect(api.debugState.reservedSessionSnapshotBytes(64), reserved);
      for (final i in [0, 32, 63]) {
        expect((await login(api, i)).newDkgs.length, accepted.length);
      }
      await api.shutdown();
      api = ServerApiHandler(config: config, persistence: persistence);
      await api.ready;
      expect(api.debugState.reservedSessionSnapshotBytes(64), reserved);
      final creator = accepted.length;
      final session = await login(api, creator);
      Future<void> retry() => api.requestNewDkg(
        sid: session.id,
        signedDetails: denied!,
        commitment: deniedCommitment!,
      );
      await expectCapacity(api, retry);
      await api.rejectDkg(
        sid: session.id,
        name: accepted.first.$1.obj.name,
        ceremonyId: accepted.first.$1.obj.ceremonyId,
      );
      await retry();
      await login(api, 0);

      final tooSmall = ServerApiHandler(
        config: config,
        persistence: persistence,
        maxSessionSnapshotBytes: SnapshotReservations.header(64),
      );
      await expectLater(tooSmall.ready, throwsFormatException);
    },
  );

  test(
    'signing reserves rounds and completion; cancellation releases capacity',
    () async {
      final info = getAggregateKeyInfo();
      Signed<SignaturesRequestDetails> details(String message) => signObject(
        SignaturesRequestDetails(
          requiredSigs: [
            for (var i = 0; i < 2; i++)
              SingleSignatureDetails(
                signDetails: getSignDetails(i),
                groupKey: info.groupKey,
                hdDerivation: [],
              ),
          ],
          expiry: futureExpiry,
          message: message,
        ),
      );
      final first = details('a');
      final second = details('b');
      final third = details('c');
      final budget =
          SnapshotReservations.header(10) +
          2 * SnapshotReservations.signing(first, 10);
      final api = ServerApiHandler(
        config: ServerConfig(group: groupConfig),
        persistence: InMemoryServerPersistence(),
        maxSessionSnapshotBytes: budget,
      );
      addTearDown(api.shutdown);
      var creator = await login(api, 0);
      final other = await login(api, 1);
      final parts = [
        for (var p = 0; p < 2; p++)
          [for (var i = 0; i < 2; i++) getSignPart1(i: p)],
      ];
      Future<void> request(Signed<SignaturesRequestDetails> signed) =>
          api.requestSignatures(
            sid: creator.id,
            keys: {info},
            signedDetails: signed,
            commitments: parts[0].map((part) => part.commitment).toList(),
          );
      await request(first);
      // Use independent nonces for the second request.
      await api.requestSignatures(
        sid: creator.id,
        keys: {info},
        signedDetails: second,
        commitments: [for (var i = 0; i < 2; i++) getSignPart1().commitment],
      );
      await expectCapacity(api, () => request(third));
      final rounds = await api.submitSignatureReplies(
        sid: other.id,
        reqId: first.obj.id,
        replies: [
          for (var i = 0; i < 2; i++)
            SignatureReply(sigI: i, nextCommitment: parts[1][i].commitment),
        ],
      ) as SignatureNewRoundsResponse;
      creator = await login(api, 0);
      expect(creator.sigRounds.single.rounds.length, 2);
      for (var p = 0; p < 2; p++) {
        await api.submitSignatureReplies(
          sid: p == 0 ? creator.id : other.id,
          reqId: first.obj.id,
          replies: [
            for (var i = 0; i < 2; i++)
              SignatureReply(
                sigI: i,
                nextCommitment: getSignPart1(i: p).commitment,
                share: SignPart2(
                  identifier: ids[p],
                  details: first.obj.requiredSigs[i].signDetails,
                  ourNonces: parts[p][i].nonces,
                  commitments: rounds.rounds[i].commitments,
                  info: getParticipantKeyInfo(i: p).signing,
                ).share,
              ),
          ],
        );
      }
      creator = await login(api, 0);
      expect(creator.completedSigs.single.signatures.length, 2);
      await expectCapacity(api, () => request(third));
      await api.cancelSignaturesRequest(sid: creator.id, reqId: second.obj.id);
      await api.requestSignatures(
        sid: creator.id,
        keys: {info},
        signedDetails: third,
        commitments: [for (var i = 0; i < 2; i++) getSignPart1().commitment],
      );
      final replay = await login(api, 0);
      expect(replay.cancelledRequests.length, 1);
      expect(replay.completedSigs.length, 1);
      expect(replay.sigRequests.length, 1);
    },
  );

  test('recovery reserves every sender and shares a budget with DKG', () async {
    final dkg = signObject(getDkgDetails());
    final budget =
        SnapshotReservations.header(10) +
        SnapshotReservations.dkg(dkg, 10) +
        SnapshotReservations.recoveryKey(10);
    final persistence = InMemoryServerPersistence();
    var api = ServerApiHandler(
      config: ServerConfig(group: groupConfig),
      persistence: persistence,
      maxSessionSnapshotBytes: budget,
    );
    addTearDown(() => api.shutdown());
    var sessions = [for (var i = 0; i < 10; i++) (await login(api, i)).id];
    await api.requestNewDkg(
      sid: sessions[0],
      signedDetails: dkg,
      commitment: getDkgPart1(0).public,
    );
    final extraKey = cl.ECCompressedPublicKey.fromPubkey(getPrivkey(99).pubkey);
    Future<void> attest(cl.ECCompressedPublicKey key) => api.sendDkgAcks(
      sid: sessions[0],
      acks: {for (var i = 0; i < 10; i++) getDkgAck(i, true, groupKey: key)},
    );
    Future<void> share(
      int sender,
      int recipient,
      cl.ECCompressedPublicKey key,
    ) async {
      await api.shareSecretShare(
        sid: sessions[sender],
        groupKey: key,
        encryptedSecrets: {
          ids[recipient]: EncryptedKeyShare(
            ECCiphertext.encrypt(
              plaintext: Uint8List(192),
              senderKey: getPrivkey(sender),
              recipientKey: getPrivkey(recipient).pubkey,
            ),
          ),
        },
      );
    }

    await attest(groupPublicKey);
    await attest(extraKey);
    await share(0, 1, groupPublicKey);
    await expectCapacity(api, () => share(0, 1, extraKey));
    expect(api.debugState.secretShares.containsKey(extraKey), isFalse);
    for (var i = 2; i < 10; i++) {
      await share(i, 1, groupPublicKey);
    }
    final replay = await login(api, 1);
    expect(replay.secretShares.length, 9);
    await api.shutdown();
    api = ServerApiHandler(
      config: ServerConfig(group: groupConfig),
      persistence: persistence,
      maxSessionSnapshotBytes: budget,
    );
    sessions = [for (var i = 0; i < 10; i++) (await login(api, i)).id];
    await attest(extraKey);
    await expectCapacity(api, () => share(0, 1, extraKey));
    // Completion of one recipient does not discard reservations for others.
    for (var i = 0; i < 10; i++) {
      await share((i + 1) % 10, i, groupPublicKey);
      await api.ackKeyConstructed(
        sid: sessions[i],
        constructedKey: signObject(KeyWasConstructed(groupPublicKey), i),
      );
    }
    await share(0, 1, extraKey);
    expect((await login(api, 1)).secretShares.length, 1);
  });

  test('oversized commitments cannot exceed a DKG reservation', () async {
    final api = ServerApiHandler(
      config: ServerConfig(group: groupConfig),
      persistence: InMemoryServerPersistence(),
    );
    addTearDown(api.shutdown);
    final creator = await login(api, 0);
    final other = await login(api, 1);
    final details = signObject(getDkgDetails(threshold: 2));
    final oversized = DkgPart1(identifier: ids[1], threshold: 10, n: 10).public;
    await expectLater(
      api.requestNewDkg(
        sid: creator.id,
        signedDetails: details,
        commitment: oversized,
      ),
      throwsA(isA<InvalidRequest>()),
    );
    await api.requestNewDkg(
      sid: creator.id,
      signedDetails: details,
      commitment: getDkgPart1(0).public,
    );
    final before = api.state.toBytes();
    await expectLater(
      api.submitDkgCommitment(
        sid: other.id,
        name: details.obj.name,
        ceremonyId: details.obj.ceremonyId,
        commitment: oversized,
      ),
      throwsA(isA<InvalidRequest>()),
    );
    expect(api.state.toBytes(), before);
  });
}

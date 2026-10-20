import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_client/testing.dart';

void main() {
  setUpAll(() async {
    await cl.loadCoinlib();
    await loadFrosty();
  });

  test('2-of-3 DKG completes across non-overlapping sessions and coordinator restarts', () async {
    final ids = List.generate(3, (i) => Identifier.fromUint16(i + 1));
    final identityKeys = List.generate(
      3,
      (i) => cl.ECPrivateKey(Uint8List(32)..last = i + 1),
    );
    final group = GroupConfig(
      id: 'resumable-dkg-test',
      participants: {
        for (var i = 0; i < ids.length; i++)
          ids[i]: cl.ECCompressedPublicKey.fromPubkey(identityKeys[i].pubkey),
      },
    );
    final config = ServerConfig(group: group);
    final persistence = InMemoryServerPersistence();
    var server = ServerApiHandler(config: config, persistence: persistence);
    await server.ready;

    Future<LoginCompleteResponse> login(int i) async {
      final challenge = await server.login(
        groupFingerprint: group.fingerprint,
        participantId: ids[i],
      );
      return server.respondToChallenge(
        Signed.sign(obj: challenge.challenge, key: identityKeys[i]),
      );
    }

    Future<void> disconnect(LoginCompleteResponse login) async {
      final session = server.sessionForTransport(login.id)!;
      await server.endSessionForTransport(session);
    }

    Future<void> restart() async {
      server = ServerApiHandler(config: config, persistence: persistence);
      await server.ready;
    }

    final details = NewDkgDetails(
      name: 'async-key',
      description: 'participants never overlap',
      threshold: 2,
      expiry: Expiry(const Duration(hours: 1)),
      groupFingerprint: group.fingerprint,
    );
    final signedDetails = Signed.sign(obj: details, key: identityKeys[0]);
    final part1 = List.generate(
      3,
      (i) => DkgPart1(identifier: ids[i], threshold: 2, n: 3),
    );

    var session = await login(0);
    await server.requestNewDkg(
      sid: session.id,
      signedDetails: signedDetails,
      commitment: part1[0].public,
    );
    await disconnect(session);

    session = await login(1);
    expect(
      (await server.getDkg(
        sid: session.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
      ))!.stage,
      DkgCeremonyStage.collectingCommitments,
    );
    await server.submitDkgCommitment(
      sid: session.id,
      name: details.name,
      ceremonyId: details.ceremonyId,
      commitment: part1[1].public,
    );
    await disconnect(session);
    await restart();

    session = await login(2);
    await server.submitDkgCommitment(
      sid: session.id,
      name: details.name,
      ceremonyId: details.ceremonyId,
      commitment: part1[2].public,
    );
    await expectLater(
      server.submitDkgCommitment(
        sid: session.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
        commitment: DkgPart1(identifier: ids[2], threshold: 2, n: 3).public,
      ),
      throwsA(isA<InvalidRequest>()),
    );
    // Exact retry after the stage transition is successful.
    await server.submitDkgCommitment(
      sid: session.id,
      name: details.name,
      ceremonyId: details.ceremonyId,
      commitment: part1[2].public,
    );
    await disconnect(session);

    final commitments = DkgCommitmentSet([
      for (var i = 0; i < ids.length; i++) (ids[i], part1[i].public),
    ]);
    final transcriptHash = details.hashWithCommitments(commitments);
    final part2 = List.generate(
      3,
      (i) => DkgPart2(
        identifier: ids[i],
        round1Secret: part1[i].secret,
        commitments: commitments,
      ),
    );
    final signatures = List.generate(
      3,
      (i) => cl.SchnorrSignature.sign(identityKeys[i], transcriptHash),
    );
    final ciphertexts = List.generate(
      3,
      (sender) => {
        for (var recipient = 0; recipient < ids.length; recipient++)
          if (recipient != sender)
            ids[recipient]: DkgEncryptedSecret.encrypt(
              secretShare: part2[sender].sharesToGive[ids[recipient]]!,
              protocolVersion: details.protocolVersion,
              ceremonyId: details.ceremonyId,
              transcriptHash: transcriptHash,
              sender: ids[sender],
              recipient: ids[recipient],
              recipientKey: identityKeys[recipient].pubkey,
              senderKey: identityKeys[sender],
            ),
      },
    );

    for (var sender = 0; sender < ids.length; sender++) {
      session = await login(sender);
      await server.submitDkgRound2(
        sid: session.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
        commitmentSetSignature: signatures[sender],
        secrets: ciphertexts[sender],
      );
      // Lost responses are reconciled by replaying the exact payload.
      await server.submitDkgRound2(
        sid: session.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
        commitmentSetSignature: signatures[sender],
        secrets: ciphertexts[sender],
      );
      if (sender == 0) {
        final conflicting = Map<Identifier, DkgEncryptedSecret>.of(
          ciphertexts[sender],
        );
        conflicting[ids[1]] = DkgEncryptedSecret.encrypt(
          secretShare: part2[sender].sharesToGive[ids[1]]!,
          protocolVersion: details.protocolVersion,
          ceremonyId: details.ceremonyId,
          transcriptHash: transcriptHash,
          sender: ids[sender],
          recipient: ids[1],
          recipientKey: identityKeys[1].pubkey,
          senderKey: identityKeys[sender],
        );
        await expectLater(
          server.submitDkgRound2(
            sid: session.id,
            name: details.name,
            ceremonyId: details.ceremonyId,
            commitmentSetSignature: signatures[sender],
            secrets: conflicting,
          ),
          throwsA(isA<InvalidRequest>()),
        );
      }
      await disconnect(session);
      if (sender == 0) {
        await restart();
        final next = await login(1);
        final progress = (await server.getDkg(
          sid: next.id,
          name: details.name,
          ceremonyId: details.ceremonyId,
        ))!;
        expect(progress.stage, DkgCeremonyStage.collectingShares);
        expect(progress.shareContributors, {ids[0]});
        await disconnect(next);
      }
    }

    final participantKeys = <ParticipantKeyInfo>[];
    for (var recipient = 0; recipient < ids.length; recipient++) {
      session = await login(recipient);
      final snapshot = (await server.getDkg(
        sid: session.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
      ))!;
      expect(snapshot.stage, DkgCeremonyStage.awaitingCompletion);
      expect(snapshot.shareContributors, ids.toSet());
      expect(snapshot.shares, hasLength(2));
      expect(
        snapshot.shares.map((share) => share.sender).toSet(),
        ids.toSet()..remove(ids[recipient]),
      );

      final received = <Identifier, DkgShareToGive>{};
      for (final share in snapshot.shares) {
        expect(
          share.commitmentSetSignature.verify(
            group.participants[share.sender]!,
            transcriptHash,
          ),
          isTrue,
        );
        final decrypted = share.secret.decrypt(
          protocolVersion: details.protocolVersion,
          ceremonyId: details.ceremonyId,
          transcriptHash: transcriptHash,
          sender: share.sender,
          recipient: ids[recipient],
          recipientKey: identityKeys[recipient],
          senderKey: group.participants[share.sender]!,
        );
        expect(decrypted, isNotNull);
        received[share.sender] = decrypted!;
      }
      participantKeys.add(
        DkgPart3(
          identifier: ids[recipient],
          round2Secret: part2[recipient].secret,
          commitments: commitments,
          receivedShares: received,
        ).participantInfo,
      );
      await disconnect(session);
    }
    expect(participantKeys.map((key) => key.groupKey).toSet(), hasLength(1));

    // The resulting key works with the same FROST operations used by ROAST.
    final message = Uint8List(32)..last = 42;
    final signDetails = SignDetails.scriptSpend(message: message);
    final signPart1 = [
      SignPart1(privateShare: participantKeys[0].private.share),
      SignPart1(privateShare: participantKeys[1].private.share),
    ];
    final signingCommitments = SigningCommitmentSet({
      ids[0]: signPart1[0].commitment,
      ids[1]: signPart1[1].commitment,
    });
    final shares = [
      for (var i = 0; i < 2; i++)
        SignPart2(
          identifier: ids[i],
          details: signDetails,
          ourNonces: signPart1[i].nonces,
          commitments: signingCommitments,
          info: participantKeys[i].signing,
        ).share,
    ];
    final signature = SignatureAggregation(
      commitments: signingCommitments,
      details: signDetails,
      shares: [(ids[0], shares[0]), (ids[1], shares[1])],
      info: participantKeys[0].aggregate,
    ).signature;
    expect(signature.verify(participantKeys[0].groupKey, message), isTrue);

    final completionAcks = <SignedDkgAck>[];
    for (var i = 0; i < ids.length; i++) {
      session = await login(i);
      if (i == 0) {
        final wrongTranscript = DkgAck(
          groupKey: participantKeys[i].groupKey,
          accepted: true,
          ceremonyId: details.ceremonyId,
          transcriptHash: Uint8List(32),
        );
        await expectLater(
          server.sendDkgAcks(
            sid: session.id,
            acks: {
              SignedDkgAck(
                signer: ids[i],
                signed: Signed.sign(obj: wrongTranscript, key: identityKeys[i]),
              ),
            },
          ),
          throwsA(isA<InvalidRequest>()),
        );
      }
      final ack = DkgAck(
        groupKey: participantKeys[i].groupKey,
        accepted: true,
        ceremonyId: details.ceremonyId,
        transcriptHash: transcriptHash,
      );
      final signedAck = SignedDkgAck(
        signer: ids[i],
        signed: Signed.sign(obj: ack, key: identityKeys[i]),
      );
      completionAcks.add(signedAck);
      if (i == 0) {
        final invalidLaterAck = SignedDkgAck(
          signer: ids[1],
          signed: Signed.sign(
            obj: DkgAck(
              groupKey: participantKeys[i].groupKey,
              accepted: true,
              ceremonyId: details.ceremonyId,
              transcriptHash: Uint8List(32),
            ),
            key: identityKeys[1],
          ),
        );
        await expectLater(
          server.sendDkgAcks(
            sid: session.id,
            acks: {signedAck, invalidLaterAck},
          ),
          throwsA(isA<InvalidRequest>()),
        );
        expect(
          (await server.getDkg(
            sid: session.id,
            name: details.name,
            ceremonyId: details.ceremonyId,
          ))!.completedParticipants,
          isEmpty,
          reason: 'a rejected batch must not mutate the live ceremony',
        );
        await restart();
        session = await login(i);
        expect(
          (await server.getDkg(
            sid: session.id,
            name: details.name,
            ceremonyId: details.ceremonyId,
          ))!.completedParticipants,
          isEmpty,
          reason: 'restart must agree with the pre-request durable state',
        );
      }
      await server.sendDkgAcks(sid: session.id, acks: {signedAck});
      await disconnect(session);
    }

    await restart();
    session = await login(0);
    final completed = (await server.getDkg(
      sid: session.id,
      name: details.name,
      ceremonyId: details.ceremonyId,
    ))!;
    expect(completed.stage, DkgCeremonyStage.completed);
    expect(completed.completedParticipants, ids.toSet());
    expect(completed.groupPublicKey, participantKeys[0].groupKey);

    // A lost completion response can be retried after restart, but a validly
    // signed acknowledgement for a different group key cannot alter the
    // terminal result.
    await server.sendDkgAcks(sid: session.id, acks: {completionAcks.first});
    final conflictingKeyAck = DkgAck(
      groupKey: cl.ECCompressedPublicKey.fromPubkey(
        cl.ECPrivateKey(Uint8List(32)..last = 99).pubkey,
      ),
      accepted: true,
      ceremonyId: details.ceremonyId,
      transcriptHash: transcriptHash,
    );
    await expectLater(
      server.sendDkgAcks(
        sid: session.id,
        acks: {
          SignedDkgAck(
            signer: ids[0],
            signed: Signed.sign(obj: conflictingKeyAck, key: identityKeys[0]),
          ),
        },
      ),
      throwsA(isA<InvalidRequest>()),
    );
    await disconnect(session);
    var disconnected = false;
    final blocked = await Client.login(
      config: ClientConfig(id: ids[0], group: group),
      api: server,
      store: InMemoryClientStorage(),
      getPrivateKey: (_) async => identityKeys[0],
      onDisconnect: () {
        disconnected = true;
      },
    );
    final errors = <Object>[];
    final subscription = blocked.events.listen((_) {}, onError: errors.add);
    addTearDown(subscription.cancel);
    addTearDown(blocked.logout);
    expect(blocked.acceptedDkgs.single.canResume, isFalse);
    server.debugState.dkgAckCache.remove(participantKeys[0].groupKey);
    session = await login(1);
    await server.requestDkgAcks(
      sid: session.id,
      requests: {
        DkgAckRequest(
          ids: {ids[0]},
          groupPublicKey: participantKeys[0].groupKey,
          ceremonyId: details.ceremonyId,
          transcriptHash: transcriptHash,
        ),
      },
    );
    await pumpEventQueue();
    expect(
      disconnected,
      isFalse,
      reason: 'A missing-key possession NACK must not disconnect the blocked signer',
    );
    expect(errors, isEmpty);
    expect(
      (await server.getDkg(
        sid: session.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
      ))!.completedParticipants,
      ids.toSet(),
    );
  });

  test(
    'snapshot exposes no ciphertext addressed to another participant',
    () async {
      final ids = [Identifier.fromUint16(1), Identifier.fromUint16(2)];
      final keys = [
        cl.ECPrivateKey(Uint8List(32)..last = 11),
        cl.ECPrivateKey(Uint8List(32)..last = 12),
      ];
      final group = GroupConfig(
        id: 'mailbox-privacy',
        participants: {
          for (var i = 0; i < 2; i++)
            ids[i]: cl.ECCompressedPublicKey.fromPubkey(keys[i].pubkey),
        },
      );
      final server = ServerApiHandler(
        config: ServerConfig(group: group),
        persistence: InMemoryServerPersistence(),
      );
      await server.ready;

      Future<LoginCompleteResponse> login(int i) async {
        final challenge = await server.login(
          groupFingerprint: group.fingerprint,
          participantId: ids[i],
        );
        return server.respondToChallenge(
          Signed.sign(obj: challenge.challenge, key: keys[i]),
        );
      }

      final details = NewDkgDetails(
        name: 'private-mailbox',
        description: '',
        threshold: 2,
        expiry: Expiry(const Duration(hours: 1)),
        groupFingerprint: group.fingerprint,
      );
      final p1 = [
        DkgPart1(identifier: ids[0], threshold: 2, n: 2),
        DkgPart1(identifier: ids[1], threshold: 2, n: 2),
      ];
      final login0 = await login(0);
      await server.requestNewDkg(
        sid: login0.id,
        signedDetails: Signed.sign(obj: details, key: keys[0]),
        commitment: p1[0].public,
      );
      final login1 = await login(1);
      await server.submitDkgCommitment(
        sid: login1.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
        commitment: p1[1].public,
      );
      final commitments = DkgCommitmentSet([
        (ids[0], p1[0].public),
        (ids[1], p1[1].public),
      ]);
      final p2 = DkgPart2(
        identifier: ids[0],
        round1Secret: p1[0].secret,
        commitments: commitments,
      );
      final encryptedForOne = DkgEncryptedSecret.encrypt(
        secretShare: p2.sharesToGive[ids[1]]!,
        protocolVersion: details.protocolVersion,
        ceremonyId: details.ceremonyId,
        transcriptHash: details.hashWithCommitments(commitments),
        sender: ids[0],
        recipient: ids[1],
        recipientKey: keys[1].pubkey,
        senderKey: keys[0],
      );
      await server.submitDkgRound2(
        sid: login0.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
        commitmentSetSignature: cl.SchnorrSignature.sign(
          keys[0],
          details.hashWithCommitments(commitments),
        ),
        secrets: {ids[1]: encryptedForOne},
      );

      final senderView = (await server.getDkg(
        sid: login0.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
      ))!;
      final recipientView = (await server.getDkg(
        sid: login1.id,
        name: details.name,
        ceremonyId: details.ceremonyId,
      ))!;
      expect(senderView.shares, isEmpty);
      expect(recipientView.shares, hasLength(1));
      expect(
        recipientView.shares.single.secret.ciphertext.toBytes(),
        encryptedForOne.ciphertext.toBytes(),
      );
    },
  );
}

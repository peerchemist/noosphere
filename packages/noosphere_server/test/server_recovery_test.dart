import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/server/state/dkg.dart';
import 'package:noosphere_server/src/server/state/signatures_coordination.dart';
import 'package:noosphere_server/src/server/state/state.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'data.dart';
import 'sig_data.dart';

void main() {
  setUpAll(() async {
    await cl.loadCoinlib();
    await loadFrosty();
  });

  test(
    'restart resumes DKG, blocks signing, and redelivers durable output',
    () async {
      final persistence = InMemoryServerPersistence();
      final state = ServerState();

      final dkgDetails = signObject(getDkgDetails(name: 'restart-dkg'));
      state.nameToDkg[dkgDetails.obj.name] = DkgState(
        details: dkgDetails,
        creator: ids.first,
        commitments: [
          (
            ids.first,
            DkgPart1(identifier: ids.first, threshold: 2, n: 10).public,
          ),
        ],
      );

      final signingDetails = signObject(getSignaturesDetails());
      state.sigRequests[signingDetails.obj.id] = SignaturesCoordinationState(
        details: signingDetails,
        creator: ids.first,
        keys: {getAggregateKeyInfo()},
      );

      final completedDetails = signObject(
        SignaturesRequestDetails.allowNegativeExpiry(
          requiredSigs: [getSingleSigDetails(tweak: 1)],
          expiry: Expiry(const Duration(seconds: -1)),
        ),
      );
      state.completedSigs[completedDetails.obj.id] = CompletedSignatures(
        details: completedDetails,
        signatures: [dummySig],
        expiry: Expiry(const Duration(days: 1)),
        creator: ids.first,
      );

      final groupKey = getAggregateKeyInfo().groupKey;
      final encryptedShare = EncryptedKeyShare.encrypt(
        keyShare: getPrivkey(2),
        recipientKey: getPrivkey(1).pubkey,
        senderKey: getPrivkey(0),
      );
      state
          .secretSharesForKey(groupKey)
          .maybeAddShare(ids.first, ids[1], encryptedShare);

      final first = ServerApiHandler(
        config: serverConfig,
        persistence: persistence,
        state: state,
      );
      await first.ready;

      final restored = ServerApiHandler(
        config: serverConfig,
        persistence: persistence,
      );
      await restored.ready;

      final exposed = restored.state.toBytes();
      final firstByte = exposed.first;
      exposed[0] ^= 0xff;
      expect(restored.state.toBytes().first, firstByte);

      expect(restored.debugState.nameToDkg.containsKey('restart-dkg'), isTrue);
      expect(restored.debugState.sigRequests.values, isEmpty);
      expect(
        restored.debugState.persistent.blockedSignatures,
        contains(signingDetails.obj.id),
      );

      final challenge = await restored.login(
        groupFingerprint: groupConfig.fingerprint,
        participantId: ids[1],
      );
      final login = await restored.respondToChallenge(
        Signed.sign(obj: challenge.challenge, key: getPrivkey(1)),
      );
      expect(
        login.completedSigs.map((result) => result.details.obj.id),
        contains(completedDetails.obj.id),
      );
      expect(login.secretShares, hasLength(1));
      expect(login.secretShares.single.groupKey, groupKey);

      expect(
        login.newDkgs.map((event) => event.details.obj.name),
        contains('restart-dkg'),
      );
    },
  );

  test('malformed coordinator snapshots fail decoding', () {
    expect(
      () => ServerStateSnapshot.fromBytes(
        Uint8List.fromList(utf8.encode('not a coordinator snapshot')),
      ),
      throwsFormatException,
    );
    for (final legacyHeader in [
      {'version': 1},
      {'version': 2, 'format': ServerStateSnapshot.currentFormat},
    ]) {
      expect(
        () => ServerStateSnapshot.fromBytes(
          Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                ...legacyHeader,
                'dkg': <Object?>[],
                'signing': <Object?>[],
                'completed': <Object?>[],
                'shares': <Object?>[],
                'cancelled': <Object?>[],
                'terminalSigning': <Object?>[],
                'terminalDkg': <Object?>[],
              }),
            ),
          ),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => ServerStateSnapshot.fromBytes(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'version': ServerStateSnapshot.currentVersion,
              'format': ServerStateSnapshot.currentFormat,
              'dkg': [
                {'status': 'gibberish'},
              ],
              'signing': <Object?>[],
              'completed': <Object?>[],
              'shares': <Object?>[],
              'cancelled': <Object?>[],
              'terminalSigning': <Object?>[],
              'terminalDkg': <Object?>[],
            }),
          ),
        ),
      ),
      throwsFormatException,
    );
  });

  test('restored DKG snapshots revalidate cryptographic invariants', () async {
    String encode(Uint8List value) => base64Encode(value);
    Uint8List decode(Object? value) => base64Decode(value! as String);

    final details = signObject(getDkgDetails(name: 'validated-restart'));
    final parts = List.generate(10, getDkgPart1);
    final commitments = DkgCommitmentSet([
      for (var i = 0; i < ids.length; i++) (ids[i], parts[i].public),
    ]);
    final transcriptHash = details.obj.hashWithCommitments(commitments);
    final part2 = DkgPart2(
      identifier: ids.first,
      round1Secret: parts.first.secret,
      commitments: commitments,
    );
    final secrets = {
      for (var i = 1; i < ids.length; i++)
        ids[i]: DkgEncryptedSecret.encrypt(
          secretShare: part2.sharesToGive[ids[i]]!,
          protocolVersion: details.obj.protocolVersion,
          ceremonyId: details.obj.ceremonyId,
          transcriptHash: transcriptHash,
          sender: ids.first,
          recipient: ids[i],
          recipientKey: getPrivkey(i).pubkey,
          senderKey: getPrivkey(0),
        ),
    };
    final state = ServerState();
    final dkgState = DkgState(
      details: details,
      creator: ids.first,
      commitments: commitments.list,
    );
    dkgState.round = DkgRound2State(
      expectedHash: transcriptHash,
      commitments: commitments.list,
      participantCount: ids.length,
    );
    dkgState.round2.contributions[ids.first] = DkgRound2Contribution(
      commitmentSetSignature: cl.SchnorrSignature.sign(
        getPrivkey(0),
        transcriptHash,
      ),
      secrets: secrets,
    );
    state.nameToDkg[details.obj.name] = dkgState;
    final snapshot = state.snapshot();

    final restored = ServerState();
    expect(restored.restore(snapshot, config: serverConfig), isFalse);
    expect(restored.nameToDkg[details.obj.name]!.round2.contributions.keys, [
      ids.first,
    ]);

    void expectRejected(void Function(Map<String, dynamic>) tamper) {
      final root = jsonDecode(utf8.decode(snapshot.toBytes()));
      final copy = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
      tamper(copy);
      expect(
        () => ServerState().restore(
          ServerStateSnapshot.fromBytes(
            Uint8List.fromList(utf8.encode(jsonEncode(copy))),
          ),
          config: serverConfig,
        ),
        throwsFormatException,
      );
    }

    Map<String, dynamic> dkg(Map<String, dynamic> root) =>
        ((root['dkg']! as List).single as Map).cast<String, dynamic>();

    expectRejected((root) {
      final record = dkg(root);
      final signed = decode(record['details']);
      signed.last ^= 1;
      record['details'] = encode(signed);
    });
    expectRejected((root) {
      final records = dkg(root)['commitments']! as List;
      (records[1] as Map)['participant'] =
          (records.first as Map)['participant'];
    });
    expectRejected((root) {
      final record = dkg(root);
      final hash = decode(record['expectedHash']);
      hash.last ^= 1;
      record['expectedHash'] = encode(hash);
    });
    expectRejected((root) {
      final contribution = (dkg(root)['contributions']! as List).single as Map;
      final secret = (contribution['secrets']! as List).first as Map;
      final envelope = decode(secret['ciphertext']);
      envelope.last ^= 1;
      secret['ciphertext'] = encode(envelope);
    });
    expectRejected((root) {
      final groupKey = cl.ECCompressedPublicKey.fromPubkey(
        getPrivkey(0).pubkey,
      );
      final ack = SignedDkgAck(
        signer: ids.first,
        signed: Signed.sign(
          obj: DkgAck(
            groupKey: groupKey,
            accepted: true,
            ceremonyId: details.obj.ceremonyId,
            transcriptHash: transcriptHash,
          ),
          key: getPrivkey(0),
        ),
      );
      (dkg(root)['completionAcks']! as List).add(encode(ack.toBytes()));
    });
  });
}

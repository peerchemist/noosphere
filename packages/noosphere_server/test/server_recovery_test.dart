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
    'restart aborts DKG, blocks signing, and redelivers durable output',
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

      expect(restored.debugState.nameToDkg.values, isEmpty);
      expect(
        restored.debugState.persistent.interruptedDkgs,
        contains('restart-dkg'),
      );
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

      final creatorChallenge = await restored.login(
        groupFingerprint: groupConfig.fingerprint,
        participantId: ids.first,
      );
      final creator = await restored.respondToChallenge(
        Signed.sign(obj: creatorChallenge.challenge, key: getPrivkey(0)),
      );
      await restored.requestNewDkg(
        sid: creator.id,
        signedDetails: dkgDetails,
        commitment: DkgPart1(
          identifier: ids.first,
          threshold: 2,
          n: ids.length,
        ).public,
      );
      expect(
        restored.debugState.persistent.interruptedDkgs,
        isNot(contains('restart-dkg')),
      );
      expect(restored.debugState.nameToDkg['restart-dkg'], isNotNull);
    },
  );
}

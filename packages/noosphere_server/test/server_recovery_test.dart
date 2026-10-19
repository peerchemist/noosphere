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
    expect(
      () => ServerStateSnapshot.fromBytes(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'version': 3,
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
}

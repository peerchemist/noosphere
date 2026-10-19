import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_client/testing.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/server/state/dkg.dart';
import 'package:noosphere_server/src/server/state/state.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'context.dart';
import 'data.dart';
import 'sig_data.dart';
import 'test_keys.dart';

Uint8List _encode(void Function(cl.Writer) write) {
  final measure = cl.MeasureWriter();
  write(measure);
  final bytes = Uint8List(measure.size);
  write(cl.BytesWriter(bytes));
  return bytes;
}

Uint8List _legacyKey(FrostKeyWithDetails key, {bool extended = true}) =>
    _encode((writer) {
      key.keyInfo.write(writer);
      writer.writeString(key.name);
      writer.writeString(key.description);
      writer.writeUInt16(1);
      writer.writeIdentifier(ids.first);
      writer.writeBool(true);
      // Even a contextual signature cannot be reconstructed from this old
      // compact record: its context was never included in the stored bytes.
      writer.writeSignature(getDkgAck(0, true).signed.signature);
      if (!extended) return;
      writer.writeMap(
        key.secretShareTimes,
        (id) => writer.writeIdentifier(id),
        (time) => writer.writeTime(time),
      );
      writer.writeIdentifierVector(key.claimedToHave);
      writer.writeBool(key.keyConstruction is KeyConstructionProgress);
      key.keyConstruction.write(writer);
    });

FrostKeyWithDetails _key(int i) => FrostKeyWithDetails(
  keyInfo: ParticipantKeyInfo.fromHex(keyInfoHex[i]),
  name: 'legacy-key',
  description: 'Keep the original key share',
  ceremonyId: Uint8List(32),
  transcriptHash: Uint8List(32),
);

void main() {
  setUpAll(() async {
    await cl.loadCoinlib();
    await loadFrosty();
  });

  for (final extended in [false, true]) {
    test(
      'legacy key migration preserves private and recovery state ($extended)',
      () {
        final time = DateTime.utc(2026);
        final source = _key(0)
            .addOrReplaceSecretShareTimes({ids[1]}, time)
            .addClaimedToHave(ids[2])
            .addSecretShare(ids[1], _key(1).keyInfo.private.share)!;
        final restored = FrostKeyWithDetails.fromBytes(
          _legacyKey(source, extended: extended),
        );
        expect(restored.keyInfo.toBytes(), source.keyInfo.toBytes());
        expect(restored.name, source.name);
        expect(restored.description, source.description);
        expect(restored.acks, isEmpty);
        expect(restored.hasLegacyDkgContext, isTrue);
        if (extended) {
          expect(restored.secretShareTimes.keys, source.secretShareTimes.keys);
          expect(
            restored.secretShareTimes[ids[1]]!.isAtSameMomentAs(time),
            isTrue,
          );
          expect(restored.claimedToHave, source.claimedToHave);
          expect(
            restored.keyConstruction.toBytes(),
            source.keyConstruction.toBytes(),
          );
        } else {
          expect(restored.secretShareTimes, isEmpty);
          expect(restored.claimedToHave, isEmpty);
          expect(restored.keyConstruction, isA<KeyConstructionProgress>());
        }
        final reloaded = FrostKeyWithDetails.fromBytes(restored.toBytes());
        expect(reloaded.toBytes(), restored.toBytes());
        expect(reloaded.hasLegacyDkgContext, isTrue);
      },
    );
  }

  test(
    'migrated participants persist fresh possession ACKs and exchange them',
    () async {
      final ctx = TestContext();
      final clients = <TestClient>[];
      addTearDown(() async {
        for (final client in clients) {
          await client.logout();
        }
      });
      for (var i = 0; i < 2; i++) {
        final store = InMemoryClientStorage();
        await store.addOrReplaceFrostKey(
          FrostKeyWithDetails.fromBytes(_legacyKey(_key(i))),
        );
        clients.add(await TestClient.login(ctx.api, i, storage: store));
      }
      await pumpEventQueue();
      for (final client in clients) {
        await client.evCollector.expectNoError();
        final key = FrostKeyWithDetails.fromBytes(
          client.store.keys.values.single.toBytes(),
        );
        expect(key.acks.map((ack) => ack.signer).toSet(), {ids[0], ids[1]});
        for (final ack in key.acks) {
          expect(
            ack.signed.verify(groupConfig.participants[ack.signer]!),
            isTrue,
          );
          expect(ack.signed.obj.ceremonyId, key.ceremonyId);
          expect(ack.signed.obj.transcriptHash, key.transcriptHash);
        }
      }
    },
  );

  for (final version in [1, 2]) {
    test(
      'snapshot v$version migrates DKG to interrupted and preserves other state',
      () async {
        final expiry = Expiry(const Duration(hours: 1));
        final details = _encode((writer) {
          writer.writeString('legacy-attempt');
          writer.writeString('old proposal');
          writer.writeUInt16(2);
          expiry.write(writer);
        });
        final ceremonyId = cl.getTaggedHasher('NewDkgDetails')(details);
        final signature = cl.SchnorrSignature.sign(getPrivkey(0), ceremonyId);
        final signed = Uint8List.fromList([...details, ...signature.data]);
        final commitment = getDkgPart1(0).public;
        final event = _encode((writer) {
          writer.writeSlice(signed);
          writer.writeIdentifier(ids.first);
          writer.writeUInt16(1);
          writer.writeIdentifier(ids.first);
          writer.writeVarSlice(commitment.toBytes());
        });
        final state = ServerState();
        final cancellation = CancelledSignaturesRequest(
          getSignaturesDetails().id,
          expiry,
        );
        state.persistent.cancelledSignatures[cancellation.requestId] =
            cancellation;
        final encrypted = EncryptedKeyShare.encrypt(
          keyShare: getPrivkey(2),
          recipientKey: getPrivkey(1).pubkey,
          senderKey: getPrivkey(0),
        );
        state
            .secretSharesForKey(groupPublicKey)
            .maybeAddShare(ids.first, ids[1], encrypted);
        final root = jsonDecode(
          utf8.decode(state.snapshot().toBytes()),
        ) as Map<String, dynamic>;
        root['version'] = version;
        root.remove('terminalDkg');
        root['dkg'] = [
          version == 1
              ? {'status': 'active', 'event': base64Encode(event)}
              : {
                  'status': 'resumable',
                  'details': base64Encode(signed),
                  'creator': base64Encode(ids.first.toBytes()),
                  'round': 1,
                  'commitments': [
                    {
                      'participant': base64Encode(ids.first.toBytes()),
                      'commitment': base64Encode(commitment.toBytes()),
                    },
                  ],
                  'completionAcks': <Object?>[],
                },
        ];
        final persistence = InMemoryServerPersistence();
        await persistence.write(
          groupConfig.id,
          ServerStateSnapshot.fromBytes(
            Uint8List.fromList(utf8.encode(jsonEncode(root))),
          ),
        );
        final server = ServerApiHandler(
          config: serverConfig,
          persistence: persistence,
        );
        await server.ready;
        expect(server.debugState.nameToDkg.values, isEmpty);
        final terminal =
            server.debugState.persistent.terminalDkgs.values.single;
        expect(terminal.ceremonyId, ceremonyId);
        expect(terminal.outcome, DkgTerminalOutcome.interrupted);
        expect(
          server.debugState.persistent.cancelledSignatures[cancellation
              .requestId],
          isNotNull,
        );
        final saved = (await persistence.load(groupConfig.id))!;
        expect(jsonDecode(utf8.decode(saved.toBytes()))['version'], 3);
        final again = ServerApiHandler(
          config: serverConfig,
          persistence: persistence,
        );
        await again.ready;
        expect(again.state.toBytes(), saved.toBytes());
        final challenge = await again.login(
          groupFingerprint: groupConfig.fingerprint,
          participantId: ids[1],
        );
        final login = await again.respondToChallenge(
          signObject(challenge.challenge, 1),
        );
        expect(login.newDkgs, isEmpty);
        expect(
          login.secretShares.single.keyShare.ciphertext.toBytes(),
          encrypted.ciphertext.toBytes(),
        );
      },
    );
  }
}

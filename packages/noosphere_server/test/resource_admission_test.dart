import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/server/state/key_sharing.dart';
import 'package:noosphere_server/src/server/state/state.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'data.dart';
import 'sig_data.dart';
import 'test_keys.dart';

void main() {
  setUpAll(loadFrosty);
  late ServerApiHandler api;
  late InMemoryServerPersistence persistence;
  late SessionID sid;
  var sequence = 0;

  Future<SessionID> login(int i) async {
    final challenge = await api.login(
      groupFingerprint: api.config.group.fingerprint,
      participantId: ids[i],
    );
    final session = await api.respondToChallenge(
      signObject(challenge.challenge, i),
    );
    unawaited(session.events.drain<void>());
    return session.id;
  }

  setUp(() async {
    persistence = InMemoryServerPersistence();
    api = ServerApiHandler(config: serverConfig, persistence: persistence);
    sid = await login(0);
  });
  tearDown(() => api.shutdown());

  SignaturesRequestDetails details({int count = 1, int pathLength = 0}) =>
      SignaturesRequestDetails(
        requiredSigs: [
          for (var i = 0; i < count; i++)
            SingleSignatureDetails(
              signDetails: getSignDetails(i),
              groupKey: groupPublicKey,
              hdDerivation: List.filled(pathLength, 0),
            ),
        ],
        expiry: futureExpiry,
        message: 'request ${sequence++}',
      );

  Future<void> request(
    SignaturesRequestDetails value, {
    SessionID? session,
    int signer = 0,
  }) => api.requestSignatures(
    sid: session ?? sid,
    keys: {getAggregateKeyInfo()},
    signedDetails: signObject(value, signer),
    commitments: [
      for (final _ in value.requiredSigs) getSignPart1().commitment,
    ],
  );

  Future<void> rejectedWithoutWrite(Future<void> Function() action) async {
    final before = (await persistence.load(groupConfig.id))!.toBytes();
    await expectLater(action(), throwsA(isA<InvalidRequest>()));
    expect((await persistence.load(groupConfig.id))!.toBytes(), before);
    expect((await api.extendSession(sid)).isExpired, isFalse);
  }

  EncryptedKeyShare share({int plaintextLength = 32}) => EncryptedKeyShare(
    ECCiphertext.encrypt(
      plaintext: Uint8List(plaintextLength)..last = 1,
      senderKey: getPrivkey(0),
      recipientKey: getPrivkey(1).pubkey,
    ),
  );

  Future<void> attest(cl.ECCompressedPublicKey key) => api.sendDkgAcks(
    sid: sid,
    acks: {
      for (var i = 0; i < ids.length; i++) getDkgAck(i, true, groupKey: key),
    },
  );

  Future<void> send(
    cl.ECCompressedPublicKey key, {
    EncryptedKeyShare? value,
  }) async {
    await api.shareSecretShare(
      sid: sid,
      groupKey: key,
      encryptedSecrets: {ids[1]: value ?? share()},
    );
  }

  test('signing rate is per participant and rejects before mutation', () async {
    for (var i = 0; i < ServerConfig.maxSigningRequestsPerMinute; i++) {
      await request(details());
    }
    final denied = details();
    await rejectedWithoutWrite(() => request(denied));
    expect(api.debugState.sigRequests.containsKey(denied.id), isFalse);
    final other = await login(1);
    await request(details(), session: other, signer: 1);
    api.debugState.runtime.signingRequestTimes[ids.first] = [
      DateTime.now().subtract(const Duration(minutes: 2)),
    ];
    await request(denied);
  });

  test(
    'active signing limit preserves existing requests and cancellation',
    () async {
      final accepted = <SignaturesRequestDetails>[];
      for (var i = 0; i < ServerConfig.maxActiveSignaturesRequests; i++) {
        api.debugState.runtime.signingRequestTimes.clear();
        final value = details();
        await request(value);
        accepted.add(value);
      }
      final denied = details();
      await rejectedWithoutWrite(() => request(denied));
      expect(api.debugState.sigRequests.values.length, accepted.length);
      await api.cancelSignaturesRequest(sid: sid, reqId: accepted.first.id);
      await request(denied);
    },
  );

  test(
    'cancelled requests cannot bypass retained signing capacity after restart',
    () async {
      for (var i = 0; i < ServerConfig.maxRetainedSignaturesRequests; i++) {
        api.debugState.runtime.signingRequestTimes.clear();
        final value = details();
        await request(value);
        await api.cancelSignaturesRequest(sid: sid, reqId: value.id);
      }
      await api.shutdown();
      api = ServerApiHandler(config: serverConfig, persistence: persistence);
      sid = await login(0);
      await rejectedWithoutWrite(() => request(details()));
      expect(
        api.debugState.retainedSigningCount,
        ServerConfig.maxRetainedSignaturesRequests,
      );
    },
  );

  test('oversized signing count and bytes leave no request behind', () async {
    for (final value in [
      details(count: ServerConfig.maxSignaturesPerRequest + 1),
      details(count: ServerConfig.maxSignaturesPerRequest, pathLength: 255),
    ]) {
      await rejectedWithoutWrite(() => request(value));
      expect(api.debugState.sigRequests.containsKey(value.id), isFalse);
    }
    await request(details());
  });

  test('unknown recovery keys and unsolicited construction claims allocate nothing', () async {
    await rejectedWithoutWrite(() => send(groupPublicKey));
    await api.sendDkgAcks(sid: sid, acks: {getDkgAck(0, true)});
    await rejectedWithoutWrite(() => send(groupPublicKey));
    await rejectedWithoutWrite(
      () => api.ackKeyConstructed(
        sid: sid,
        constructedKey: signObject(KeyWasConstructed(groupPublicKey)),
      ),
    );
    expect(api.debugState.secretShares, isEmpty);
    await attest(groupPublicKey);
    await send(groupPublicKey);
  });

  test('negative and mismatched roster acknowledgements cannot admit a recovery key', () async {
    await api.sendDkgAcks(
      sid: sid,
      acks: {for (var i = 0; i < ids.length; i++) getDkgAck(i, i != 1)},
    );
    await rejectedWithoutWrite(() => send(groupPublicKey));
    await api.sendDkgAcks(
      sid: sid,
      acks: {getDkgAck(1, true, transcriptHash: Uint8List(32)..last = 1)},
    );
    await rejectedWithoutWrite(() => send(groupPublicKey));
    expect(api.debugState.secretShares, isEmpty);
  });

  test(
    'oversized recovery ciphertext is rejected before mailbox allocation',
    () async {
      await attest(groupPublicKey);
      await rejectedWithoutWrite(
        () => send(
          groupPublicKey,
          value: share(
            plaintextLength: ServerConfig.maxEncryptedRecoveryShareBytes,
          ),
        ),
      );
      expect(api.debugState.secretShares, isEmpty);
      await send(groupPublicKey);
    },
  );

  test(
    'recovery count cap survives restart and existing mailboxes still progress',
    () async {
      final keys = <cl.ECCompressedPublicKey>[];
      for (var i = 0; i < ServerConfig.maxRecoveryKeys; i++) {
        final key = cl.ECCompressedPublicKey.fromPubkey(getPrivkey(i).pubkey);
        keys.add(key);
        await attest(key);
        await send(key);
      }
      await api.shutdown();
      api = ServerApiHandler(config: serverConfig, persistence: persistence);
      sid = await login(0);
      final extra = cl.ECCompressedPublicKey.fromPubkey(getPrivkey(100).pubkey);
      await attest(extra);
      await rejectedWithoutWrite(() => send(extra));
      expect(api.debugState.secretShares.length, ServerConfig.maxRecoveryKeys);
      // Replays are no-ops; recipient completion releases its ciphertexts.
      await send(keys.first);
      final recipient = await login(1);
      await api.ackKeyConstructed(
        sid: recipient,
        constructedKey: signObject(KeyWasConstructed(keys.first), 1),
      );
      expect(
        api.debugState.secretShares[keys.first]!.receiverShares[ids[1]],
        isA<ParticipantDoneShareState>(),
      );
    },
  );

  test('recovery rate limit leaves pending ciphertexts available', () async {
    await attest(groupPublicKey);
    await send(groupPublicKey);
    api.debugState.runtime.recoveryRequestTimes[ids[1]] = List.filled(
      ServerConfig.maxRecoveryRequestsPerMinute,
      DateTime.now(),
      growable: true,
    );
    final recipient = await login(1);
    await rejectedWithoutWrite(
      () => api.ackKeyConstructed(
        sid: recipient,
        constructedKey: signObject(KeyWasConstructed(groupPublicKey), 1),
      ),
    );
    expect(
      api.debugState.secretShares[groupPublicKey]!.getSharesForReceiver(ids[1]),
      hasLength(1),
    );
  });
  test(
    'aggregate recovery byte budget rejects only the new contribution',
    () async {
      await api.shutdown();
      final roster = List.generate(64, (i) => Identifier.fromUint16(i + 1));
      final config = ServerConfig(
        group: GroupConfig(
          id: groupConfig.id,
          participants: {
            for (var i = 0; i < roster.length; i++)
              roster[i]: cl.ECCompressedPublicKey.fromPubkey(
                getPrivkey(i).pubkey,
              ),
          },
        ),
      );
      final state = ServerState();
      final ciphertext = share(plaintextLength: 192);
      expect(
        ciphertext.ciphertext.toBytes().length,
        lessThanOrEqualTo(ServerConfig.maxEncryptedRecoveryShareBytes),
      );
      final targetKey = cl.ECCompressedPublicKey.fromPubkey(
        getPrivkey(64).pubkey,
      );
      var payloadBytes = 0;
      var full = false;
      for (var k = 0; k < ServerConfig.maxRecoveryKeys && !full; k++) {
        final key = cl.ECCompressedPublicKey.fromPubkey(
          getPrivkey(64 + k).pubkey,
        );
        final entryBytes =
            32 +
            SecretShareEvent(
              sender: roster[0],
              keyShare: ciphertext,
              groupKey: key,
            ).toBytes().length;
        if (payloadBytes + 33 + entryBytes >
            ServerConfig.maxRecoveryStateBytes) {
          break;
        }
        final mailbox = state.secretSharesForKey(key);
        payloadBytes += 33;
        for (final receiver in roster) {
          for (final sender in roster) {
            if (sender == receiver ||
                (key == targetKey && sender == ids[0] && receiver == ids[1])) {
              continue;
            }
            if (payloadBytes + entryBytes >
                ServerConfig.maxRecoveryStateBytes) {
              full = true;
              break;
            }
            mailbox.maybeAddShare(sender, receiver, ciphertext);
            payloadBytes += entryBytes;
          }
          if (full) break;
        }
      }
      expect(state.recoveryPayloadBytes, payloadBytes);
      persistence = InMemoryServerPersistence();
      api = ServerApiHandler(
        config: config,
        persistence: persistence,
        state: state,
      );
      sid = await login(0);
      await rejectedWithoutWrite(() => send(targetKey, value: ciphertext));
      expect(state.recoveryPayloadBytes, payloadBytes);
      final recipient = await login(2);
      await api.ackKeyConstructed(
        sid: recipient,
        constructedKey: signObject(KeyWasConstructed(targetKey), 2),
      );
      expect(state.recoveryPayloadBytes, lessThan(payloadBytes));
      await send(targetKey, value: ciphertext);
    },
  );

  test('restoration rejects oversized retained collections', () async {
    final value = details();
    await request(value);
    await api.cancelSignaturesRequest(sid: sid, reqId: value.id);
    final root =
        jsonDecode(utf8.decode(api.state.toBytes())) as Map<String, dynamic>;
    final oversized = {
      ...root,
      'cancelled': List.filled(
        ServerConfig.maxRetainedSignaturesRequests + 1,
        (root['cancelled'] as List).single,
      ),
    };
    expect(
      () => ServerState().restore(
        ServerStateSnapshot.fromBytes(
          Uint8List.fromList(utf8.encode(jsonEncode(oversized))),
        ),
        config: serverConfig,
      ),
      throwsFormatException,
    );
    final oversizedRecovery = {
      ...root,
      'shares': List.filled(
        ServerConfig.maxRecoveryKeys + 1,
        <String, Object>{},
      ),
    };
    expect(
      () => ServerState().restore(
        ServerStateSnapshot.fromBytes(
          Uint8List.fromList(utf8.encode(jsonEncode(oversizedRecovery))),
        ),
        config: serverConfig,
      ),
      throwsFormatException,
    );
  });
}

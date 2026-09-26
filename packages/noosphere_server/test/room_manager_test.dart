import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    await cl.loadCoinlib();
    await loadFrosty();
  });

  final endpointId = Uint8List.fromList(List.generate(32, (i) => i));

  Future<(RoomManager, InMemoryRoomPersistence)> manager() async {
    final persistence = InMemoryRoomPersistence();
    return (
      await RoomManager.open(
        coordinatorEndpointId: endpointId,
        persistence: persistence,
        relayUrls: const ['https://relay.example'],
      ),
      persistence,
    );
  }

  Future<RoomInvite> issue(
    RoomManager rooms,
    String room,
    cl.ECPrivateKey key,
  ) => rooms.issueRoomInvite(
    roomId: room,
    expectedParticipantPublicKey: cl.ECCompressedPublicKey.fromPubkey(
      key.pubkey,
    ),
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
  );

  test('valid proof enrolls once and does not expose the token', () async {
    final (rooms, _) = await manager();
    await rooms.createRoom(
      roomId: 'room',
      expectedParticipants: 2,
      threshold: 2,
    );
    final key = cl.ECPrivateKey.generate();
    final invite = await issue(rooms, 'room', key);
    final snapshot = await RoomEnrollmentClient(rooms)
        .joinRoom(invite, (_) async => key);

    expect(snapshot.participants, hasLength(1));
    expect(snapshot.invites.single.status, RoomInviteStatus.used);
    expect(snapshot.invites.single.tokenHash, invite.tokenHash);
    expect(_containsSequence(snapshot.toBytes(), invite.token), isFalse);
  });

  test('stolen invite fails with a different private key', () async {
    final (rooms, _) = await manager();
    await rooms.createRoom(
      roomId: 'room',
      expectedParticipants: 2,
      threshold: 2,
    );
    final invite = await issue(rooms, 'room', cl.ECPrivateKey.generate());

    await expectLater(
      RoomEnrollmentClient(rooms)
          .joinRoom(invite, (_) async => cl.ECPrivateKey.generate()),
      throwsArgumentError,
    );
    expect((await rooms.getRoom('room')).participants, isEmpty);
  });

  test('changed transcript fields and wrong signature are rejected', () async {
    final (rooms, _) = await manager();
    await rooms.createRoom(
      roomId: 'room',
      expectedParticipants: 2,
      threshold: 1,
    );
    final key = cl.ECPrivateKey.generate();
    final invite = await issue(rooms, 'room', key);
    final challenge = await rooms.beginEnrollment(
      invite: invite,
      participantPublicKey: invite.expectedParticipantPublicKey,
    );
    final changed = EnrollmentTranscript(
      roomId: 'changed-room',
      inviteId: challenge.transcript.inviteId,
      inviteTokenHash: challenge.transcript.inviteTokenHash,
      expectedParticipantPublicKey:
          challenge.transcript.expectedParticipantPublicKey,
      coordinatorEndpointId: challenge.transcript.coordinatorEndpointId,
      serverNonce: challenge.transcript.serverNonce,
    );
    await expectLater(
      rooms.redeemRoomInvite(Signed.sign(obj: changed, key: key)),
      throwsA(
        isA<RoomException>().having(
          (error) => error.code,
          'code',
          RoomFailureCode.malformedProof,
        ),
      ),
    );

    final retry = await rooms.beginEnrollment(
      invite: invite,
      participantPublicKey: invite.expectedParticipantPublicKey,
    );
    await expectLater(
      rooms.redeemRoomInvite(
        Signed.sign(obj: retry.transcript, key: cl.ECPrivateKey.generate()),
      ),
      throwsA(
        isA<RoomException>().having(
          (error) => error.code,
          'code',
          RoomFailureCode.invalidSignature,
        ),
      ),
    );
  });

  test('revocation, expiry, freeze and capacity are enforced', () async {
    final (rooms, _) = await manager();
    await rooms.createRoom(
      roomId: 'room',
      expectedParticipants: 2,
      threshold: 1,
    );
    final first = cl.ECPrivateKey.generate();
    final revoked = await issue(rooms, 'room', first);
    await rooms.revokeRoomInvite(roomId: 'room', inviteId: revoked.inviteId);
    await expectLater(
      rooms.beginEnrollment(
        invite: revoked,
        participantPublicKey: revoked.expectedParticipantPublicKey,
      ),
      throwsA(
        isA<RoomException>().having(
          (error) => error.code,
          'code',
          RoomFailureCode.revokedInvite,
        ),
      ),
    );

    final keys = [first, cl.ECPrivateKey.generate()];
    for (final key in keys) {
      final invite = await issue(rooms, 'room', key);
      await RoomEnrollmentClient(rooms).joinRoom(invite, (_) async => key);
    }
    final frozen = await rooms.freezeRoom('room');
    expect(frozen.lifecycle, RoomLifecycle.frozen);
    expect(frozen.groupConfig, isNotNull);
    await expectLater(
      issue(rooms, 'room', cl.ECPrivateKey.generate()),
      throwsA(
        isA<RoomException>().having(
          (error) => error.code,
          'code',
          RoomFailureCode.roomNotEnrolling,
        ),
      ),
    );
  });

  test('parallel redemption is atomic and replay-safe', () async {
    final (rooms, _) = await manager();
    await rooms.createRoom(
      roomId: 'room',
      expectedParticipants: 2,
      threshold: 1,
    );
    final key = cl.ECPrivateKey.generate();
    final invite = await issue(rooms, 'room', key);
    final challenge = await rooms.beginEnrollment(
      invite: invite,
      participantPublicKey: invite.expectedParticipantPublicKey,
    );
    final proof = challenge.sign(key);
    final results = await Future.wait([
      rooms
          .redeemRoomInvite(proof)
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      rooms
          .redeemRoomInvite(proof)
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);

    expect(results.whereType<RoomSnapshot>(), hasLength(1));
    expect(results.whereType<RoomException>(), hasLength(1));
    expect((await rooms.getRoom('room')).participants, hasLength(1));
  });

  test('frozen roster and fingerprint survive restart', () async {
    final (rooms, persistence) = await manager();
    await rooms.createRoom(
      roomId: 'room',
      expectedParticipants: 3,
      threshold: 2,
    );
    final keys = List.generate(3, (_) => cl.ECPrivateKey.generate());
    for (final key in keys.reversed) {
      final invite = await issue(rooms, 'room', key);
      await RoomEnrollmentClient(rooms).joinRoom(invite, (_) async => key);
    }
    final before = await rooms.freezeRoom('room');
    final restored = await RoomManager.open(
      coordinatorEndpointId: endpointId,
      persistence: persistence,
    );
    final after = await restored.getRoom('room');

    expect(after.lifecycle, RoomLifecycle.frozen);
    expect(after.groupConfig!.toBytes(), before.groupConfig!.toBytes());
    expect(after.groupFingerprint, before.groupFingerprint);
    expect(
      after.participants.map((participant) => participant.identifier),
      before.participants.map((participant) => participant.identifier),
    );
  });

  test('a used invitation stays consumed after restart', () async {
    final (rooms, persistence) = await manager();
    await rooms.createRoom(
      roomId: 'room',
      expectedParticipants: 2,
      threshold: 1,
    );
    final key = cl.ECPrivateKey.generate();
    final invite = await issue(rooms, 'room', key);
    await RoomEnrollmentClient(rooms).joinRoom(invite, (_) async => key);

    final restored = await RoomManager.open(
      coordinatorEndpointId: endpointId,
      persistence: persistence,
    );
    await expectLater(
      restored.beginEnrollment(
        invite: invite,
        participantPublicKey: invite.expectedParticipantPublicKey,
      ),
      throwsA(
        isA<RoomException>().having(
          (error) => error.code,
          'code',
          RoomFailureCode.usedInvite,
        ),
      ),
    );
  });

  test('unknown write outcome blocks every mutation until reload', () async {
    final persistence = _UncertainRoomPersistence();
    final rooms = await RoomManager.open(
      coordinatorEndpointId: endpointId,
      persistence: persistence,
    );
    await rooms.createRoom(
      roomId: 'room',
      expectedParticipants: 2,
      threshold: 1,
    );
    final key = cl.ECPrivateKey.generate();
    persistence.failAfterCommit = true;

    await expectLater(issue(rooms, 'room', key), throwsStateError);
    expect((await rooms.getRoom('room')).invites, isEmpty);
    await expectLater(
      rooms.createRoom(roomId: 'other', expectedParticipants: 2, threshold: 1),
      throwsStateError,
    );
    await expectLater(issue(rooms, 'room', key), throwsStateError);

    final restored = await RoomManager.open(
      coordinatorEndpointId: endpointId,
      persistence: persistence,
    );
    final durable = await restored.getRoom('room');
    expect(durable.invites, hasLength(1));
    await restored.revokeRoomInvite(
      roomId: 'room',
      inviteId: durable.invites.single.inviteId,
    );
  });
}

final class _UncertainRoomPersistence implements RoomPersistence {
  final records = <String, Uint8List>{};
  bool failAfterCommit = false;

  @override
  Future<Map<String, Uint8List>> loadAll() async => {
    for (final entry in records.entries)
      entry.key: Uint8List.fromList(entry.value),
  };

  @override
  Future<void> write(String roomId, Uint8List state) async {
    records[roomId] = Uint8List.fromList(state);
    if (failAfterCommit) {
      failAfterCommit = false;
      throw StateError('reply was lost');
    }
  }
}

bool _containsSequence(Uint8List bytes, Uint8List sequence) {
  for (var offset = 0; offset + sequence.length <= bytes.length; offset++) {
    var matches = true;
    for (var index = 0; index < sequence.length; index++) {
      if (bytes[offset + index] != sequence[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

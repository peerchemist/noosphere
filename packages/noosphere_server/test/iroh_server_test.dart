@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'data.dart';

void main() {
  setUpAll(() async {
    await loadFrosty();
    await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  });

  IrohConfig config() => IrohConfig(
    server: serverConfig,
    relay: IrohRelayConfig.disabled(),
    nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
  );

  test('host-supplied secret keeps the endpoint ID across restarts', () async {
    final secret = SecretKey.generate();
    final first = await IrohServer.start(
      config(),
      secretKey: secret,
      persistence: newServerPersistence(),
    );
    final firstId = first.id;
    await first.close();
    final second = await IrohServer.start(
      config(),
      secretKey: SecretKey.fromBytes(secret.toBytes()),
      persistence: newServerPersistence(),
    );
    addTearDown(second.close);

    expect(second.id, firstId);
    expect(second.id, secret.publicKey);
  });

  test('embedding alias uses the supplied identity', () async {
    final secret = SecretKey.generate();
    final server = await IrohServer.start(
      config(),
      secretKey: secret,
      persistence: newServerPersistence(),
    );
    addTearDown(server.close);
    expect(server.id, secret.publicKey);
  });

  test('close releases a blocked accept and is idempotent', () async {
    final server = await IrohServer.start(
      config(),
      secretKey: SecretKey.generate(),
      persistence: newServerPersistence(),
    );
    final accepted = server.accept();
    await Future.wait([server.close(), server.close()]);

    expect(await accepted, isNull);
    expect(server.isClosed, isTrue);
  });

  test('local routing requires the active identity and hosted group', () async {
    final server = await IrohServer.start(
      config(),
      secretKey: SecretKey.generate(),
      persistence: newServerPersistence(),
    );
    expect(
      server.canServeLocally(
        coordinatorId: server.id,
        groupFingerprint: groupConfig.fingerprint,
      ),
      isTrue,
    );
    expect(
      server.canServeLocally(
        coordinatorId: SecretKey.generate().publicKey,
        groupFingerprint: groupConfig.fingerprint,
      ),
      isFalse,
    );
    expect(
      server.canServeLocally(
        coordinatorId: server.id,
        groupFingerprint: Uint8List(32),
      ),
      isFalse,
    );

    final api = server.openLocalApi(groupConfig.fingerprint);
    await server.close();
    expect(api.isClosed, isTrue);
  });

  test(
    'room activation can be retried after handler initialization fails',
    () async {
      final secret = SecretKey.generate();
      final roomPersistence = InMemoryRoomPersistence();
      final room = RoomSnapshot(
        roomId: 'retry-room',
        lifecycle: RoomLifecycle.enrolling,
        expectedParticipants: 2,
        threshold: 2,
        coordinatorEndpointId: secret.publicKey.asBytes(),
        invites: const [],
        participants: [
          for (final publicKey in serverConfig.group.participants.values.take(
            2,
          ))
            RoomParticipantSnapshot(
              publicKey: publicKey,
              enrolledAt: DateTime.utc(2026),
              identifier: null,
            ),
        ],
        groupConfig: null,
      );
      await roomPersistence.write(room.roomId, room.toBytes());
      final rooms = await RoomManager.open(
        coordinatorEndpointId: secret.publicKey.asBytes(),
        persistence: roomPersistence,
      );
      final persistence = _TransientRoomLoadFailure(room.roomId);
      final server = await IrohServer.start(
        config(),
        secretKey: secret,
        persistence: persistence,
        rooms: rooms,
      );
      addTearDown(server.close);

      await expectLater(server.freezeRoom(room.roomId), throwsStateError);
      final frozen = await rooms.getRoom(room.roomId);
      expect(frozen.lifecycle, RoomLifecycle.frozen);
      expect(
        server.canServeLocally(
          coordinatorId: server.id,
          groupFingerprint: frozen.groupFingerprint!,
        ),
        isFalse,
      );

      persistence.failRoomLoad = false;
      final activated = await server.freezeRoom(room.roomId);
      expect(
        server.canServeLocally(
          coordinatorId: server.id,
          groupFingerprint: activated.groupFingerprint!,
        ),
        isTrue,
      );
      expect(await server.freezeRoom(room.roomId), isA<RoomSnapshot>());
    },
  );

  test(
    'scheduled expiry reports persistence failure once to the host',
    () async {
      final persistence = _FailingPersistence();
      final expiringConfig = ServerConfig(
        group: groupConfig,
        minDkgRequestTTL: const Duration(milliseconds: 1),
      );
      final handler = ServerApiHandler(
        config: expiringConfig,
        persistence: persistence,
      );
      final challenge = await handler.login(
        groupFingerprint: groupConfig.fingerprint,
        participantId: ids.first,
      );
      final session = await handler.respondToChallenge(
        signObject(challenge.challenge),
      );
      unawaited(session.events.drain<void>());
      await handler.requestNewDkg(
        sid: session.id,
        signedDetails: signObject(
          getDkgDetails(expiry: Expiry(const Duration(milliseconds: 100))),
        ),
        commitment: getDkgPart1(0).public,
      );

      final reported = Completer<void>();
      final errors = <(Object, StackTrace)>[];
      final server = await IrohServer.start(
        IrohConfig(
          server: expiringConfig,
          relay: IrohRelayConfig.disabled(),
          nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
        ),
        secretKey: SecretKey.generate(),
        persistence: persistence,
        handler: handler,
        onError: (error, stackTrace) {
          errors.add((error, stackTrace));
          if (!reported.isCompleted) reported.complete();
        },
      );
      addTearDown(server.close);
      persistence.fail = true;

      await reported.future.timeout(const Duration(seconds: 3));
      expect(errors.single.$1, isA<StateError>());
      expect(
        errors.single.$1.toString(),
        contains('simulated storage failure'),
      );
      expect(errors.single.$2.toString(), isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(errors, hasLength(1));
    },
  );
}

final class _FailingPersistence implements ServerPersistence {
  final delegate = InMemoryServerPersistence();
  bool fail = false;

  @override
  Future<ServerStateSnapshot?> load(String groupId) => delegate.load(groupId);

  @override
  Future<void> write(String groupId, ServerStateSnapshot state) {
    if (fail) throw StateError('simulated storage failure');
    return delegate.write(groupId, state);
  }
}

final class _TransientRoomLoadFailure(final String roomId)
    implements ServerPersistence {
  final delegate = InMemoryServerPersistence();
  bool failRoomLoad = true;

  @override
  Future<ServerStateSnapshot?> load(String groupId) {
    if (failRoomLoad && groupId == roomId) {
      throw StateError('simulated room state load failure');
    }
    return delegate.load(groupId);
  }

  @override
  Future<void> write(String groupId, ServerStateSnapshot state) =>
      delegate.write(groupId, state);
}

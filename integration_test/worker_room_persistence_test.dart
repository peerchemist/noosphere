import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'worker persists enrollment and rejects used invites after restart',
    (_) async {
      await NoosphereFlutter.initialize();
      final keys = [
        ECPrivateKey(Uint8List(32)..last = 31),
        ECPrivateKey(Uint8List(32)..last = 32),
      ];
      final identity = MemoryIdentityStore();
      final secret = await loadOrCreateServerIdentity(identity);
      final storage = InMemoryRoomPersistence();
      final rooms = await RoomManager.open(
        coordinatorEndpointId: secret.publicKey.asBytes(),
        persistence: storage,
      );
      await rooms.createRoom(
        roomId: 'room',
        expectedParticipants: 2,
        threshold: 2,
      );
      final invites = [
        for (final key in keys)
          await rooms.issueRoomInvite(
            roomId: 'room',
            expectedParticipantPublicKey: ECCompressedPublicKey.fromPubkey(
              key.pubkey,
            ),
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
      ];
      await rooms.close();
      final options = EmbeddedServerOptions(
        serverConfig: ServerConfig(
          group: GroupConfig(
            id: 'bootstrap',
            participants: {
              for (var i = 0; i < keys.length; i++)
                Identifier.fromUint16(i + 1): ECCompressedPublicKey.fromPubkey(
                  keys[i].pubkey,
                ),
            },
          ),
        ),
        identityStore: identity,
        roomPersistence: storage,
        relay: IrohRelayConfig.disabled(),
      );

      var worker = await NoosphereWorker.start();
      try {
        await worker.startSetup(setupId: 'rooms', server: options);
        var transport = await _transport(worker);
        final joined = await IrohRoomEnrollmentApi.joinRoom(
          transport,
          invites[0],
          (_) async => keys[0],
        );
        expect(joined.participants, hasLength(1));
        expect(
          RoomSnapshot.fromBytes((await storage.loadAll())['room']!)
              .participants,
          hasLength(1),
        );
        await worker.close();

        worker = await NoosphereWorker.start();
        await worker.startSetup(setupId: 'rooms', server: options);
        transport = await _transport(worker);
        expect(transport.pinnedServerId, secret.publicKey);
        await expectLater(
          IrohRoomEnrollmentApi.joinRoom(
            transport,
            invites[0],
            (_) async => keys[0],
          ),
          throwsA(isA<RoomEnrollmentProtocolException>()),
        );
        final completed = await IrohRoomEnrollmentApi.joinRoom(
          transport,
          invites[1],
          (_) async => keys[1],
        );
        expect(completed.participants, hasLength(2));
        expect(
          RoomSnapshot.fromBytes((await storage.loadAll())['room']!)
              .participants,
          hasLength(2),
        );
      } finally {
        await worker.close();
      }
    },
  );
}

Future<IrohClientTransportConfig> _transport(NoosphereWorker worker) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final address = (await worker.snapshot('rooms')).coordinator!;
    if (address.ipAddrs.isNotEmpty) {
      final id = PublicKey.fromZ32(address.id);
      return IrohClientTransportConfig(
        bootstrapAddress: EndpointAddr(id, ipAddrs: address.ipAddrs),
        pinnedServerId: id,
        relay: IrohRelayConfig.disabled(),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Worker did not publish a reachable address.');
}

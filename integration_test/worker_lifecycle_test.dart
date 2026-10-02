import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native objects close and restart with identity while setups stay independent',
    (_) async {
      // Exercise native bindings in the root isolate at the same time as the
      // worker and its process-wide Iroh stream registry.
      await NoosphereFlutter.initialize();
      final firstKey = ECPrivateKey(Uint8List(32)..last = 11);
      final secondKey = ECPrivateKey(Uint8List(32)..last = 12);
      final group = GroupConfig(
        id: 'worker-lifecycle',
        participants: {
          Identifier.fromUint16(1): ECCompressedPublicKey.fromPubkey(
            firstKey.pubkey,
          ),
          Identifier.fromUint16(2): ECCompressedPublicKey.fromPubkey(
            secondKey.pubkey,
          ),
        },
      );
      final firstIdentity = MemoryIdentityStore();
      final secondIdentity = MemoryIdentityStore();
      final directIdentity = MemoryIdentityStore();
      EmbeddedServerOptions options(MemoryIdentityStore store) =>
          EmbeddedServerOptions(
            serverConfig: ServerConfig(group: group),
            identityStore: store,
            serverPersistence: MemoryServerPersistence(),
            relay: IrohRelayConfig.disabled(),
          );

      var direct = await NoosphereNode.start(server: options(directIdentity));
      NoosphereWorker? worker;
      try {
        final directAddress = await reachableTestAddress(direct.server!);
        worker = await NoosphereWorker.start();
        await worker.startSetup(
          setupId: 'reconnect-signer',
          client: nativeTestClientOptions(
            group: group,
            participant: Identifier.fromUint16(1),
            key: firstKey,
            address: directAddress,
          ),
        );
        final startingFirst = worker.startSetup(
          setupId: 'first',
          server: options(firstIdentity),
        );
        await expectLater(
          worker.stopSetup('first'),
          throwsA(
            isA<NoosphereWorkerException>().having(
              (error) => error.code,
              'code',
              'setup_busy',
            ),
          ),
        );
        final first = await startingFirst;
        final wrongIdentity = MemoryIdentityStore();
        await expectLater(
          worker.startSetup(setupId: 'first', server: options(wrongIdentity)),
          throwsStateError,
        );
        expect(wrongIdentity.writes, 0);
        expect(
          await worker.exportIrohServerIdentity('first'),
          await firstIdentity.read(),
        );
        final second = await worker.startSetup(
          setupId: 'second',
          server: options(secondIdentity),
        );
        expect(first.coordinator, isNotNull);
        expect(second.coordinator, isNotNull);
        expect(first.coordinator!.id, isNot(second.coordinator!.id));
        await expectLater(
          worker.updateSignerAddress(
            'reconnect-signer',
            EndpointAddr(PublicKey.fromZ32(second.coordinator!.id)),
          ),
          throwsA(
            isA<NoosphereWorkerException>().having(
              (error) => error.code,
              'code',
              'invalid_argument',
            ),
          ),
        );

        final replacement = worker.events
            .where((event) => event is WorkerSessionReplacedEvent)
            .cast<WorkerSessionReplacedEvent>()
            .firstWhere((event) => event.setupId == 'reconnect-signer');
        await direct.close();
        for (var attempt = 0; attempt < 100; attempt++) {
          if (!(await worker.snapshot('reconnect-signer')).connected) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect((await worker.snapshot('reconnect-signer')).connected, isFalse);
        await expectLater(
          worker.requestDkg(
            'reconnect-signer',
            NewDkgDetails(
              name: 'not-replayed',
              description: 'Disconnected mutation must fail',
              threshold: 2,
              expiry: Expiry(const Duration(hours: 1)),
            ),
          ),
          throwsA(isA<NoosphereWorkerException>()),
        );
        direct = await NoosphereNode.start(server: options(directIdentity));
        await worker.updateSignerAddress(
          'reconnect-signer',
          await reachableTestAddress(direct.server!),
        );
        await replacement.timeout(const Duration(seconds: 30));
        final reconnected = await worker.snapshot('reconnect-signer');
        expect(reconnected.connected, isTrue);
        expect(
          reconnected.dkgs.any((dkg) => dkg.name == 'not-replayed'),
          isFalse,
        );

        await worker.stopSetup('first');
        expect((await worker.snapshot('second')).serverRunning, isTrue);
        final firstId = first.coordinator!.id;
        await worker.close();
        worker = null;

        worker = await NoosphereWorker.start();
        final restarted = await worker.startSetup(
          setupId: 'first',
          server: options(firstIdentity),
        );
        expect(restarted.coordinator!.id, firstId);
        expect(firstIdentity.writes, 1);
        expect(secondIdentity.writes, 1);
        expect(direct.serverId, isNotNull);

        await worker.close();
        worker = await NoosphereWorker.start();
        final thirdStart = await worker.startSetup(
          setupId: 'first',
          server: options(firstIdentity),
        );
        expect(thirdStart.coordinator!.id, firstId);
        expect(firstIdentity.writes, 1);
      } finally {
        await worker?.close();
        await direct.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

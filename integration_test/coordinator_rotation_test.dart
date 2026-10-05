import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'worker switches with old server offline and signs with unchanged FROST key',
    (_) async {
      await NoosphereFlutter.initialize();
      final f = _Fixture();
      final oldServer = await NoosphereNode.start(
        server: EmbeddedServerOptions(
          serverConfig: ServerConfig(group: f.group),
          getIrohSecretKey: freshTestIrohSecretKey(),
          serverPersistence: MemoryServerPersistence(),
          relay: IrohRelayConfig.disabled(),
        ),
      );
      addTearDown(oldServer.close);
      final newServer = await NoosphereNode.start(
        server: EmbeddedServerOptions(
          serverConfig: ServerConfig(group: f.group),
          getIrohSecretKey: freshTestIrohSecretKey(),
          serverPersistence: MemoryServerPersistence(),
          relay: IrohRelayConfig.disabled(),
        ),
      );
      addTearDown(newServer.close);
      final oldAddress = await reachableTestAddress(oldServer.server!);
      final newAddress = await reachableTestAddress(newServer.server!);
      final worker = await NoosphereWorker.start();
      addTearDown(worker.close);
      final stores = [for (var i = 0; i < 3; i++) InMemoryClientStorage()];
      final options = [
        for (var i = 0; i < 3; i++)
          nativeTestClientOptions(
            group: f.group,
            participant: Identifier.fromUint16(i + 1),
            key: f.keys[i],
            address: oldAddress,
            storage: stores[i],
          ),
      ];
      final events = <NoosphereWorkerEvent>[];
      final subscription = worker.events.listen(events.add);
      addTearDown(subscription.cancel);
      for (var i = 0; i < 3; i++) {
        await worker.startSetup(
          setupId: 'signer-$i',
          client: options[i],
          server: i == 0
              ? EmbeddedServerOptions(
                  serverConfig: ServerConfig(group: f.group),
                  getIrohSecretKey: freshTestIrohSecretKey(),
                  serverPersistence: MemoryServerPersistence(),
                  relay: IrohRelayConfig.disabled(),
                )
              : null,
        );
      }
      final proposals = [
        for (var i = 1; i < 3; i++)
          worker.events
              .where((e) => e is WorkerDkgEvent && e.setupId == 'signer-$i')
              .cast<WorkerDkgEvent>()
              .first,
      ];
      await worker.requestDkg(
        'signer-0',
        NewDkgDetails(
          name: 'rotation-test-key',
          description: 'Key must survive coordinator rotation',
          threshold: 2,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      );
      final keyFutures = [
        for (final store in stores)
          store.waitForKeyWithName('rotation-test-key', 3),
      ];
      for (var i = 1; i < 3; i++) {
        await worker.acceptDkg('signer-$i', (await proposals[i - 1]).status);
      }
      final keys = await Future.wait(keyFutures)
          .timeout(const Duration(minutes: 1));
      // A failure before or after the host write must leave the signer stopped.
      var selected = oldAddress;
      for (final afterWrite in [false, true]) {
        await expectLater(
          worker.switchCoordinator(
            'signer-0',
            newCoordinator: newAddress,
            persist: (address) async {
              if (afterWrite) selected = address;
              throw StateError('private persistence failure');
            },
          ),
          throwsA(
            isA<NoosphereWorkerException>().having(
              (error) => error.code,
              'code',
              'host_state',
            ),
          ),
        );
        final stopped = await worker.snapshot('signer-0');
        expect(stopped.signerRunning, isFalse);
        expect(stopped.serverRunning, isTrue);
        // A stopped snapshot does not release the providers. Acknowledge
        // cleanup, then restart from the app's reconciled durable selection.
        await expectLater(
          worker.startSetup(
            setupId: 'signer-0',
            client: options[0].withCoordinator(selected),
          ),
          throwsStateError,
        );
        await worker.lockSigner('signer-0');
        await worker.startSetup(
          setupId: 'signer-0',
          client: options[0].withCoordinator(selected),
        );
      }
      await oldServer.close();

      // No destination connection is made until persistence has completed.
      final persisting = Completer<void>();
      final durable = Completer<void>();
      final switching = worker.switchCoordinator(
        'signer-0',
        newCoordinator: newAddress,
        persist: (_) {
          persisting.complete();
          return durable.future;
        },
      );
      await persisting.future;
      expect((await worker.snapshot('signer-0')).connected, isFalse);
      await expectLater(
        worker.switchCoordinator(
          'signer-0',
          newCoordinator: newAddress,
          persist: (_) async {},
        ),
        throwsA(
          isA<NoosphereWorkerException>().having(
            (error) => error.code,
            'code',
            'setup_busy',
          ),
        ),
      );
      durable.complete();
      expect((await switching).serverRunning, isTrue);
      for (var i = 1; i < 3; i++) {
        await worker.switchCoordinator(
          'signer-$i',
          newCoordinator: newAddress,
          persist: (address) async {
            expect(address.id, newAddress.id);
          },
        );
      }
      for (var i = 0; i < 3; i++) {
        final snapshot = await worker.snapshot('signer-$i');
        expect(snapshot.connected, isTrue);
        expect(snapshot.keys.single.groupKeyHex, keys.first.groupKey.hex);
        expect(stores[i].keys.length, 1);
      }
      expect(events.whereType<WorkerSessionReplacedEvent>(), isNotEmpty);

      // A failed connection after persistence must not restore the previous pin.
      var committed = false;
      await expectLater(
        worker.switchCoordinator(
          'signer-2',
          newCoordinator: oldAddress,
          persist: (_) async {
            committed = true;
          },
        ),
        throwsA(isA<NoosphereWorkerException>()),
      );
      expect(committed, isTrue);
      expect((await worker.snapshot('signer-2')).connected, isFalse);
      await worker.switchCoordinator(
        'signer-2',
        newCoordinator: newAddress,
        persist: (_) async {},
      );

      final message = Uint8List(32)..last = 99;
      final request = SignaturesRequestDetails(
        requiredSigs: [
          SingleSignatureDetails(
            signDetails: SignDetails.keySpend(message: message),
            groupKey: keys.first.groupKey,
            hdDerivation: const [],
          ),
        ],
        expiry: Expiry(const Duration(minutes: 3)),
      );
      final pending = worker.events
          .where(
            (e) => e is WorkerSigningRequestEvent && e.setupId == 'signer-1',
          )
          .cast<WorkerSigningRequestEvent>()
          .first;
      final completed = worker.events
          .where(
            (e) => e is WorkerSigningResultEvent && e.setupId == 'signer-0',
          )
          .cast<WorkerSigningResultEvent>()
          .first;
      await worker.requestSignatures('signer-0', request);
      await worker.acceptSignatures('signer-1', (await pending).request);
      final result = await completed.timeout(const Duration(seconds: 30));
      expect(
        SchnorrSignature(
          result.signatures.single,
        ).verify(Taproot(internalKey: keys.first.groupKey).tweakedKey, message),
        isTrue,
      );
      // An unfinished signing request must block switching before persistence.
      final unfinished = SignaturesRequestDetails(
        requiredSigs: [
          SingleSignatureDetails(
            signDetails: SignDetails.keySpend(
              message: Uint8List(32)..last = 100,
            ),
            groupKey: keys.first.groupKey,
            hdDerivation: const [],
          ),
        ],
        expiry: Expiry(const Duration(minutes: 3)),
      );
      await worker.requestSignatures('signer-0', unfinished);
      var persisted = false;
      await expectLater(
        worker.switchCoordinator(
          'signer-0',
          newCoordinator: oldAddress,
          persist: (_) async {
            persisted = true;
          },
        ),
        throwsA(
          isA<NoosphereWorkerException>().having(
            (error) => error.code,
            'code',
            'pending_signing_operations',
          ),
        ),
      );
      expect(persisted, isFalse);
      expect(stores[0].sigNonces.containsKey(unfinished.id), isTrue);
      final stopped = await worker.snapshot('signer-0');
      expect(stopped.signerRunning, isFalse);
      expect(stopped.serverRunning, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

final class _Fixture {
  _Fixture() {
    group = GroupConfig(
      id: 'rotation-group',
      participants: {
        for (var i = 0; i < keys.length; i++)
          Identifier.fromUint16(i + 1): ECCompressedPublicKey.fromPubkey(
            keys[i].pubkey,
          ),
      },
    );
  }
  final keys = [
    for (var i = 1; i <= 3; i++) ECPrivateKey(Uint8List(32)..last = i),
  ];
  late final GroupConfig group;
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/src/iroh_node.dart' show NoosphereRuntime;
import 'package:noosphere_flutter/testing.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('oversized startup retains providers and permits stop/restart', (
    _,
  ) async {
    await NoosphereFlutter.initialize();
    final keys = [
      ECPrivateKey(Uint8List(32)..last = 31),
      ECPrivateKey(Uint8List(32)..last = 32),
    ];
    final ids = [Identifier.fromUint16(1), Identifier.fromUint16(2)];
    final group = GroupConfig(
      id: 'oversized-start',
      participants: {
        for (var i = 0; i < 2; i++)
          ids[i]: ECCompressedPublicKey.fromPubkey(keys[i].pubkey),
      },
    );
    final server = await NoosphereRuntime.start(
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        getIrohSecretKey: freshTestIrohSecretKey(),
        serverPersistence: MemoryServerPersistence(),
        relay: IrohRelayConfig.disabled(),
      ),
    );
    addTearDown(server.close);
    final address = await reachableTestAddress(server.server!);
    final requester = await NoosphereRuntime.start(
      client: nativeTestClientOptions(
        group: group,
        participant: ids[0],
        key: keys[0],
        address: address,
      ),
    );
    addTearDown(requester.close);
    for (var i = 0; i < 3; i++) {
      await requester.client!.current.requestDkg(
        NewDkgDetails(
          name: 'pending-$i',
          description: 'x' * 1000,
          threshold: 2,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      );
    }
    final worker = await NoosphereWorker.startNativeForTesting(
      maxMessageBytes: 4096,
    );
    addTearDown(worker.close);
    final storage = InMemoryClientStorage();
    final options = nativeTestClientOptions(
      group: group,
      participant: ids[1],
      key: keys[1],
      address: address,
      storage: storage,
    );
    final startedButUnavailable = throwsA(
      isA<NoosphereWorkerException>().having(
        (e) => e.code,
        'code',
        'start_result_too_large',
      ),
    );
    await expectLater(
      worker.startSetup(setupId: 'signer', client: options),
      startedButUnavailable,
    );
    // This operation needs the retained private-key callback.
    await worker.requestDkg(
      'signer',
      NewDkgDetails(
        name: 'after-overflow',
        description: '',
        threshold: 2,
        expiry: Expiry(const Duration(hours: 1)),
      ),
    );
    // This operation needs the retained client persistence provider.
    final rejectedId = Uint8List(16)..last = 99;
    await worker.debugClientStorageForTesting(
      'signer',
      rejectRequestId: rejectedId,
    );
    expect(
      (await storage.loadState()).rejectedRequests.keys.single.toBytes(),
      rejectedId,
    );
    // Adding a role must preserve existing providers when the combined
    // startup snapshot is still too large to deliver.
    final identity = SecretKey.generate();
    await expectLater(
      worker.startSetup(
        setupId: 'signer',
        server: EmbeddedServerOptions(
          serverConfig: ServerConfig(group: group),
          getIrohSecretKey: () => identity,
          serverPersistence: MemoryServerPersistence(),
          relay: IrohRelayConfig.disabled(),
        ),
      ),
      startedButUnavailable,
    );
    expect(await worker.debugClientStorageForTesting('signer'), [rejectedId]);
    await worker.stopSetup('signer');
    await expectLater(
      worker.startSetup(setupId: 'signer', client: options),
      startedButUnavailable,
    );
    await worker.stopSetup('signer');
  });

  testWidgets('unexpected server completion emits failure and stopped status', (
    _,
  ) async {
    await NoosphereFlutter.initialize();
    final group = GroupConfig(
      id: 'serve-health',
      participants: {
        for (var i = 1; i <= 2; i++)
          Identifier.fromUint16(i): ECCompressedPublicKey.fromPubkey(
            ECPrivateKey(Uint8List(32)..last = i).pubkey,
          ),
      },
    );
    final worker = await NoosphereWorker.startNativeForTesting();
    addTearDown(worker.close);
    final options = EmbeddedServerOptions(
      serverConfig: ServerConfig(group: group),
      getIrohSecretKey: freshTestIrohSecretKey(),
      serverPersistence: MemoryServerPersistence(),
      relay: IrohRelayConfig.disabled(),
    );
    await worker.startSetup(setupId: 'server', server: options);
    final failure = worker.events
        .where((e) => e is WorkerFailureEvent)
        .cast<WorkerFailureEvent>()
        .firstWhere((e) => e.operation == 'serve');
    await worker.debugStopServingForTesting('server');
    await failure.timeout(const Duration(seconds: 10));
    expect((await worker.snapshot('server')).serverRunning, isFalse);
    // Health becoming false does not release provider ownership before the
    // host acknowledges cleanup; restarting requires an explicit stop.
    await expectLater(
      worker.startSetup(setupId: 'server', server: options),
      throwsStateError,
    );
    await worker.stopSetup('server');
    expect(
      (await worker.startSetup(
        setupId: 'server',
        server: options,
      )).serverRunning,
      isTrue,
    );
    await worker.stopSetup('server');
  });
}

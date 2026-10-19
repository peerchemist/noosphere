import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

import 'test_support.dart';

const _dropoutDuration = Duration(minutes: 4);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('3-of-3 DKG survives an accepted co-signer crash and restart', (
    _,
  ) async {
    final (:worker, :group, :stores, :options) = await _startGroup(
      'worker-dkg-crash-recovery',
    );
    const dkgName = 'three-of-three-after-crash';
    final received = await _requestDkg(
      worker,
      group,
      dkgName,
      'An accepted co-signer restarts during round one',
    );
    await worker.acceptDkg('signer-1', received.first.status);
    final exportedSecret = await worker.exportDkgSecret('signer-1', dkgName);

    // Discard this signer's process-local session after it has published its
    // commitment. The wrapping app retains the explicitly exported secret.
    await worker.stopSetup('signer-1');
    final restarted = await worker.startSetup(
      setupId: 'signer-1',
      client: options[1],
    );
    final blocked = restarted.dkgs.singleWhere((dkg) => dkg.name == dkgName);
    expect(blocked.stage, 'round1');
    expect(blocked.canResume, isFalse);

    await worker.importDkgSecret('signer-1', exportedSecret);
    final resumed = (await worker.snapshot('signer-1')).dkgs
        .singleWhere((dkg) => dkg.name == dkgName);
    expect(resumed.stage, 'round1');
    expect(resumed.canResume, isTrue);

    final completedKeys = _waitForKeys(stores, dkgName);
    await worker.acceptDkg('signer-2', received.last.status);
    await _expectCompleted(worker, await completedKeys);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('3-of-3 DKG resumes when one co-signer returns after 4 minutes', (
    _,
  ) async {
    final (:worker, :group, :stores, :options) = await _startGroup(
      'worker-dkg-dropout',
    );
    const dkgName = 'three-of-three-after-dropout';
    final received = await _requestDkg(
      worker,
      group,
      dkgName,
      'One co-signer is offline for four minutes',
    );
    await worker.lockSigner('signer-2');
    await worker.acceptDkg('signer-1', received.first.status);

    await Future<void>.delayed(_dropoutDuration);
    expect(stores.every((store) => store.keys.isEmpty), isTrue);
    for (var i = 0; i < 2; i++) {
      final pending = (await worker.snapshot('signer-$i')).dkgs
          .singleWhere((dkg) => dkg.name == dkgName);
      expect(pending.stage, 'round1');
      expect(pending.canResume, isTrue);
    }

    final completedKeys = _waitForKeys(stores, dkgName);
    final returning = await worker.startSetup(
      setupId: 'signer-2',
      client: options[2],
    );
    final pending = returning.dkgs.singleWhere((dkg) => dkg.name == dkgName);
    expect(pending.stage, 'waiting');
    expect(pending.canResume, isTrue);
    await worker.acceptDkg('signer-2', pending);

    await _expectCompleted(worker, await completedKeys);
  }, timeout: const Timeout(Duration(minutes: 7)));
}

Future<
  ({
    NoosphereWorker worker,
    GroupConfig group,
    List<InMemoryClientStorage> stores,
    List<ClientNodeOptions> options,
  })
>
_startGroup(String groupId) async {
  await NoosphereFlutter.initialize();
  final keys = [
    for (var i = 1; i <= 3; i++) ECPrivateKey(Uint8List(32)..last = i),
  ];
  final ids = [for (var i = 1; i <= 3; i++) Identifier.fromUint16(i)];
  final group = GroupConfig(
    id: groupId,
    participants: {
      for (var i = 0; i < 3; i++)
        ids[i]: ECCompressedPublicKey.fromPubkey(keys[i].pubkey),
    },
  );
  final stores = [for (var i = 0; i < 3; i++) InMemoryClientStorage()];
  final worker = await NoosphereWorker.start();
  addTearDown(worker.close);
  final reachableSnapshot = worker.events
      .where((event) => event is WorkerSnapshotEvent)
      .cast<WorkerSnapshotEvent>()
      .map((event) => event.snapshot)
      .firstWhere(
        (snapshot) =>
            snapshot.setupId == 'signer-0' &&
            snapshot.coordinator?.ipAddrs.isNotEmpty == true,
      );
  var server = await worker.startSetup(
    setupId: 'signer-0',
    server: EmbeddedServerOptions(
      serverConfig: ServerConfig(group: group),
      getIrohSecretKey: freshTestIrohSecretKey(),
      serverPersistence: MemoryServerPersistence(),
      relay: IrohRelayConfig.disabled(),
    ),
  );
  if (server.coordinator!.ipAddrs.isEmpty) {
    server = await reachableSnapshot.timeout(const Duration(seconds: 15));
  }
  final coordinator = server.coordinator!;
  final address = EndpointAddr(
    PublicKey.fromZ32(coordinator.id),
    ipAddrs: coordinator.ipAddrs,
  );
  final options = [
    for (var i = 0; i < 3; i++)
      nativeTestClientOptions(
        group: group,
        participant: ids[i],
        key: keys[i],
        address: address,
        storage: stores[i],
      ),
  ];
  for (var i = 0; i < 3; i++) {
    await worker.startSetup(setupId: 'signer-$i', client: options[i]);
  }
  return (worker: worker, group: group, stores: stores, options: options);
}

Future<List<WorkerDkgEvent>> _requestDkg(
  NoosphereWorker worker,
  GroupConfig group,
  String name,
  String description,
) async {
  final proposals = [
    for (var i = 1; i < 3; i++)
      worker.events
          .where((event) => event is WorkerDkgEvent)
          .cast<WorkerDkgEvent>()
          .firstWhere(
            (event) =>
                event.setupId == 'signer-$i' &&
                event.status.name == name &&
                !event.rejected,
          ),
  ];
  await worker.requestDkg(
    'signer-0',
    NewDkgDetails(
      name: name,
      description: description,
      threshold: 3,
      expiry: Expiry(const Duration(hours: 1)),
      groupFingerprint: group.fingerprint,
    ),
  );
  return Future.wait(proposals).timeout(const Duration(seconds: 15));
}

Future<List<FrostKeyWithDetails>> _waitForKeys(
  List<InMemoryClientStorage> stores,
  String name,
) =>
    Future.wait(stores.map((store) => store.waitForKeyWithName(name, 3)))
        .timeout(const Duration(minutes: 2));

Future<void> _expectCompleted(
  NoosphereWorker worker,
  List<FrostKeyWithDetails> keys,
) async {
  expect(keys.map((key) => key.groupKey).toSet(), hasLength(1));
  for (var i = 0; i < 3; i++) {
    final snapshot = await worker.snapshot('signer-$i');
    expect(snapshot.dkgs, isEmpty);
    expect(snapshot.keys.single.groupKeyHex, keys.first.groupKey.hex);
  }
}

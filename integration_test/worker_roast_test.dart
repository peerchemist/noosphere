import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final scenario in [
    (participants: 2, threshold: 2),
    (participants: 3, threshold: 2),
  ]) {
    testWidgets(
      'worker completes and verifies ${scenario.threshold}-of-${scenario.participants} ROAST',
      (_) => _runScenario(
        participants: scenario.participants,
        threshold: scenario.threshold,
      ),
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}

Future<void> _runScenario({
  required int participants,
  required int threshold,
}) async {
  // Host storage deserializes Frosty values, so both host and worker bindings
  // are intentionally initialized for this proxy-storage integration test.
  await NoosphereFlutter.initialize();
  final privateKeys = [
    for (var i = 1; i <= participants; i++)
      ECPrivateKey(Uint8List(32)..last = i),
  ];
  final ids = [
    for (var i = 1; i <= participants; i++) Identifier.fromUint16(i),
  ];
  final group = GroupConfig(
    id: 'flutter-worker-$threshold-of-$participants',
    participants: {
      for (var i = 0; i < participants; i++)
        ids[i]: ECCompressedPublicKey.fromPubkey(privateKeys[i].pubkey),
    },
  );
  final stores = [
    for (var i = 0; i < participants; i++) InMemoryClientStorage(),
  ];
  final worker = await NoosphereWorker.start();
  final events = worker.events;

  try {
    final reachableSnapshot = events
        .where((event) => event is WorkerSnapshotEvent)
        .cast<WorkerSnapshotEvent>()
        .map((event) => event.snapshot)
        .firstWhere(
          (snapshot) =>
              snapshot.setupId == 'server' &&
              snapshot.coordinator?.ipAddrs.isNotEmpty == true,
        );
    var serverSnapshot = await worker.startSetup(
      setupId: 'server',
      identityStorageId: 'worker-native-$threshold-of-$participants',
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        identityStore: MemoryIdentityStore(),
        relay: IrohRelayConfig.disabled(),
      ),
    );
    if (serverSnapshot.coordinator!.ipAddrs.isEmpty) {
      serverSnapshot = await reachableSnapshot.timeout(
        const Duration(seconds: 15),
      );
    }
    final coordinator = serverSnapshot.coordinator!;
    final address = EndpointAddr(
      PublicKey.fromZ32(coordinator.id),
      ipAddrs: coordinator.ipAddrs,
    );
    for (var i = 0; i < participants; i++) {
      await worker.startSetup(
        setupId: 'signer-$i',
        client: nativeTestClientOptions(
          group: group,
          participant: ids[i],
          key: privateKeys[i],
          address: address,
          storage: stores[i],
        ),
      );
    }

    final dkgName = 'worker-$threshold-of-$participants';
    final pendingDkgs = [
      for (var i = 1; i < participants; i++)
        events
            .where((event) => event is WorkerDkgEvent)
            .cast<WorkerDkgEvent>()
            .firstWhere(
              (event) =>
                  event.setupId == 'signer-$i' && event.status.name == dkgName,
            ),
    ];
    await worker.requestDkg(
      'signer-0',
      NewDkgDetails(
        name: dkgName,
        description: 'Native worker integration test',
        threshold: threshold,
        expiry: Expiry(const Duration(hours: 1)),
      ),
    );
    final proposals = await Future.wait(pendingDkgs)
        .timeout(const Duration(seconds: 15));
    final completedKeys = Future.wait([
      for (final store in stores)
        store.waitForKeyWithName(dkgName, participants),
    ]);
    for (var i = 1; i < participants; i++) {
      await worker.acceptDkg('signer-$i', proposals[i - 1].status);
    }
    final frostKeys = await completedKeys.timeout(const Duration(minutes: 2));

    final message = Uint8List(32)..last = 40 + participants;
    final details = SignaturesRequestDetails(
      requiredSigs: [
        SingleSignatureDetails(
          signDetails: SignDetails.keySpend(message: message),
          groupKey: frostKeys.first.groupKey,
          hdDerivation: const [],
        ),
      ],
      expiry: Expiry(const Duration(minutes: 3)),
    );
    final secondRequest = events
        .where((event) => event is WorkerSigningRequestEvent)
        .cast<WorkerSigningRequestEvent>()
        .firstWhere((event) => event.setupId == 'signer-1');
    final resultFutures = [
      for (var i = 0; i < threshold; i++)
        events
            .where((event) => event is WorkerSigningResultEvent)
            .cast<WorkerSigningResultEvent>()
            .firstWhere((event) => event.setupId == 'signer-$i'),
    ];
    await worker.requestSignatures('signer-0', details);
    final request = await secondRequest.timeout(const Duration(seconds: 15));
    await worker.acceptSignatures('signer-1', request.request);
    final results = await Future.wait(resultFutures)
        .timeout(const Duration(minutes: 2));

    for (final result in results) {
      expect(result.signatures, hasLength(1));
      expect(
        SchnorrSignature(result.signatures.single).verify(
          Taproot(internalKey: frostKeys.first.groupKey).tweakedKey,
          message,
        ),
        isTrue,
      );
    }
  } finally {
    await worker.close();
  }
}

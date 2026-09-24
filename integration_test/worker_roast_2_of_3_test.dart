import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('worker completes and verifies a 2-of-3 quorum', (_) async {
    await NoosphereFlutter.initialize();
    final keys = [
      for (var i = 1; i <= 3; i++) ECPrivateKey(Uint8List(32)..last = i),
    ];
    final ids = [for (var i = 1; i <= 3; i++) Identifier.fromUint16(i)];
    final group = GroupConfig(
      id: 'flutter-worker-2-of-3-integration',
      participants: {
        for (var i = 0; i < ids.length; i++)
          ids[i]: ECCompressedPublicKey.fromPubkey(keys[i].pubkey),
      },
    );
    final stores = [
      for (var i = 0; i < ids.length; i++) InMemoryClientStorage(),
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
                snapshot.coordinator != null &&
                snapshot.coordinator!.ipAddrs.isNotEmpty,
          );
      var serverSnapshot = await worker.startSetup(
        setupId: 'server',
        identityStorageId: 'worker-native-2-of-3-test',
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
      for (var i = 0; i < ids.length; i++) {
        await worker.startSetup(
          setupId: 'signer-$i',
          client: nativeTestClientOptions(
            group: group,
            participant: ids[i],
            key: keys[i],
            address: address,
            storage: stores[i],
          ),
        );
      }

      const dkgName = 'worker-2-of-3';
      final pendingDkgs = [
        for (var i = 1; i < ids.length; i++)
          events
              .where((event) => event is WorkerDkgEvent)
              .cast<WorkerDkgEvent>()
              .firstWhere(
                (event) =>
                    event.setupId == 'signer-$i' &&
                    event.status.name == dkgName,
              ),
      ];
      await worker.requestDkg(
        'signer-0',
        NewDkgDetails(
          name: dkgName,
          description: 'Native worker 2-of-3 integration test',
          threshold: 2,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      );
      final dkgProposals = await Future.wait(pendingDkgs)
          .timeout(const Duration(seconds: 15));
      final completedKeys = Future.wait([
        for (final store in stores) store.waitForKeyWithName(dkgName, 3),
      ]);
      await worker.acceptDkg('signer-1', dkgProposals[0].status);
      await worker.acceptDkg('signer-2', dkgProposals[1].status);
      final frostKeys = await completedKeys.timeout(const Duration(minutes: 2));

      final message = Uint8List(32)..last = 99;
      final details = SignaturesRequestDetails(
        requiredSigs: [
          SingleSignatureDetails(
            signDetails: SignDetails.scriptSpend(message: message),
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
      final requesterResult = events
          .where((event) => event is WorkerSigningResultEvent)
          .cast<WorkerSigningResultEvent>()
          .firstWhere((event) => event.setupId == 'signer-0');
      await worker.requestSignatures('signer-0', details);
      final request = await secondRequest.timeout(const Duration(seconds: 15));
      await worker.acceptSignatures('signer-1', request.request);
      final result = await requesterResult.timeout(const Duration(minutes: 2));

      expect(result.signatures, hasLength(1));
      expect(
        SchnorrSignature(result.signatures.single)
            .verify(frostKeys.first.groupKey, message),
        isTrue,
      );
    } finally {
      await worker.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

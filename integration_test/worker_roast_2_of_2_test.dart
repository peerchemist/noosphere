import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('worker completes and verifies native 2-of-2 ROAST', (_) async {
    // Host storage objects deserialize Frosty values, so this integration test
    // intentionally initializes both host and worker bindings.
    await NoosphereFlutter.initialize();
    final keys = [
      ECPrivateKey(Uint8List(32)..last = 1),
      ECPrivateKey(Uint8List(32)..last = 2),
    ];
    final ids = [Identifier.fromUint16(1), Identifier.fromUint16(2)];
    final group = GroupConfig(
      id: 'flutter-worker-roast-integration',
      participants: {
        for (var i = 0; i < ids.length; i++)
          ids[i]: ECCompressedPublicKey.fromPubkey(keys[i].pubkey),
      },
    );
    final stores = [InMemoryClientStorage(), InMemoryClientStorage()];
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
                (snapshot.coordinator!.ipAddrs.isNotEmpty ||
                    snapshot.coordinator!.relayUrls.isNotEmpty),
          );
      var serverSnapshot = await worker.startSetup(
        setupId: 'server',
        identityStorageId: 'worker-native-test',
        server: EmbeddedServerOptions(
          serverConfig: ServerConfig(group: group),
          identityStore: MemoryIdentityStore(),
          relay: IrohRelayConfig.disabled(),
        ),
      );
      if (serverSnapshot.coordinator!.ipAddrs.isEmpty &&
          serverSnapshot.coordinator!.relayUrls.isEmpty) {
        serverSnapshot = await reachableSnapshot.timeout(
          const Duration(seconds: 15),
        );
      }
      final coordinator = serverSnapshot.coordinator!;
      final address = EndpointAddr(
        PublicKey.fromZ32(coordinator.id),
        relayUrls: [
          for (final url in coordinator.relayUrls) RelayUrl.parse(url),
        ],
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

      const dkgName = 'worker-2-of-2';
      final secondDkg = events
          .where((event) => event is WorkerDkgEvent)
          .cast<WorkerDkgEvent>()
          .firstWhere(
            (event) =>
                event.setupId == 'signer-1' && event.status.name == dkgName,
          );
      await worker.requestDkg(
        'signer-0',
        NewDkgDetails(
          name: dkgName,
          description: 'Native worker integration test',
          threshold: 2,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      );
      final dkg = await secondDkg.timeout(const Duration(seconds: 15));
      final completedKeys = Future.wait([
        stores[0].waitForKeyWithName(dkgName, 2),
        stores[1].waitForKeyWithName(dkgName, 2),
      ]);
      await worker.acceptDkg('signer-1', dkg.status);
      final frostKeys = await completedKeys.timeout(const Duration(minutes: 2));

      final message = Uint8List(32)..last = 42;
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
      final firstResult = events
          .where((event) => event is WorkerSigningResultEvent)
          .cast<WorkerSigningResultEvent>()
          .firstWhere((event) => event.setupId == 'signer-0');
      await worker.requestSignatures('signer-0', details);
      final request = await secondRequest.timeout(const Duration(seconds: 15));
      final secondResult = events
          .where((event) => event is WorkerSigningResultEvent)
          .cast<WorkerSigningResultEvent>()
          .firstWhere((event) => event.setupId == 'signer-1');
      await worker.acceptSignatures('signer-1', request.request);

      final results = await Future.wait([firstResult, secondResult])
          .timeout(const Duration(minutes: 2));
      for (final result in results) {
        expect(result.signatures, hasLength(1));
        expect(
          SchnorrSignature(result.signatures.single)
              .verify(frostKeys.first.groupKey, message),
          isTrue,
        );
      }
    } finally {
      await worker.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

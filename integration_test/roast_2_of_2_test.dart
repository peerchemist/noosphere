import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completes a native 2-of-2 DKG and ROAST signature', (_) async {
    await NoosphereFlutter.initialize();

    final participantKeys = [
      ECPrivateKey(Uint8List(32)..last = 1),
      ECPrivateKey(Uint8List(32)..last = 2),
    ];
    final participantIds = [Identifier.fromUint16(1), Identifier.fromUint16(2)];
    final group = GroupConfig(
      id: 'flutter-native-roast-integration',
      participants: {
        for (var i = 0; i < participantIds.length; i++)
          participantIds[i]: ECCompressedPublicKey.fromPubkey(
            participantKeys[i].pubkey,
          ),
      },
    );
    final stores = [InMemoryClientStorage(), InMemoryClientStorage()];
    final serverNode = await NoosphereNode.start(
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        identityStore: MemoryIdentityStore(),
        relay: IrohRelayConfig.disabled(),
      ),
    );
    final address = await reachableTestAddress(serverNode.server!);
    final clientNodes = <NoosphereNode>[];

    try {
      for (var i = 0; i < participantIds.length; i++) {
        clientNodes.add(
          await NoosphereNode.start(
            client: nativeTestClientOptions(
              group: group,
              participant: participantIds[i],
              key: participantKeys[i],
              address: address,
              storage: stores[i],
            ),
          ),
        );
      }
      final clients = clientNodes.map((node) => node.client!.current).toList();
      final events = clients
          .map((client) => client.events.asBroadcastStream())
          .toList();
      const dkgName = 'native-2-of-2';
      final secondSawDkg = events[1]
          .where((event) => event is UpdatedDkgClientEvent)
          .cast<UpdatedDkgClientEvent>()
          .firstWhere((event) => event.progress.details.name == dkgName);

      await clients[0].requestDkg(
        NewDkgDetails(
          name: dkgName,
          description: 'Native Flutter 2-of-2 integration test',
          threshold: 2,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      );
      await secondSawDkg.timeout(const Duration(seconds: 15));
      final completedKeys = Future.wait([
        stores[0].waitForKeyWithName(dkgName, 2),
        stores[1].waitForKeyWithName(dkgName, 2),
      ]);
      await clients[1].acceptDkg(dkgName);
      final keys = await completedKeys.timeout(const Duration(minutes: 2));
      expect(keys[1].groupKey, keys[0].groupKey);

      final message = Uint8List(32)..last = 42;
      final request = SignaturesRequestDetails(
        requiredSigs: [
          SingleSignatureDetails(
            signDetails: SignDetails.scriptSpend(message: message),
            groupKey: keys[0].groupKey,
            hdDerivation: const [],
          ),
        ],
        expiry: Expiry(const Duration(minutes: 3)),
      );
      final secondSawRequest = events[1]
          .where((event) => event is SignaturesRequestClientEvent)
          .cast<SignaturesRequestClientEvent>()
          .firstWhere((event) => event.request.details.id == request.id);
      final firstCompleted = events[0]
          .where((event) => event is SignaturesCompleteClientEvent)
          .cast<SignaturesCompleteClientEvent>()
          .firstWhere((event) => event.details.id == request.id);

      await clients[0].requestSignatures(request);
      await secondSawRequest.timeout(const Duration(seconds: 15));
      final secondCompleted = events[1]
          .where((event) => event is SignaturesCompleteClientEvent)
          .cast<SignaturesCompleteClientEvent>()
          .firstWhere((event) => event.details.id == request.id);
      await clients[1].acceptSignaturesRequest(request.id);

      final results = await Future.wait([firstCompleted, secondCompleted])
          .timeout(const Duration(minutes: 2));
      for (final result in results) {
        expect(result.signatures, hasLength(1));
        expect(
          result.signatures.single.verify(keys[0].groupKey, message),
          isTrue,
        );
      }
      expect(
        results[1].signatures.single.data,
        orderedEquals(results[0].signatures.single.data),
      );
    } finally {
      for (final node in clientNodes.reversed) {
        await node.close();
      }
      await serverNode.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/src/iroh_node.dart' show NoosphereRuntime;

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'authenticates, receives snapshot/event, reconnects, and preserves identity',
    (_) async {
      await NoosphereFlutter.initialize();

      final firstKey = ECPrivateKey(Uint8List(32)..last = 1);
      final secondKey = ECPrivateKey(Uint8List(32)..last = 2);
      final firstId = Identifier.fromUint16(1);
      final secondId = Identifier.fromUint16(2);
      final group = GroupConfig(
        id: 'flutter-native-integration',
        participants: {
          firstId: ECCompressedPublicKey.fromPubkey(firstKey.pubkey),
          secondId: ECCompressedPublicKey.fromPubkey(secondKey.pubkey),
        },
      );
      final irohSecretKey = SecretKey.generate();
      final serverOptions = EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        getIrohSecretKey: () => irohSecretKey,
        serverPersistence: MemoryServerPersistence(),
        relay: IrohRelayConfig.disabled(),
      );

      var serverNode = await NoosphereRuntime.start(server: serverOptions);
      final initialServerId = serverNode.serverId!;
      final initialAddress = await reachableTestAddress(serverNode.server!);
      final firstClientNode = await NoosphereRuntime.start(
        client: nativeTestClientOptions(
          group: group,
          participant: firstId,
          key: firstKey,
          address: initialAddress,
        ),
      );
      final firstSession = firstClientNode.client!.current;

      await firstSession.requestDkg(
        NewDkgDetails(
          name: 'snapshot-dkg',
          description: 'must arrive in the initial snapshot',
          threshold: 2,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      );

      final secondClientNode = await NoosphereRuntime.start(
        client: nativeTestClientOptions(
          group: group,
          participant: secondId,
          key: secondKey,
          address: initialAddress,
        ),
      );
      final secondSession = secondClientNode.client!.current;
      expect(secondSession.dkgExists('snapshot-dkg'), isTrue);

      final event = secondSession.events
          .where((event) => event is UpdatedDkgClientEvent)
          .cast<UpdatedDkgClientEvent>()
          .firstWhere((event) => event.progress.details.name == 'event-dkg');
      await firstSession.requestDkg(
        NewDkgDetails(
          name: 'event-dkg',
          description: 'must arrive over the live event stream',
          threshold: 2,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      );
      await event.timeout(const Duration(seconds: 15));

      await secondClientNode.close();

      final replacementFuture = firstClientNode.client!.sessions.first;
      await serverNode.close();
      await expectLater(
        firstSession.requestDkg(
          NewDkgDetails(
            name: 'not-replayed',
            description: 'a disconnected mutation must not be queued',
            threshold: 2,
            expiry: Expiry(const Duration(hours: 1)),
          ),
        ),
        throwsA(anything),
      );

      serverNode = await NoosphereRuntime.start(server: serverOptions);
      expect(serverNode.serverId, initialServerId);
      final replacementAddress = await reachableTestAddress(serverNode.server!);
      firstClientNode.client!.updateTransportConfig(
        IrohClientTransportConfig(
          bootstrapAddress: replacementAddress,
          pinnedServerId: initialServerId,
          relay: IrohRelayConfig.disabled(),
        ),
      );
      final replacement = await replacementFuture.timeout(
        const Duration(seconds: 30),
      );
      expect(identical(replacement, firstSession), isFalse);
      expect(replacement.dkgExists('not-replayed'), isFalse);

      await firstClientNode.close();
      await serverNode.close();

      expect(File('host-managed://iroh-secret').existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

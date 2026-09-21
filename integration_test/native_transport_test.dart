import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

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
      final identityStore = _MemoryIdentityStore();
      final serverOptions = EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        identityStore: identityStore,
        relay: IrohRelayConfig.disabled(),
      );

      var serverNode = await NoosphereNode.start(server: serverOptions);
      final initialServerId = serverNode.serverId!;
      final initialAddress = await _reachableAddress(serverNode.server!);
      final firstClientNode = await NoosphereNode.start(
        client: _clientOptions(
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

      final secondClientNode = await NoosphereNode.start(
        client: _clientOptions(
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

      serverNode = await NoosphereNode.start(server: serverOptions);
      expect(serverNode.serverId, initialServerId);
      final replacementAddress = await _reachableAddress(serverNode.server!);
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

      expect(identityStore.writes, 1);
      expect(File('host-managed://iroh-secret').existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

ClientNodeOptions _clientOptions({
  required GroupConfig group,
  required Identifier participant,
  required ECPrivateKey key,
  required EndpointAddr address,
}) => ClientNodeOptions(
  clientConfig: ClientConfig(group: group, id: participant),
  bootstrapAddress: address,
  pinnedServerId: address.id,
  relay: IrohRelayConfig.disabled(),
  storage: InMemoryClientStorage(),
  getPrivateKey: (_) async => key,
  reconnect: const IrohReconnectConfig(
    initialDelay: Duration(milliseconds: 100),
    maxDelay: Duration(seconds: 1),
    jitter: 0,
  ),
);

Future<EndpointAddr> _reachableAddress(IrohServer server) async {
  final current = server.address;
  if (current.ipAddrs.isNotEmpty || current.relayUrls.isNotEmpty) {
    return current;
  }
  return server.endpoint
      .watchAddr()
      .firstWhere(
        (address) => address.ipAddrs.isNotEmpty || address.relayUrls.isNotEmpty,
      )
      .timeout(const Duration(seconds: 15));
}

final class _MemoryIdentityStore implements ServerIdentityStore {
  Uint8List? _secret;
  int writes = 0;

  @override
  Future<Uint8List?> read() async =>
      _secret == null ? null : Uint8List.fromList(_secret!);

  @override
  Future<void> write(Uint8List secret) async {
    writes++;
    _secret = Uint8List.fromList(secret);
  }
}

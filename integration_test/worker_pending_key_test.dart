import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('canceled and pending key providers do not deadlock shutdown', (
    _,
  ) async {
    await NoosphereFlutter.initialize();
    final firstKey = ECPrivateKey(Uint8List(32)..last = 31);
    final secondKey = ECPrivateKey(Uint8List(32)..last = 32);
    final id = Identifier.fromUint16(1);
    final group = GroupConfig(
      id: 'worker-pending-key',
      participants: {
        id: ECCompressedPublicKey.fromPubkey(firstKey.pubkey),
        Identifier.fromUint16(2): ECCompressedPublicKey.fromPubkey(
          secondKey.pubkey,
        ),
      },
    );
    final server = await NoosphereNode.start(
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        getIrohSecretKey: freshTestIrohSecretKey(),
        serverPersistence: MemoryServerPersistence(),
        relay: IrohRelayConfig.disabled(),
      ),
    );
    NoosphereWorker? worker;
    try {
      final address = await reachableTestAddress(server.server!);
      worker = await NoosphereWorker.start(
        shutdownTimeout: const Duration(milliseconds: 250),
        hostOperationTimeout: const Duration(seconds: 5),
      );
      ClientNodeOptions options(GetPrivateKey provider) => ClientNodeOptions(
        clientConfig: ClientConfig(group: group, id: id),
        bootstrapAddress: address,
        pinnedServerId: address.id,
        storage: InMemoryClientStorage(),
        getPrivateKey: provider,
        relay: IrohRelayConfig.disabled(),
      );

      await expectLater(
        worker.startSetup(
          setupId: 'canceled',
          client: options((_) async => throw StateError('private cancel data')),
        ),
        throwsA(
          isA<NoosphereWorkerException>().having(
            (error) => error.message,
            'message',
            isNot(contains('private cancel data')),
          ),
        ),
      );

      final entered = Completer<void>();
      final release = Completer<ECPrivateKey>();
      final starting = worker.startSetup(
        setupId: 'pending',
        client: options((_) {
          entered.complete();
          return release.future;
        }),
      );
      final failedStart = expectLater(
        starting,
        throwsA(isA<NoosphereWorkerException>()),
      );
      await entered.future.timeout(const Duration(seconds: 15));
      await worker.close().timeout(const Duration(seconds: 3));
      await failedStart;
      release.complete(firstKey);
    } finally {
      await worker?.close();
      await server.close();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

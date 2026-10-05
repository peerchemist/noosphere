import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pending identity initializer stays outside the worker runtime', (
    _,
  ) async {
    await NoosphereFlutter.initialize();
    final first = ECPrivateKey(Uint8List(32)..last = 21);
    final second = ECPrivateKey(Uint8List(32)..last = 22);
    final group = GroupConfig(
      id: 'worker-pending-provider',
      participants: {
        Identifier.fromUint16(1): ECCompressedPublicKey.fromPubkey(
          first.pubkey,
        ),
        Identifier.fromUint16(2): ECCompressedPublicKey.fromPubkey(
          second.pubkey,
        ),
      },
    );
    final initializer = _BlockedIdentityInitializer();
    final worker = await NoosphereWorker.start(
      shutdownTimeout: const Duration(milliseconds: 250),
      hostOperationTimeout: const Duration(seconds: 5),
    );
    final starting = worker.startSetup(
      setupId: 'blocked',
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        getIrohSecretKey: initializer.call,
        serverPersistence: MemoryServerPersistence(),
        relay: IrohRelayConfig.disabled(),
      ),
    );
    final failedStart = expectLater(
      starting,
      throwsA(isA<NoosphereWorkerException>()),
    );
    await initializer.started.future.timeout(const Duration(seconds: 15));

    await worker.close().timeout(const Duration(seconds: 3));
    initializer.finish.complete(SecretKey.generate());
    await failedStart;
    await worker.close();

    final replacement = await NoosphereWorker.start();
    await replacement.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}

final class _BlockedIdentityInitializer {
  final started = Completer<void>();
  final finish = Completer<SecretKey>();

  Future<SecretKey> call() {
    if (!started.isCompleted) started.complete();
    return finish.future;
  }
}

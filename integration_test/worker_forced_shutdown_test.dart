import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pending identity provider forces bounded, unsafe shutdown', (
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
    final store = _BlockedIdentityStore();
    final worker = await NoosphereWorker.start(
      shutdownTimeout: const Duration(milliseconds: 250),
      hostOperationTimeout: const Duration(seconds: 5),
    );
    final starting = worker.startSetup(
      setupId: 'blocked',
      identityStorageId: 'blocked-provider',
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        identityStore: store,
        relay: IrohRelayConfig.disabled(),
      ),
    );
    final failedStart = expectLater(
      starting,
      throwsA(isA<NoosphereWorkerException>()),
    );
    await store.readStarted.future.timeout(const Duration(seconds: 15));

    await worker.close().timeout(const Duration(seconds: 3));
    await failedStart;
    await worker.close();
    store.finishRead.complete(null);
    await expectLater(
      NoosphereWorker.start(),
      throwsA(
        isA<NoosphereWorkerException>().having(
          (error) => error.code,
          'code',
          'unsafe_restart',
        ),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

final class _BlockedIdentityStore implements ServerIdentityStore {
  final readStarted = Completer<void>();
  final finishRead = Completer<Uint8List?>();

  @override
  Future<Uint8List?> read() {
    if (!readStarted.isCompleted) readStarted.complete();
    return finishRead.future;
  }

  @override
  Future<void> write(Uint8List secret) async {}
}

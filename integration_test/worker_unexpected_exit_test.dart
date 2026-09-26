import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unexpected native worker exit interrupts pending work', (
    _,
  ) async {
    await NoosphereFlutter.initialize();
    final first = ECPrivateKey(Uint8List(32)..last = 31);
    final second = ECPrivateKey(Uint8List(32)..last = 32);
    final group = GroupConfig(
      id: 'worker-unexpected-exit',
      participants: {
        Identifier.fromUint16(1): ECCompressedPublicKey.fromPubkey(
          first.pubkey,
        ),
        Identifier.fromUint16(2): ECCompressedPublicKey.fromPubkey(
          second.pubkey,
        ),
      },
    );
    final worker = await NoosphereWorker.startNativeForTesting();
    try {
      final snapshot = await worker.startSetup(
        setupId: 'interrupted',
        server: EmbeddedServerOptions(
          serverConfig: ServerConfig(group: group),
          identityStore: MemoryIdentityStore(),
          serverPersistence: MemoryServerPersistence(),
          relay: IrohRelayConfig.disabled(),
        ),
      );
      expect(snapshot.serverRunning, isTrue);

      final interrupted = worker.events
          .where((event) => event is WorkerFailureEvent)
          .cast<WorkerFailureEvent>()
          .first;
      final streamDone = worker.events.drain<void>();
      final pending = worker.debugPendingCommandForTesting();
      final failed = expectLater(
        pending,
        throwsA(
          isA<NoosphereWorkerException>().having(
            (error) => error.code,
            'code',
            anyOf('worker_exited', 'worker_crashed'),
          ),
        ),
      );

      worker.debugKillForTesting();
      await failed.timeout(const Duration(seconds: 5));
      final event = await interrupted.timeout(const Duration(seconds: 5));
      expect(event.setupId, 'interrupted');
      expect(event.interrupted, isTrue);
      expect(event.message, contains('not replayed'));
      await streamDone.timeout(const Duration(seconds: 5));
      expect(worker.isClosed, isTrue);
      await worker.close();
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
    } finally {
      await worker.close();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

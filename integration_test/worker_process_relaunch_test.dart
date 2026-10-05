import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

const _phase = String.fromEnvironment('NOOSPHERE_RELAUNCH_PHASE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'forced exit leaves a reproducible identity for a new process',
    (_) async {
      await NoosphereFlutter.initialize();
      await _publicIdFile.deleteIfPresent();

      final worker = await NoosphereWorker.startNativeForTesting(
        shutdownTimeout: const Duration(milliseconds: 250),
      );
      final snapshot = await worker.startSetup(
        setupId: 'durable',
        server: EmbeddedServerOptions(
          serverConfig: ServerConfig(group: _group()),
          getIrohSecretKey: _deriveIdentity,
          serverPersistence: InMemoryServerPersistence(),
          relay: IrohRelayConfig.disabled(),
        ),
      );
      await _publicIdFile.writeAsString(snapshot.coordinator!.id, flush: true);

      final pending = worker.debugPendingCommandForTesting();
      final failedPending = expectLater(
        pending,
        throwsA(isA<NoosphereWorkerException>()),
      );
      await worker.close().timeout(const Duration(seconds: 3));
      await failedPending;
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
    },
    skip: _phase != 'prepare',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'new process re-derives identity without in-memory sessions',
    (_) async {
      await NoosphereFlutter.initialize();
      expect(await _publicIdFile.exists(), isTrue);
      final expectedId = await _publicIdFile.readAsString();

      final worker = await NoosphereWorker.startNativeForTesting();
      try {
        final snapshot = await worker.startSetup(
          setupId: 'durable',
          server: EmbeddedServerOptions(
            serverConfig: ServerConfig(group: _group()),
            getIrohSecretKey: _deriveIdentity,
            serverPersistence: InMemoryServerPersistence(),
            relay: IrohRelayConfig.disabled(),
          ),
        );
        expect(snapshot.coordinator!.id, expectedId);
        expect(snapshot.dkgs, isEmpty);
        expect(snapshot.signingRequests, isEmpty);
      } finally {
        await worker.close();
        await _publicIdFile.deleteIfPresent();
      }
    },
    skip: _phase != 'recover',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

GroupConfig _group() {
  final first = ECPrivateKey(Uint8List(32)..last = 41);
  final second = ECPrivateKey(Uint8List(32)..last = 42);
  return GroupConfig(
    id: 'worker-process-relaunch',
    participants: {
      Identifier.fromUint16(1): ECCompressedPublicKey.fromPubkey(first.pubkey),
      Identifier.fromUint16(2): ECCompressedPublicKey.fromPubkey(second.pubkey),
    },
  );
}

final _publicIdFile = File(
  '${Directory.systemTemp.path}/noosphere-worker-process-relaunch.id',
);

SecretKey _deriveIdentity() => deriveIrohSecretKeyFromBip39Seed(
  Uint8List.fromList(List<int>.generate(64, (index) => index)),
);

extension on File {
  Future<void> deleteIfPresent() async {
    if (await exists()) await delete();
  }
}

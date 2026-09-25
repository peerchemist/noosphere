import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

const _phase = String.fromEnvironment('NOOSPHERE_RELAUNCH_PHASE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'forced exit leaves durable identity for a new process',
    (_) async {
      await NoosphereFlutter.initialize();
      await _identityFile.deleteIfPresent();
      await _publicIdFile.deleteIfPresent();

      final worker = await NoosphereWorker.startNativeForTesting(
        shutdownTimeout: const Duration(milliseconds: 250),
      );
      final snapshot = await worker.startSetup(
        setupId: 'durable',
        identityStorageId: 'process-relaunch',
        server: EmbeddedServerOptions(
          serverConfig: ServerConfig(group: _group()),
          identityStore: _FileIdentityStore(_identityFile),
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
    'new process recovers durable identity without in-memory sessions',
    (_) async {
      await NoosphereFlutter.initialize();
      expect(await _identityFile.exists(), isTrue);
      expect(await _publicIdFile.exists(), isTrue);
      final expectedId = await _publicIdFile.readAsString();

      final worker = await NoosphereWorker.startNativeForTesting();
      try {
        final snapshot = await worker.startSetup(
          setupId: 'durable',
          identityStorageId: 'process-relaunch',
          server: EmbeddedServerOptions(
            serverConfig: ServerConfig(group: _group()),
            identityStore: _FileIdentityStore(_identityFile),
            relay: IrohRelayConfig.disabled(),
          ),
        );
        expect(snapshot.coordinator!.id, expectedId);
        expect(snapshot.dkgs, isEmpty);
        expect(snapshot.signingRequests, isEmpty);
      } finally {
        await worker.close();
        await _identityFile.deleteIfPresent();
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

final _identityFile = File(
  '${Directory.systemTemp.path}/noosphere-worker-process-relaunch.identity',
);
final _publicIdFile = File(
  '${Directory.systemTemp.path}/noosphere-worker-process-relaunch.id',
);

final class _FileIdentityStore(this.file) implements ServerIdentityStore {
  final File file;

  @override
  Future<Uint8List?> read() async =>
      await file.exists() ? Uint8List.fromList(await file.readAsBytes()) : null;

  @override
  Future<void> write(Uint8List secret) async {
    await file.writeAsBytes(Uint8List.fromList(secret), flush: true);
  }
}

extension on File {
  Future<void> deleteIfPresent() async {
    if (await exists()) await delete();
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'replacement client waits for a timed-out write from the old worker',
    () async {
      final storage = _DelayedStorage();
      final first = await NoosphereWorker.startForTesting(
        clientStorages: {'wallet': storage},
        hostOperationTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(first.close);
      addTearDown(() {
        if (!storage.release.isCompleted) storage.release.complete();
      });
      final requestId = Uint8List(16)..last = 7;
      await expectLater(
        first.debugClientStorageForTesting(
          'wallet',
          rejectRequestId: requestId,
        ),
        throwsA(
          isA<NoosphereWorkerException>().having(
            (error) => error.code,
            'code',
            'host_timeout',
          ),
        ),
      );
      await first.close();
      final replacement = await NoosphereWorker.startForTesting(
        clientStorages: {'wallet': storage},
      );
      addTearDown(replacement.close);
      final loaded = replacement.debugClientStorageForTesting('wallet');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(storage.loads, 0, reason: 'old durable write has not completed');
      storage.release.complete();
      expect(await loaded, [requestId]);
    },
  );
}

final class _DelayedStorage extends InMemoryClientStorage {
  final release = Completer<void>();
  int loads = 0;

  @override
  Future<ClientStorageSnapshot> loadState() {
    loads++;
    return super.loadState();
  }

  @override
  Future<void> addRejectedSigsRequest(
    SignaturesRequestId id,
    FinalExpirable expirable,
  ) async {
    await release.future;
    await super.addRejectedSigsRequest(id, expirable);
  }
}

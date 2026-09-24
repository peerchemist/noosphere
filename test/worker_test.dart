import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('worker performs a ready handshake and closes idempotently', () async {
    final worker = await NoosphereWorker.startForTesting();
    final first = worker.close();
    final second = worker.close();

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(worker.isClosed, isTrue);
    await expectLater(worker.events, emitsDone);
  });

  test('facade validates setup roles before sending a command', () async {
    final worker = await NoosphereWorker.startForTesting();
    try {
      await expectLater(
        worker.startSetup(setupId: 'wallet'),
        throwsArgumentError,
      );
    } finally {
      await worker.close();
    }
  });

  test('worker lifecycle ignores inactive and closes on detached', () async {
    final worker = await NoosphereWorker.startForTesting();
    final observer = NoosphereWorkerLifecycleObserver(worker);

    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(worker.isClosed, isFalse);

    observer.didChangeAppLifecycleState(AppLifecycleState.detached);
    await worker.events.drain<void>();
    expect(worker.isClosed, isTrue);
  });

  test('snapshot DTO defensively copies binary approval data', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final request = WorkerSigningRequest(
      id: bytes,
      proposalBytes: bytes,
      creator: 'participant',
      expiry: DateTime.fromMillisecondsSinceEpoch(1),
      status: 'waiting',
    );
    bytes[0] = 9;

    expect(request.id, orderedEquals([1, 2, 3]));
    expect(request.proposalBytes, orderedEquals([1, 2, 3]));
    final decoded = WorkerSigningRequest.fromMessage(request.toMessage());
    request.id[0] = 8;
    expect(decoded.id, orderedEquals([1, 2, 3]));
  });
}

import 'dart:isolate';
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

  test('identity export rejects an unknown setup', () async {
    final worker = await NoosphereWorker.startForTesting();
    addTearDown(worker.close);

    await expectLater(
      worker.exportIrohServerIdentity('missing'),
      throwsA(isA<StateError>()),
    );
  });

  test('server setup exports its identity defensively', () async {
    final bytes = Uint8List(32)..last = 71;
    final store = _MemoryIdentityStore(bytes);
    final worker = await NoosphereWorker.startForTesting(
      identityStores: {'server-export-test': store},
    );
    addTearDown(worker.close);

    final first = await worker.exportIrohServerIdentity('server-export-test');
    first.last = 99;
    final second = await worker.exportIrohServerIdentity('server-export-test');

    expect(second, orderedEquals(bytes));
  });

  test('identity export rejects a client-only setup', () async {
    final worker = await NoosphereWorker.startForTesting(
      identityStores: {'client-only': null},
    );
    addTearDown(worker.close);

    await expectLater(
      worker.exportIrohServerIdentity('client-only'),
      throwsA(isA<StateError>()),
    );
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

  test('snapshot DTO is sendable and copies binary approval data', () async {
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
    final received = await Isolate.run(() => request);
    request.id[0] = 8;
    expect(received.id, orderedEquals([1, 2, 3]));
  });
}

final class _MemoryIdentityStore(Uint8List initial)
    implements ServerIdentityStore {
  final Uint8List _bytes = Uint8List.fromList(initial);

  @override
  Future<Uint8List?> read() async => Uint8List.fromList(_bytes);

  @override
  Future<void> write(Uint8List secret) async {
    _bytes.setAll(0, secret);
  }
}

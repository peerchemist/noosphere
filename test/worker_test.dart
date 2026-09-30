import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(cl.loadCoinlib);

  test('worker performs a ready handshake and closes idempotently', () async {
    final worker = await NoosphereWorker.startForTesting();
    final first = worker.close();
    final second = worker.close();

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(worker.isClosed, isTrue);
    await expectLater(worker.events, emitsDone);
  });

  test(
    'unexpected exit fails an outstanding command and closes events',
    () async {
      final worker = await NoosphereWorker.startForTesting();
      final pending = worker.debugPendingCommandForTesting();
      final failure = expectLater(
        pending,
        throwsA(
          isA<NoosphereWorkerException>().having(
            (error) => error.code,
            'code',
            anyOf('worker_exited', 'worker_crashed'),
          ),
        ),
      );
      final done = expectLater(worker.events, emitsDone);

      worker.debugKillForTesting();
      await failure.timeout(const Duration(seconds: 2));
      await done.timeout(const Duration(seconds: 2));
      expect(worker.isClosed, isTrue);
      await worker.close();
    },
  );

  test('close has a bounded fallback with a pending command', () async {
    final worker = await NoosphereWorker.startForTesting(
      shutdownTimeout: const Duration(milliseconds: 100),
    );
    final pending = worker.debugPendingCommandForTesting();
    final failure = expectLater(
      pending,
      throwsA(isA<NoosphereWorkerException>()),
    );

    await worker.close().timeout(const Duration(seconds: 2));
    await failure;
    expect(worker.isClosed, isTrue);
    await worker.close();
  });

  test(
    'host provider failures are sanitized and cancellation completes',
    () async {
      final provider = Completer<Object?>();
      final called = Completer<void>();
      final worker = await NoosphereWorker.startForTesting(
        hostOperation: () {
          called.complete();
          return provider.future;
        },
      );
      try {
        final request = worker.debugHostRequestForTesting();
        final failure = expectLater(
          request,
          throwsA(
            isA<NoosphereWorkerException>()
                .having((error) => error.code, 'code', 'host_state')
                .having(
                  (error) => error.message,
                  'message',
                  isNot(contains('sensitive-provider-detail')),
                ),
          ),
        );
        await called.future.timeout(const Duration(seconds: 2));
        provider.completeError(StateError('sensitive-provider-detail'));
        await failure.timeout(const Duration(seconds: 2));
      } finally {
        await worker.close();
      }
    },
  );

  test('pending host request and shutdown complete within the bound', () async {
    final provider = Completer<Object?>();
    final called = Completer<void>();
    final worker = await NoosphereWorker.startForTesting(
      hostOperation: () {
        called.complete();
        return provider.future;
      },
      hostOperationTimeout: const Duration(milliseconds: 100),
      shutdownTimeout: const Duration(milliseconds: 100),
    );
    final request = worker.debugHostRequestForTesting();
    final failure = expectLater(
      request,
      throwsA(isA<NoosphereWorkerException>()),
    );
    await called.future.timeout(const Duration(seconds: 2));
    await worker.close().timeout(const Duration(seconds: 2));
    await failure;
    provider.complete(null);
    expect(worker.isClosed, isTrue);
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

  test(
    'partial startup failure is sanitized and leaves ports reusable',
    () async {
      await expectLater(
        NoosphereWorker.startForTesting(failStartup: true),
        throwsA(
          isA<NoosphereWorkerException>()
              .having((error) => error.code, 'code', 'invalid_state')
              .having(
                (error) => error.message,
                'message',
                isNot(contains('private startup detail')),
              ),
        ),
      );
      final worker = await NoosphereWorker.startForTesting();
      await worker.close();
    },
  );

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
      progress: WorkerSigningProgress(
        threshold: 2,
        contributingParticipants: const ['participant'],
        stage: 'collecting',
      ),
    );
    bytes[0] = 9;

    expect(request.id, orderedEquals([1, 2, 3]));
    expect(request.proposalBytes, orderedEquals([1, 2, 3]));
    final received = await Isolate.run(() => request);
    request.id[0] = 8;
    expect(received.id, orderedEquals([1, 2, 3]));
  });

  test('completed signing results tolerate only expired proposals', () {
    final key = ECPrivateKey(Uint8List(32)..last = 1);
    final active = SignaturesRequestDetails.forMessage(
      text: 'Completed before expiry',
      groupKey: ECCompressedPublicKey.fromPubkey(key.pubkey),
      expiry: Expiry(const Duration(hours: 1)),
    );
    final expired = SignaturesRequestDetails.allowNegativeExpiry(
      requiredSigs: active.requiredSigs,
      metadata: active.metadata,
      expiry: Expiry(const Duration(days: -1)),
    );
    final signature = SchnorrSignature.sign(
      key,
      expired.requiredSigs.single.signDetails.message,
    );
    WorkerSigningResultEvent result({
      Uint8List? proposal,
      Uint8List? completedSignature,
    }) => WorkerSigningResultEvent(
      'setup',
      1,
      requestId: expired.id.toBytes(),
      proposalBytes: proposal ?? expired.toBytes(),
      signatures: [completedSignature ?? signature.data],
      creator: 'participant',
    );

    expect(result().decodeProposal().expiry.isExpired, isTrue);
    expect(result().toSignedMessage().verify(), isTrue);

    final invalidMetadata = Uint8List.fromList(expired.toBytes())..[2] ^= 1;
    expect(
      () => result(proposal: invalidMetadata).decodeProposal(),
      throwsA(isA<InvalidMetaData>()),
    );
    final bytes = expired.toBytes();
    final truncated = Uint8List.sublistView(bytes, 0, bytes.length - 1);
    expect(
      () => result(proposal: truncated).decodeProposal(),
      throwsA(isA<cl.OutOfData>()),
    );
    final invalidSignature = Uint8List.fromList(signature.data)..last ^= 1;
    expect(
      () => result(completedSignature: invalidSignature).toSignedMessage(),
      throwsArgumentError,
    );
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

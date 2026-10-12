import 'dart:typed_data';

import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_client/src/client/cached_storage.dart';
import 'package:noosphere_client/testing.dart';
import 'package:test/test.dart';

import '../test_keys.dart';

class InterruptingStorage extends InMemoryClientStorage {
  final bool afterWrite;

  InterruptingStorage({required this.afterWrite});

  @override
  Future<void> prepareSignaturesOperation(
    PreparedSignaturesOperation operation,
    int capacity,
  ) async {
    if (!afterWrite) throw StateError('interrupted before write');
    await super.prepareSignaturesOperation(operation, capacity);
    throw StateError('interrupted after write');
  }
}

class InterruptingCompletionStorage extends InMemoryClientStorage {
  final bool afterWrite;

  InterruptingCompletionStorage({required this.afterWrite});

  @override
  Future<void> completeSignaturesOperation(SignaturesRequestId id) async {
    if (!afterWrite) throw StateError('interrupted before completion');
    await super.completeSignaturesOperation(id);
    throw StateError('interrupted after completion');
  }
}

final class InterruptingCancellationStorage({required this.afterWrite})
    extends InMemoryClientStorage {
  final bool afterWrite;
  @override
  Future<void> cancelSignaturesRequest(
    SignaturesRequestId id,
    Expiry expiresAt,
  ) async {
    if (afterWrite) await super.cancelSignaturesRequest(id, expiresAt);
    throw StateError('unknown cancellation write outcome');
  }
}

void main() {
  setUpAll(loadFrosty);

  PreparedSignaturesOperation operation() {
    final part1 = SignPart1(
      privateShare: ParticipantKeyInfo.fromHex(keyInfoHex).private.share,
    );
    return PreparedSignaturesOperation(
      id: SignaturesRequestId.fromBytes(Uint8List(16)..last = 1),
      kind: PreparedSignaturesOperationKind.replies,
      payloads: [
        Uint8List.fromList([1, 2, 3]),
      ],
      transcripts: [
        Uint8List.fromList([4, 5, 6]),
      ],
      nextNonces: SignaturesNonces({
        0: part1.nonces,
      }, Expiry(Duration(days: 1))),
    );
  }

  test('prepared signatures operation round trips', () {
    final original = operation();
    final decoded = PreparedSignaturesOperation.fromBytes(original.toBytes());

    expect(decoded.id, original.id);
    expect(decoded.kind, original.kind);
    expect(decoded.payloads, original.payloads);
    expect(decoded.transcripts, original.transcripts);
    expect(
      decoded.nextNonces.map[0]!.toBytes(),
      original.nextNonces.map[0]!.toBytes(),
    );
    expect(
      decoded.expiry.time.millisecondsSinceEpoch,
      original.expiry.time.millisecondsSinceEpoch,
    );
  });

  test('cancellation atomically removes nonces, prepared payloads and decisions; reload blocks replay', () async {
    final store = InMemoryClientStorage();
    final cache = await ClientCachedStorage.load(store);
    final op = operation();
    await cache.prepareSignaturesOperation(operation: op, capacity: 1);
    await cache.addRejectedSigsRequest(op.id, op.expiry);
    final tombstone = CancelledSignaturesRequest(op.id, op.expiry);
    await cache.cancelSignaturesRequest(tombstone);
    final snapshot = await store.loadState();
    expect(snapshot.sigNonces, isEmpty);
    expect(snapshot.preparedOperations, isEmpty);
    expect(snapshot.rejectedRequests, isEmpty);
    expect(snapshot.cancelledRequests[op.id]!.toBytes(), [
      ...op.id.toBytes(),
      ...op.expiry.toBytes(),
    ]);
    final reloaded = await ClientCachedStorage.load(store);
    expect(reloaded.cancelledRequests[op.id], isNotNull);
    await expectLater(
      reloaded.prepareSignaturesOperation(operation: op, capacity: 1),
      throwsStateError,
    );
    await expectLater(
      store.prepareSignaturesOperation(op, 1),
      throwsStateError,
    );
    await expectLater(
      store.addSignaturesNonces(op.id, op.nextNonces, 1),
      throwsStateError,
    );
    await expectLater(
      store.addRejectedSigsRequest(op.id, FinalExpirable(op.expiry)),
      throwsStateError,
    );
    await reloaded.cancelSignaturesRequest(tombstone);
    expect((await store.loadState()).cancelledRequests, hasLength(1));
  });

  for (final afterWrite in [false, true]) {
    test(
      'unknown cancellation write (committed=$afterWrite) blocks the cache until reload',
      () async {
        final store = InterruptingCancellationStorage(afterWrite: afterWrite);
        final cache = await ClientCachedStorage.load(store);
        final op = operation();
        await cache.prepareSignaturesOperation(operation: op, capacity: 1);
        await expectLater(
          cache.cancelSignaturesRequest(
            CancelledSignaturesRequest(op.id, op.expiry),
          ),
          throwsStateError,
        );
        await expectLater(
          cache.prepareSignaturesOperation(operation: op, capacity: 1),
          throwsStateError,
        );
        final snapshot = await store.loadState();
        expect(snapshot.cancelledRequests.containsKey(op.id), afterWrite);
        expect(snapshot.preparedOperations.containsKey(op.id), !afterWrite);
        expect(snapshot.sigNonces.containsKey(op.id), !afterWrite);
        final reloaded = await ClientCachedStorage.load(store);
        expect(reloaded.cancelledRequests.containsKey(op.id), afterWrite);
      },
    );
  }

  test(
    'expired cancellation tombstones are pruned durably on reload',
    () async {
      final store = InMemoryClientStorage();
      final id = operation().id;
      store.cancelledRequests[id] = CancelledSignaturesRequest(
        id,
        Expiry(const Duration(seconds: -1)),
      );
      final cache = await ClientCachedStorage.load(store);
      expect(cache.cancelledRequests.values, isEmpty);
      expect((await store.loadState()).cancelledRequests, isEmpty);
    },
  );

  test('inconsistent provider snapshot fails closed instead of exposing reusable nonces', () async {
    final store = InMemoryClientStorage();
    final op = operation();
    await store.prepareSignaturesOperation(op, 1);
    store.cancelledRequests[op.id] = CancelledSignaturesRequest(
      op.id,
      op.expiry,
    );
    await expectLater(ClientCachedStorage.load(store), throwsStateError);
  });

  test('prepared operation exposes defensive nested byte snapshots', () {
    final original = operation();
    final first = original.payloads;
    final expected = first.first.first;
    first.first[0] ^= 0xff;

    expect(original.payloads.first.first, expected);
    expect(() => original.nextNonces.map.clear(), throwsUnsupportedError);
  });

  test('prepare atomically stores operation and next nonce', () async {
    final store = InMemoryClientStorage();
    final prepared = operation();

    await store.prepareSignaturesOperation(prepared, 1);

    expect(store.preparedSigOperations[prepared.id], same(prepared));
    expect(
      store.sigNonces[prepared.id]!.map[0]!.toBytes(),
      prepared.nextNonces.map[0]!.toBytes(),
    );

    await store.completeSignaturesOperation(prepared.id);
    expect(store.preparedSigOperations, isNot(contains(prepared.id)));
    expect(store.sigNonces, contains(prepared.id));
  });

  test(
    'interruption before prepare blocks the request until storage reload',
    () async {
      final underlying = InterruptingStorage(afterWrite: false);
      final cached = await ClientCachedStorage.load(underlying);
      final prepared = operation();

      await expectLater(
        cached.prepareSignaturesOperation(operation: prepared, capacity: 1),
        throwsStateError,
      );

      expect(cached.preparedSigOperations.containsKey(prepared.id), isTrue);
      expect(cached.sigNonces.containsKey(prepared.id), isFalse);
      expect(underlying.preparedSigOperations, isEmpty);
      expect(underlying.sigNonces, isEmpty);
      final reloaded = await ClientCachedStorage.load(underlying);
      expect(reloaded.preparedSigOperations.containsKey(prepared.id), isFalse);
    },
  );

  test('interruption after durable prepare is recovered on reload', () async {
    final underlying = InterruptingStorage(afterWrite: true);
    final cached = await ClientCachedStorage.load(underlying);
    final prepared = operation();

    await expectLater(
      cached.prepareSignaturesOperation(operation: prepared, capacity: 1),
      throwsStateError,
    );

    expect(cached.preparedSigOperations.containsKey(prepared.id), isTrue);
    expect(cached.sigNonces.containsKey(prepared.id), isFalse);

    final reloaded = await ClientCachedStorage.load(underlying);
    expect(reloaded.preparedSigOperations.containsKey(prepared.id), isTrue);
    expect(reloaded.sigNonces.containsKey(prepared.id), isTrue);
  });

  test('interruption before completion keeps operation prepared', () async {
    final underlying = InterruptingCompletionStorage(afterWrite: false);
    final prepared = operation();
    await underlying.prepareSignaturesOperation(prepared, 1);
    final cached = await ClientCachedStorage.load(underlying);

    await expectLater(
      cached.completeSignaturesOperation(prepared.id),
      throwsStateError,
    );

    expect(cached.preparedSigOperations.containsKey(prepared.id), isTrue);
    final reloaded = await ClientCachedStorage.load(underlying);
    expect(reloaded.preparedSigOperations.containsKey(prepared.id), isTrue);
  });

  test('interruption after completion is conservative until reload', () async {
    final underlying = InterruptingCompletionStorage(afterWrite: true);
    final prepared = operation();
    await underlying.prepareSignaturesOperation(prepared, 1);
    final cached = await ClientCachedStorage.load(underlying);

    await expectLater(
      cached.completeSignaturesOperation(prepared.id),
      throwsStateError,
    );

    expect(cached.preparedSigOperations.containsKey(prepared.id), isTrue);
    final reloaded = await ClientCachedStorage.load(underlying);
    expect(reloaded.preparedSigOperations.containsKey(prepared.id), isFalse);
    expect(reloaded.sigNonces.containsKey(prepared.id), isTrue);
  });
}

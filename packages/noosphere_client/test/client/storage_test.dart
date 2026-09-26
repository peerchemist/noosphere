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

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

void main() {
  test('stored identity is reused by concurrent callers', () async {
    final bytes = Uint8List(32)..last = 7;
    final store = _MemoryIdentityStore(bytes);

    final results = await Future.wait([
      loadOrCreateServerIdentity(store),
      loadOrCreateServerIdentity(store),
    ]);

    expect(results[0].toBytes(), orderedEquals(bytes));
    expect(results[1].toBytes(), orderedEquals(bytes));
    expect(store.reads, 1);
    expect(store.writes, 0);
  });

  test('malformed stored identity is rejected before construction', () async {
    final store = _MemoryIdentityStore(Uint8List(31));

    await expectLater(
      loadOrCreateServerIdentity(store),
      throwsA(isA<FormatException>()),
    );
    expect(store.writes, 0);
  });

  test('exports a stored identity', () async {
    final bytes = Uint8List(32)..last = 11;
    final store = _MemoryIdentityStore(bytes);

    final exported = await exportStoredIrohServerIdentity(store);

    expect(exported, orderedEquals(bytes));
  });

  test('export returns a defensive copy of a loaded identity', () async {
    final bytes = Uint8List(32)..last = 12;
    final store = _MemoryIdentityStore(bytes);
    await loadOrCreateServerIdentity(store);

    final first = await exportStoredIrohServerIdentity(store);
    first.last = 99;
    final second = await exportStoredIrohServerIdentity(store);

    expect(second, orderedEquals(bytes));
    expect(await store.read(), orderedEquals(bytes));
  });

  test('export rejects a missing identity', () async {
    final store = _MemoryIdentityStore(null);

    await expectLater(
      exportStoredIrohServerIdentity(store),
      throwsA(isA<StateError>()),
    );
  });

  test('export rejects an identity with the wrong length', () async {
    final store = _MemoryIdentityStore(Uint8List(33));

    await expectLater(
      exportStoredIrohServerIdentity(store),
      throwsA(isA<FormatException>()),
    );
  });

  test('restores into an empty store and copies the input', () async {
    final bytes = Uint8List(32)..last = 21;
    final expected = Uint8List.fromList(bytes);
    final store = _MemoryIdentityStore(null);

    final restoring = restoreStoredIrohServerIdentity(store, bytes);
    bytes.last = 99;
    await restoring;

    expect(await store.read(), orderedEquals(expected));
    expect(store.writes, 1);
  });

  test('restore rejects replacing a different identity by default', () async {
    final stored = Uint8List(32)..last = 31;
    final replacement = Uint8List(32)..last = 32;
    final store = _MemoryIdentityStore(stored);

    await expectLater(
      restoreStoredIrohServerIdentity(store, replacement),
      throwsA(isA<StateError>()),
    );

    expect(await store.read(), orderedEquals(stored));
    expect(store.writes, 0);
  });

  test('rejected restore does not poison export or deliberate retry', () async {
    final original = Uint8List(32)..last = 71;
    final replacement = Uint8List(32)..last = 72;
    final store = _MemoryIdentityStore(original);
    await expectLater(
      restoreStoredIrohServerIdentity(store, replacement),
      throwsStateError,
    );
    expect(await exportStoredIrohServerIdentity(store), original);
    await restoreStoredIrohServerIdentity(store, replacement, overwrite: true);
    expect((await loadOrCreateServerIdentity(store)).toBytes(), replacement);
  });

  test('load reconciles after a failed restore write that committed', () async {
    final replacement = Uint8List(32)..last = 73;
    final store = _FailingWriteStore();
    await expectLater(
      restoreStoredIrohServerIdentity(store, replacement),
      throwsStateError,
    );
    expect(await exportStoredIrohServerIdentity(store), replacement);
    expect((await loadOrCreateServerIdentity(store)).toBytes(), replacement);
    expect(store.writes, 1);
  });

  test(
    'load can retry a failed persistence operation without changing key',
    () async {
      final store = _FailingWriteStore();
      await expectLater(loadOrCreateServerIdentity(store), throwsStateError);
      final committed = await store.read();
      expect((await loadOrCreateServerIdentity(store)).toBytes(), committed);
      expect(store.writes, 1);
      expect(
        () => restoreStoredIrohServerIdentity(store, Uint8List(32)),
        throwsStateError,
      );
    },
  );

  test('queued restore recovers after a rejected predecessor', () async {
    final original = Uint8List(32)..last = 74;
    final replacement = Uint8List(32)..last = 75;
    final store = _MemoryIdentityStore(original);
    final rejected = expectLater(
      restoreStoredIrohServerIdentity(store, replacement),
      throwsStateError,
    );
    final restoring = restoreStoredIrohServerIdentity(
      store,
      replacement,
      overwrite: true,
    );
    final loading = loadOrCreateServerIdentity(store);
    await rejected;
    await restoring;
    expect((await loading).toBytes(), replacement);
  });

  test('restore replaces a different identity with overwrite', () async {
    final replacement = Uint8List(32)..last = 42;
    final store = _MemoryIdentityStore(Uint8List(32)..last = 41);

    await restoreStoredIrohServerIdentity(store, replacement, overwrite: true);

    expect(await store.read(), orderedEquals(replacement));
    expect(store.writes, 1);
  });

  test('restoring the same identity is idempotent', () async {
    final bytes = Uint8List(32)..last = 51;
    final store = _MemoryIdentityStore(bytes);

    await restoreStoredIrohServerIdentity(store, bytes);
    await restoreStoredIrohServerIdentity(store, bytes);

    expect(await store.read(), orderedEquals(bytes));
    expect(store.writes, 0);
  });

  test('restore rejects a backup with the wrong length', () {
    final store = _MemoryIdentityStore(null);

    expect(
      () => restoreStoredIrohServerIdentity(store, Uint8List(31)),
      throwsA(isA<FormatException>()),
    );
  });

  test('restore is rejected after the identity has been loaded', () async {
    final bytes = Uint8List(32)..last = 61;
    final store = _MemoryIdentityStore(bytes);
    await loadOrCreateServerIdentity(store);

    expect(
      () => restoreStoredIrohServerIdentity(store, bytes),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'parallel start waits for restore instead of generating a key',
    () async {
      final bytes = Uint8List(32)..last = 81;
      final readBarrier = Completer<void>();
      final store = _BlockingIdentityStore(readBarrier.future);

      final restoring = restoreStoredIrohServerIdentity(store, bytes);
      final loading = loadOrCreateServerIdentity(store);
      readBarrier.complete();

      await restoring;
      expect((await loading).toBytes(), orderedEquals(bytes));
      expect(store.writes, 1);
    },
  );
}

final class _MemoryIdentityStore(Uint8List? initial)
    implements ServerIdentityStore {
  Uint8List? _bytes = initial == null ? null : Uint8List.fromList(initial);
  int reads = 0;
  int writes = 0;

  @override
  Future<Uint8List?> read() async {
    reads++;
    return _bytes == null ? null : Uint8List.fromList(_bytes!);
  }

  @override
  Future<void> write(Uint8List secret) async {
    writes++;
    _bytes = Uint8List.fromList(secret);
  }
}

final class _BlockingIdentityStore(this._readBarrier)
    implements ServerIdentityStore {
  final Future<void> _readBarrier;
  Uint8List? _bytes;
  int writes = 0;

  @override
  Future<Uint8List?> read() async {
    await _readBarrier;
    return _bytes == null ? null : Uint8List.fromList(_bytes!);
  }

  @override
  Future<void> write(Uint8List secret) async {
    writes++;
    _bytes = Uint8List.fromList(secret);
  }
}

final class _FailingWriteStore implements ServerIdentityStore {
  Uint8List? bytes;
  int writes = 0;
  @override
  Future<Uint8List?> read() async =>
      bytes == null ? null : Uint8List.fromList(bytes!);
  @override
  Future<void> write(Uint8List secret) async {
    bytes = Uint8List.fromList(secret);
    writes++;
    throw StateError('Commit succeeded but acknowledgement failed');
  }
}

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

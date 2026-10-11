import 'dart:typed_data';

import 'package:noosphere/public_feed.dart';
import 'package:noosphere/wire.dart' as wire;
import 'package:test/test.dart';

void main() {
  test('canonical v1 empty page uses tag order and omits proto3 defaults', () {
    final page = PublicFeedPage(
      feedId: PublicFeedId.fromBytes(Uint8List(32)),
      entries: [],
      oldestAvailableCursor: 1,
      latestCursor: 0,
      nextCursor: 0,
      hasMore: false,
      historyGap: false,
      afterCursor: 0,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
    );
    // tag 1 version 1; tag 2 32 zero ID bytes; tag 4 oldest 1;
    // tag 9 generation 1. No zero cursor or false boolean fields.
    final golden = [
      0x08,
      0x01,
      0x12,
      0x20,
      ...Uint8List(32),
      0x20,
      0x01,
      0x48,
      0x01,
    ];
    expect(page.toBytes(), golden);
    expect(PublicFeedPage.fromBytes(golden).nextCursor, 0);
    expect(
      () => PublicFeedPage.fromBytes([...golden, 0x38, 0x00]),
      throwsFormatException,
    );
    expect(
      () => PublicFeedPage.fromBytes([...golden, 0x58, 0x01]),
      throwsFormatException,
    );
    final wrongVersion = wire.PublicFeedPage.fromBuffer(golden)
      ..schemaVersion = 2;
    expect(
      () => PublicFeedPage.fromBytes(wrongVersion.writeToBuffer()),
      throwsFormatException,
    );
  });

  test('feed IDs require exactly 256 bits and page entries are immutable', () {
    expect(PublicFeedId.generate().toBytes(), hasLength(32));
    expect(() => PublicFeedId('a' * 63), throwsFormatException);
    expect(() => PublicFeedId('A' * 64), throwsFormatException);
    expect(
      () => PublicFeedId.fromBytes([256, ...Uint8List(31)]),
      throwsFormatException,
    );
    final entries = <PublicFeedEntry>[];
    final page = PublicFeedPage(
      feedId: PublicFeedId.generate(),
      entries: entries,
      oldestAvailableCursor: 1,
      latestCursor: 0,
      nextCursor: 0,
      hasMore: false,
      historyGap: false,
      generatedAt: DateTime.now(),
      afterCursor: 0,
    );
    expect(() => page.entries.clear(), throwsUnsupportedError);
  });
}

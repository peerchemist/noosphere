import 'dart:typed_data';

import 'package:noosphere_protocol/public_feed.dart';
import 'package:noosphere_protocol/wire.dart' as wire;
import 'package:test/test.dart';

void main() {
  test('deterministic CBOR v1 empty page has fixed bytes', () {
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
    // All required fields are present, including zero and false values.
    final golden = [
      0xaa,
      0x01,
      0x01,
      0x02,
      0x58,
      0x20,
      ...Uint8List(32),
      0x03,
      0x80,
      0x04,
      0x01,
      0x05,
      0x00,
      0x06,
      0x00,
      0x07,
      0xf4,
      0x08,
      0xf4,
      0x09,
      0x01,
      0x0a,
      0x00,
    ];
    expect(page.toBytes(), golden);
    expect(publicFeedCheckpointBytes(golden), [
      0x6e,
      0x6f,
      0x6f,
      0x73,
      0x70,
      0x68,
      0x65,
      0x72,
      0x65,
      0x2f,
      0x70,
      0x75,
      0x62,
      0x6c,
      0x69,
      0x63,
      0x2d,
      0x66,
      0x65,
      0x65,
      0x64,
      0x2f,
      0x63,
      0x68,
      0x65,
      0x63,
      0x6b,
      0x70,
      0x6f,
      0x69,
      0x6e,
      0x74,
      0x2f,
      0x63,
      0x62,
      0x6f,
      0x72,
      0x2f,
      0x76,
      0x31,
      0x00,
      ...golden,
    ]);
    expect(PublicFeedPage.fromBytes(golden).nextCursor, 0);
    expect(
      () => PublicFeedPage.fromBytes([...golden, 0x00]),
      throwsFormatException,
    );
    expect(
      () => PublicFeedPage.fromBytes([0xaa, 0x18, 0x01, ...golden.skip(2)]),
      throwsFormatException,
    );
    final decoded = wire.PublicFeedPage.fromBuffer(golden);
    final wrongVersion = wire.PublicFeedPage(
      schemaVersion: 2,
      feedId: decoded.feedId,
      entries: decoded.entries,
      oldestAvailableCursor: decoded.oldestAvailableCursor,
      latestCursor: decoded.latestCursor,
      nextCursor: decoded.nextCursor,
      hasMore: decoded.hasMore,
      historyGap: decoded.historyGap,
      generatedAtMs: decoded.generatedAtMs,
      afterCursor: decoded.afterCursor,
    );
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

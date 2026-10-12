import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';

import 'generated/noosphere.pb.dart' as wire;

const publicFeedSchemaVersion = 1;
const publicFeedMaxPageEntries = 100;
const publicFeedMaxResponseBytes = 64 * 1024;
const publicFeedMaxCursor = 0x7ffffffffffffffe;

/// An opaque, randomly generated 256-bit identifier; never a group fingerprint.
final class PublicFeedId(final String hex) {
  this {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
      throw const FormatException('Expected a lowercase 256-bit feed ID');
    }
  }

  factory PublicFeedId.generate() {
    final random = Random.secure();
    return PublicFeedId.fromBytes(
      List.generate(32, (_) => random.nextInt(256)),
    );
  }

  factory PublicFeedId.fromBytes(List<int> bytes) {
    if (bytes.length != 32 || bytes.any((v) => v < 0 || v > 255)) {
      throw const FormatException('Expected a 256-bit feed ID');
    }
    return PublicFeedId(
      bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  Uint8List toBytes() => Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);

  @override
  bool operator ==(Object other) => other is PublicFeedId && hex == other.hex;
  @override
  int get hashCode => hex.hashCode;
  @override
  String toString() => hex;
}

enum PublicFeedCategory { dkg, signing }

enum PublicFeedLifecycle {
  requested,
  progress,
  completed,
  rejected,
  cancelled,
  expired,
  failed,
}

final class PublicFeedEntry({
  required final int cursor,

  /// Random, stable within one accepted operation; unrelated to its request ID.
  required final PublicFeedId eventId,
  required final PublicFeedCategory category,
  required final PublicFeedLifecycle state,
  required final DateTime observedAt,
  final DateTime? expiresAt,
});

final class PublicFeedPage({
  final int schemaVersion = publicFeedSchemaVersion,
  required final PublicFeedId feedId,
  required Iterable<PublicFeedEntry> entries,
  required final int oldestAvailableCursor,
  required final int latestCursor,
  required final int nextCursor,
  required final bool hasMore,
  required final bool historyGap,
  required final DateTime generatedAt,
  required final int afterCursor,
}) {
  final List<PublicFeedEntry> entries = List.unmodifiable(entries);

  Uint8List toBytes() => wire.PublicFeedPage(
    schemaVersion: schemaVersion,
    feedId: feedId.toBytes(),
    entries: entries.map(
      (e) => wire.PublicFeedEntry(
        cursor: Int64(e.cursor),
        eventId: e.eventId.toBytes(),
        category: e.category.name,
        state: e.state.name,
        observedAtMs: e.observedAt.millisecondsSinceEpoch == 0
            ? null
            : Int64(e.observedAt.millisecondsSinceEpoch),
        expiresAtMs: e.expiresAt == null
            ? null
            : Int64(e.expiresAt!.millisecondsSinceEpoch),
      ),
    ),
    oldestAvailableCursor: Int64(oldestAvailableCursor),
    latestCursor: latestCursor == 0 ? null : Int64(latestCursor),
    nextCursor: nextCursor == 0 ? null : Int64(nextCursor),
    hasMore: hasMore ? true : null,
    historyGap: historyGap ? true : null,
    generatedAtMs: generatedAt.millisecondsSinceEpoch == 0
        ? null
        : Int64(generatedAt.millisecondsSinceEpoch),
    afterCursor: afterCursor == 0 ? null : Int64(afterCursor),
  ).writeToBuffer();

  factory PublicFeedPage.fromBytes(List<int> bytes) {
    if (bytes.length > publicFeedMaxResponseBytes) {
      throw const FormatException('Public feed page too large');
    }
    final p = wire.PublicFeedPage.fromBuffer(bytes);
    int cursor(Int64 v) {
      if (v < Int64.ZERO || v > Int64(publicFeedMaxCursor + 1)) {
        throw const FormatException('Invalid public feed cursor');
      }
      return v.toInt();
    }

    DateTime time(Int64 v) =>
        DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
    final page = PublicFeedPage(
      schemaVersion: p.schemaVersion,
      feedId: PublicFeedId.fromBytes(p.feedId),
      entries: p.entries.map(
        (e) => PublicFeedEntry(
          cursor: cursor(e.cursor),
          eventId: PublicFeedId.fromBytes(e.eventId),
          category: PublicFeedCategory.values.byName(e.category),
          state: PublicFeedLifecycle.values.byName(e.state),
          observedAt: time(e.observedAtMs),
          expiresAt: e.hasExpiresAtMs() ? time(e.expiresAtMs) : null,
        ),
      ),
      oldestAvailableCursor: cursor(p.oldestAvailableCursor),
      latestCursor: cursor(p.latestCursor),
      nextCursor: cursor(p.nextCursor),
      hasMore: p.hasMore,
      historyGap: p.historyGap,
      generatedAt: time(p.generatedAtMs),
      afterCursor: cursor(p.afterCursor),
    );
    final canonical = page.toBytes();
    if (page.schemaVersion != publicFeedSchemaVersion ||
        page.entries.length > publicFeedMaxPageEntries ||
        !const ListEquality<int>().equals(bytes, canonical)) {
      throw const FormatException(
        'Noncanonical or unsupported public feed page',
      );
    }
    var previous = page.afterCursor;
    for (final e in page.entries) {
      if (e.cursor <= previous ||
          e.cursor < page.oldestAvailableCursor ||
          e.cursor > page.latestCursor) {
        throw const FormatException('Invalid public feed entry order');
      }
      previous = e.cursor;
    }
    if (page.oldestAvailableCursor < 1 ||
        page.oldestAvailableCursor > page.latestCursor + 1 ||
        page.nextCursor !=
            (page.entries.isEmpty
                ? max(page.afterCursor, page.latestCursor)
                : previous) ||
        page.hasMore != (page.nextCursor < page.latestCursor) ||
        page.historyGap !=
            (page.afterCursor < page.oldestAvailableCursor - 1)) {
      throw const FormatException('Invalid public feed pagination');
    }
    return page;
  }
}

/// Domain separation for the standard Ed25519 application signature.
/// Both live clients and offline verifiers must sign/verify these exact bytes.
Uint8List publicFeedCheckpointBytes(List<int> canonicalPage) =>
    Uint8List.fromList([
      ...utf8.encode('noosphere/public-feed/checkpoint/v1\u0000'),
      ...canonicalPage,
    ]);

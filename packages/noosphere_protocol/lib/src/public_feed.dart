import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:noosphere_protocol/message_limits.dart';

import 'wire/messages.dart' as wire;

const publicFeedSchemaVersion = 1;
const publicFeedMaxPageEntries = 100;
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
    entries: entries
        .map(
          (e) => wire.PublicFeedEntry(
            cursor: e.cursor,
            eventId: e.eventId.toBytes(),
            category: switch (e.category) {
              PublicFeedCategory.dkg => 0,
              PublicFeedCategory.signing => 1,
            },
            state: switch (e.state) {
              PublicFeedLifecycle.requested => 0,
              PublicFeedLifecycle.progress => 1,
              PublicFeedLifecycle.completed => 2,
              PublicFeedLifecycle.rejected => 3,
              PublicFeedLifecycle.cancelled => 4,
              PublicFeedLifecycle.expired => 5,
              PublicFeedLifecycle.failed => 6,
            },
            observedAtMs: e.observedAt.millisecondsSinceEpoch,
            expiresAtMs: e.expiresAt?.millisecondsSinceEpoch,
          ),
        )
        .toList(),
    oldestAvailableCursor: oldestAvailableCursor,
    latestCursor: latestCursor,
    nextCursor: nextCursor,
    hasMore: hasMore,
    historyGap: historyGap,
    generatedAtMs: generatedAt.millisecondsSinceEpoch,
    afterCursor: afterCursor,
  ).writeToBuffer();

  factory PublicFeedPage.fromBytes(List<int> bytes) {
    if (bytes.length > publicFeedMaxResponseBytes) {
      throw const FormatException('Public feed page too large');
    }
    final p = wire.PublicFeedPage.fromBuffer(bytes);
    int cursor(int v) {
      if (v < 0 || v > publicFeedMaxCursor + 1) {
        throw const FormatException('Invalid public feed cursor');
      }
      return v;
    }

    DateTime time(int v) => DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    final page = PublicFeedPage(
      schemaVersion: p.schemaVersion,
      feedId: PublicFeedId.fromBytes(p.feedId),
      entries: p.entries.map(
        (e) => PublicFeedEntry(
          cursor: cursor(e.cursor),
          eventId: PublicFeedId.fromBytes(e.eventId),
          category: switch (e.category) {
            0 => PublicFeedCategory.dkg,
            1 => PublicFeedCategory.signing,
            _ => throw const FormatException('Invalid public feed category'),
          },
          state: switch (e.state) {
            0 => PublicFeedLifecycle.requested,
            1 => PublicFeedLifecycle.progress,
            2 => PublicFeedLifecycle.completed,
            3 => PublicFeedLifecycle.rejected,
            4 => PublicFeedLifecycle.cancelled,
            5 => PublicFeedLifecycle.expired,
            6 => PublicFeedLifecycle.failed,
            _ => throw const FormatException('Invalid public feed lifecycle'),
          },
          observedAt: time(e.observedAtMs),
          expiresAt: e.expiresAtMs == null ? null : time(e.expiresAtMs!),
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
      ...utf8.encode('noosphere/public-feed/checkpoint/cbor/v1\u0000'),
      ...canonicalPage,
    ]);

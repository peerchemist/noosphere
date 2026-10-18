import 'dart:convert';

import 'package:noosphere_protocol/public_feed.dart';

import '../../config/public_feed.dart';

/// Part of the protocol snapshot, never an independently committed store.
final class PublicFeedJournal(PublicFeedConfig config) {
  final PublicFeedId feedId = config.feedId;
  int maxEntries = config.maxEntries;
  Duration maxAge = config.maxAge;
  bool enabled = true;
  int nextCursor = 1;
  final List<PublicFeedEntry> entries = [];
  // Private snapshot data. Source keys never appear in a public response.
  final Map<String, PublicFeedEntry> active = {};

  void requested(String source, PublicFeedCategory category, DateTime expiry) {
    if (!enabled || active.containsKey(source)) return;
    final entry = _append(
      PublicFeedId.generate(),
      category,
      PublicFeedLifecycle.requested,
      expiry,
    );
    active[source] = entry;
  }

  void finish(String source, PublicFeedLifecycle state) {
    final start = active.remove(source);
    if (start == null || !enabled) return;
    _append(start.eventId, start.category, state, start.expiresAt);
  }

  PublicFeedEntry _append(
    PublicFeedId eventId,
    PublicFeedCategory category,
    PublicFeedLifecycle state,
    DateTime? expiry,
  ) {
    if (nextCursor > publicFeedMaxCursor) {
      throw StateError('Public feed cursor exhausted');
    }
    final entry = PublicFeedEntry(
      cursor: nextCursor++,
      eventId: eventId,
      category: category,
      state: state,
      observedAt: DateTime.now().toUtc(),
      expiresAt: expiry,
    );
    entries.add(entry);
    prune();
    return entry;
  }

  bool prune() {
    final cutoff = DateTime.now().subtract(maxAge);
    var count = 0;
    while (count < entries.length &&
        (entries.length - count > maxEntries ||
            entries[count].observedAt.isBefore(cutoff))) {
      count++;
    }
    if (count == 0) return false;
    entries.removeRange(0, count);
    return true;
  }

  bool expire() {
    final now = DateTime.now();
    final expired = active.entries
        .where((e) => e.value.expiresAt!.isBefore(now))
        .map((e) => e.key)
        .toList();
    for (final key in expired) {
      finish(key, PublicFeedLifecycle.expired);
    }
    return expired.isNotEmpty;
  }

  Map<String, Object?> toJson() {
    String encodeEntry(PublicFeedEntry e) => base64Encode(_single(e).toBytes());
    return {
      'feedId': feedId.hex,
      'maxEntries': maxEntries,
      'maxAgeUs': maxAge.inMicroseconds,
      'nextCursor': nextCursor,
      'enabled': enabled,
      'entries': entries.map(encodeEntry).toList(),
      'active': active.map((key, value) => MapEntry(key, encodeEntry(value))),
    };
  }

  // Use the same canonical schema for durable metadata and wire metadata.
  PublicFeedPage _single(PublicFeedEntry e) => PublicFeedPage(
    feedId: feedId,
    entries: [e],
    oldestAvailableCursor: e.cursor,
    latestCursor: e.cursor,
    nextCursor: e.cursor,
    hasMore: false,
    historyGap: false,
    generatedAt: e.observedAt,
    afterCursor: e.cursor - 1,
  );

  factory PublicFeedJournal.fromJson(Map<Object?, Object?> raw) {
    final journal = PublicFeedJournal(
      PublicFeedConfig(
        feedId: PublicFeedId(raw['feedId'] as String),
        maxEntries: raw['maxEntries'] as int,
        maxAge: Duration(microseconds: raw['maxAgeUs'] as int),
      ),
    );
    journal.enabled = raw['enabled'] as bool;
    journal.nextCursor = raw['nextCursor'] as int;
    if (journal.nextCursor < 1 ||
        journal.nextCursor > publicFeedMaxCursor + 1) {
      throw const FormatException('Invalid public feed next cursor');
    }
    PublicFeedEntry decodeEntry(Object? encoded) {
      final page = PublicFeedPage.fromBytes(base64Decode(encoded as String));
      if (page.feedId != journal.feedId ||
          page.entries.length != 1 ||
          page.entries.single.cursor >= journal.nextCursor) {
        throw const FormatException('Invalid public feed snapshot entry');
      }
      return page.entries.single;
    }

    journal.entries.addAll((raw['entries'] as List).map(decodeEntry));
    var previous = 0;
    for (final entry in journal.entries) {
      if (previous != 0 && entry.cursor != previous + 1) {
        throw const FormatException('Unordered journal');
      }
      previous = entry.cursor;
    }
    if (journal.entries.isNotEmpty &&
        journal.entries.last.cursor != journal.nextCursor - 1) {
      throw const FormatException('Invalid journal high-water mark');
    }
    if (journal.entries.length > journal.maxEntries) {
      throw const FormatException('Oversized public feed journal');
    }
    for (final item in (raw['active'] as Map).entries) {
      final entry = decodeEntry(item.value);
      if (entry.state != PublicFeedLifecycle.requested ||
          entry.expiresAt == null) {
        throw const FormatException('Invalid active public operation');
      }
      journal.active[item.key as String] = entry;
    }
    return journal;
  }
}

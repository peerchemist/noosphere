import 'package:noosphere/public_feed.dart';

/// Explicit opt-in for one coordinator group. Supply a random ID once and
/// retain it in host configuration; the journal also persists it atomically.
final class PublicFeedConfig({
  required final PublicFeedId feedId,
  final int maxEntries = 10000,
  final Duration maxAge = const Duration(days: 30),
}) {
  this {
    if (maxEntries < 1 || maxEntries > 100000) {
      throw RangeError.range(maxEntries, 1, 100000, 'maxEntries');
    }
    if (maxAge <= Duration.zero) throw ArgumentError.value(maxAge, 'maxAge');
  }
}

import 'dart:collection';

import 'package:noosphere/api/types/expirable.dart';

/// Maps [K] to the [Expirable] [V] objects. These objects are removed when
/// expired. [K] should have [Object.operator==] and [Object.hashCode]
/// implemented.
class ExpirableMap<K, V extends Expirable> {
  final HashMap<K, V> _map;
  final void Function(K, V) _onExpired;
  final bool expireOnRead;

  ExpirableMap({void Function(K, V)? onExpired, bool expireOnRead = true})
    : this.of(HashMap(), onExpired: onExpired, expireOnRead: expireOnRead);

  ExpirableMap.of(
    Map<K, V> map, {
    void Function(K, V)? onExpired,
    this.expireOnRead = true,
  }) : _map = HashMap.of(map),
       _onExpired = onExpired ?? ((_, _) {});

  void _removeExpired() {
    // Get entries to be expired
    final toExpire = _map.entries
        .where((e) => e.value.expiry.isExpired)
        .toList();

    for (final entry in toExpire) {
      _map.remove(entry.key);
      _onExpired(entry.key, entry.value);
    }
  }

  /// Adds the object to the map
  void operator []=(K key, V value) {
    _map[key] = value;
    if (expireOnRead) _removeExpired();
  }

  /// Obtain the object if it is not expired.
  V? operator [](K key) {
    if (expireOnRead) _removeExpired();
    final value = _map[key];
    return value == null || value.expiry.isExpired ? null : value;
  }

  bool containsKey(K key) {
    if (expireOnRead) _removeExpired();
    final value = _map[key];
    return value != null && !value.expiry.isExpired;
  }

  /// Remove the entry at [key] and return the removed value. Returns null if
  /// the key was not in the map. Does not call [this.onExpired].
  V? remove(K key) => _map.remove(key);

  void removeWhere(bool Function(K key, V value) test) =>
      _map.removeWhere(test);

  Iterable<V> get values {
    if (expireOnRead) _removeExpired();
    return expireOnRead
        ? _map.values
        : _map.values.where((value) => !value.expiry.isExpired);
  }

  /// Explicitly removes expired entries. Persistent owners use this before a
  /// durable transition so ordinary reads never mutate authoritative state.
  List<MapEntry<K, V>> removeExpired() {
    final expired = _map.entries
        .where((entry) => entry.value.expiry.isExpired)
        .toList();
    for (final entry in expired) {
      _map.remove(entry.key);
      _onExpired(entry.key, entry.value);
    }
    return expired;
  }

  void clear() => _map.clear();
}

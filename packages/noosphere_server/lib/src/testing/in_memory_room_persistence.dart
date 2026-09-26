import 'dart:typed_data';

import '../room/persistence.dart';

/// Non-durable room storage for tests and examples only.
final class InMemoryRoomPersistence implements RoomPersistence {
  final Map<String, Uint8List> _records = {};

  @override
  Future<Map<String, Uint8List>> loadAll() async => {
    for (final entry in _records.entries)
      entry.key: Uint8List.fromList(entry.value),
  };

  @override
  Future<void> write(String roomId, Uint8List state) async {
    _records[roomId] = Uint8List.fromList(state);
  }
}

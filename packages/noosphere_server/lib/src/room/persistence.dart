import 'dart:typed_data';

/// Host-owned durable storage for opaque room-state records.
///
/// Implementations must make [write] durable atomically: after it completes a
/// restart must observe either the old record or all of the new record.
abstract interface class RoomPersistence {
  Future<Map<String, Uint8List>> loadAll();

  Future<void> write(String roomId, Uint8List state);
}

import 'dart:typed_data';

import '../server/persistence.dart';

final class InMemoryServerPersistence implements ServerPersistence {
  final Map<String, Uint8List> _records = {};

  @override
  Future<ServerStateSnapshot?> load(String groupId) async {
    final bytes = _records[groupId];
    return bytes == null ? null : ServerStateSnapshot.fromBytes(bytes);
  }

  @override
  Future<void> write(String groupId, ServerStateSnapshot state) async {
    _records[groupId] = state.toBytes();
  }
}

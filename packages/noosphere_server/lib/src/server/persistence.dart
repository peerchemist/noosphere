import 'dart:convert';
import 'dart:typed_data';

/// Validated, versioned durable state for one server group.
///
/// The payload is intentionally opaque to hosts: noosphere owns its schema and
/// validation, while the host owns atomic and durable storage of the record.
final class ServerStateSnapshot {
  static const currentVersion = 3;

  final Uint8List _bytes;

  ServerStateSnapshot._(this._bytes);

  factory ServerStateSnapshot.fromBytes(Uint8List bytes) {
    final copy = Uint8List.fromList(bytes);
    final decoded = jsonDecode(utf8.decode(copy));
    if (decoded is! Map<String, dynamic> ||
        ![1, 2, currentVersion].contains(decoded['version']) ||
        decoded['dkg'] is! List ||
        (decoded['dkg'] as List).any(
          (record) =>
              record is! Map ||
              !(decoded['version'] == currentVersion
                      ? ['resumable']
                      : decoded['version'] == 1
                      ? ['active', 'interrupted']
                      : ['resumable', 'interrupted'])
                  .contains(record['status']),
        ) ||
        decoded['signing'] is! List ||
        decoded['completed'] is! List ||
        decoded['shares'] is! List ||
        decoded['cancelled'] is! List ||
        decoded['terminalSigning'] is! List ||
        (decoded['version'] == currentVersion &&
            decoded['terminalDkg'] is! List)) {
      throw const FormatException('Invalid server state snapshot.');
    }
    return ServerStateSnapshot._(copy);
  }

  Uint8List toBytes() => Uint8List.fromList(_bytes);
}

/// Host-owned durable storage for a server group's protocol state.
///
/// [write] is the single atomic domain operation. Once it completes, a restart
/// must observe either the entire previous snapshot or the entire new one.
abstract interface class ServerPersistence {
  Future<ServerStateSnapshot?> load(String groupId);

  Future<void> write(String groupId, ServerStateSnapshot state);
}

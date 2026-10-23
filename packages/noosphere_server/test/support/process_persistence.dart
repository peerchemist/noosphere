import 'dart:convert';
import 'dart:io';

import 'package:noosphere_server/noosphere_server.dart';

/// Models an application wrapper across real test processes.
final class TestProcessPersistence(final Directory directory)
    implements ServerPersistence {
  File _file(String groupId) =>
      File('${directory.path}/${base64Url.encode(utf8.encode(groupId))}.state');

  @override
  Future<ServerStateSnapshot?> load(String groupId) async {
    final file = _file(groupId);
    if (!await file.exists()) return null;
    return ServerStateSnapshot.fromBytes(await file.readAsBytes());
  }

  @override
  Future<void> write(String groupId, ServerStateSnapshot state) async {
    await directory.create(recursive: true);
    await _file(groupId).writeAsBytes(state.toBytes(), flush: true);
  }
}

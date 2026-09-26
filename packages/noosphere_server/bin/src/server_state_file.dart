import 'dart:convert';
import 'dart:io';

import 'package:noosphere_server/noosphere_server.dart';

/// CLI-owned file persistence. Embedders should use their transactional store.
final class FileServerPersistence implements ServerPersistence {
  FileServerPersistence(this.directory);

  final Directory directory;

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
    final target = _file(groupId);
    final temporary = File(
      '${target.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsBytes(state.toBytes(), flush: true);
    await temporary.rename(target.path);
  }
}

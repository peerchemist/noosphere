import 'dart:io';
import 'dart:math';

import 'package:iroh_quic/iroh_quic.dart';

// CLI policy only. Embedding applications provide their own identity storage.
// In-process calls share work; the file lock serializes cooperating processes.
final _loads = <String, Future<SecretKey>>{};

Future<SecretKey> loadOrCreateIdentityFile(String path) {
  if (path.isEmpty) throw ArgumentError.value(path, 'path');
  final file = File(path).absolute;
  return _loads.putIfAbsent(file.path, () async {
    try {
      return await _loadLocked(file);
    } finally {
      _loads.remove(file.path);
    }
  });
}

Future<SecretKey> _loadLocked(File file) async {
  await file.parent.create(recursive: true);
  final lock = await File('${file.path}.lock').open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.blockingExclusive);
    if (await file.exists()) {
      await _restrictPermissions(file);
      return SecretKey.fromBytes(await file.readAsBytes());
    }

    final random = Random.secure();
    final secret = SecretKey.fromBytes(
      List<int>.generate(SecretKey.lengthBytes, (_) => random.nextInt(256)),
    );
    final temporary = await file.parent.createTemp('identity-');
    try {
      final staging = await File('${temporary.path}/identity').create();
      // Set permissions before writing any key material.
      await _restrictPermissions(staging);
      await staging.writeAsBytes(secret.toBytes(), flush: true);
      await staging.rename(file.path);
    } finally {
      await temporary.delete(recursive: true);
    }
    return secret;
  } finally {
    // Closing releases the lock. Keep the lock file so every process locks
    // the same inode, including processes already waiting for the lock.
    await lock.close();
  }
}

Future<void> _restrictPermissions(File file) async {
  if (Platform.isWindows) return;
  final result = await Process.run('chmod', ['600', file.path]);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'could not restrict identity permissions',
      file.path,
    );
  }
}

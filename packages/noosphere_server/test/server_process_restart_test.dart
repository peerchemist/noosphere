@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('real process restart durably interrupts an unfinished DKG', () async {
    final directory = await Directory.systemTemp.createTemp(
      'noosphere-server-restart-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final helper =
        File('packages/noosphere_server/test/server_restart_helper.dart')
            .existsSync()
        ? 'packages/noosphere_server/test/server_restart_helper.dart'
        : 'test/server_restart_helper.dart';
    final packageConfig = File('.dart_tool/package_config.json').existsSync()
        ? '.dart_tool/package_config.json'
        : '../../.dart_tool/package_config.json';

    final seeded = await Process.run(Platform.resolvedExecutable, [
      '--packages=$packageConfig',
      helper,
      directory.path,
      'seed',
    ]);
    expect(seeded.exitCode, 0, reason: seeded.stderr as String);
    final active = _snapshot(seeded.stdout as String);
    expect((active['dkg'] as List).single['status'], 'active');

    final restarted = await Process.run(Platform.resolvedExecutable, [
      '--packages=$packageConfig',
      helper,
      directory.path,
      'restore',
    ]);
    expect(restarted.exitCode, 0, reason: restarted.stderr as String);
    final recovered = _snapshot(restarted.stdout as String);
    expect((recovered['dkg'] as List).single['status'], 'interrupted');
  });
}

Map<String, dynamic> _snapshot(String output) {
  final line = output
      .split('\n')
      .where((line) => line.startsWith('{"version"'))
      .last;
  return jsonDecode(line) as Map<String, dynamic>;
}

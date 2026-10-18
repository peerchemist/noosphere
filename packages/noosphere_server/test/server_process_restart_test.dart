@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:noosphere_protocol/public_feed.dart';

void main() {
  test('public journal survives process restart without cursor reuse or duplicate recovery', () async {
    final directory = await Directory.systemTemp.createTemp(
      'noosphere-feed-restart-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final helper = File('test/server_restart_helper.dart').existsSync()
        ? 'test/server_restart_helper.dart'
        : 'packages/noosphere_server/test/server_restart_helper.dart';
    final packageConfig = File('.dart_tool/package_config.json').existsSync()
        ? '.dart_tool/package_config.json'
        : '../../.dart_tool/package_config.json';
    final feedId = PublicFeedId.generate();
    for (final operation in ['seed', 'restore', 'restore']) {
      final result = await Process.run(Platform.resolvedExecutable, [
        '--packages=$packageConfig',
        helper,
        directory.path,
        operation,
        feedId.hex,
      ]);
      expect(result.exitCode, 0, reason: result.stderr as String);
      final journal = _snapshot(result.stdout as String)['publicFeed'] as Map;
      expect(journal['feedId'], feedId.hex);
      expect(journal['nextCursor'], operation == 'seed' ? 2 : 3);
      final entries = (journal['entries'] as List)
          .map(
            (e) =>
                PublicFeedPage.fromBytes(base64Decode(e as String))
                    .entries
                    .single,
          )
          .toList();
      expect(entries.first.state, PublicFeedLifecycle.requested);
      if (operation != 'seed') {
        expect(entries.last.cursor, 2);
        expect(entries.last.state, PublicFeedLifecycle.cancelled);
        expect(entries.first.eventId, entries.last.eventId);
      }
    }
  });

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

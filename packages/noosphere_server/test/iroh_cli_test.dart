@TestOn('vm')
@Timeout(Duration(seconds: 90))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:test/test.dart';

import 'data.dart';

void main() {
  setUpAll(loadFrosty);

  test('CLI handles SIGTERM and preserves its endpoint identity', () async {
    final temporary = await Directory.systemTemp.createTemp('iroh-cli-');
    addTearDown(() => temporary.delete(recursive: true));
    final configFile = File('${temporary.path}/server.yaml');
    final nativeLibrary = Platform.environment['IROH_NATIVE_LIBRARY'];
    final secretPath = '${temporary.path}/identity/secret.key';
    await configFile.writeAsString('''
secret-key-path: ${jsonEncode(secretPath)}
relay:
  policy: disabled
${nativeLibrary == null ? '' : 'native-library-path: ${jsonEncode(nativeLibrary)}'}
server:
  group:
    id: ${jsonEncode(groupConfig.id)}
    participant-keys:
${groupConfig.participants.entries.map((e) => '      "${e.key}": "${e.value.hex}"').join('\n')}
''');

    final firstId = await _startAndStop(configFile.path);
    final secondId = await _startAndStop(configFile.path);

    expect(secondId, firstId);
    expect(await File(secretPath).length(), SecretKey.lengthBytes);
  });
}

Future<String> _startAndStop(String configPath) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    <String>['run', 'bin/iroh_server.dart', '--config', configPath],
    workingDirectory: Directory.current.path,
    environment: Platform.environment,
  );
  final ready = Completer<String>();
  final stdoutLog = StringBuffer();
  final stderrLog = StringBuffer();
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      stdoutLog.writeln(line);
      if (line.startsWith('IROH_SERVER_READY ') && !ready.isCompleted) {
        ready.complete(line.split(' ')[1]);
      }
    },
  );
  process.stderr.transform(utf8.decoder).listen(stderrLog.write);

  final id = await Future.any<String>(<Future<String>>[
    ready.future,
    process.exitCode.then(
      (code) => throw StateError(
        'CLI exited with $code before readiness:\n$stdoutLog\n$stderrLog',
      ),
    ),
  ]).timeout(const Duration(seconds: 45));
  expect(process.kill(ProcessSignal.sigterm), isTrue);
  final exitCode = await process.exitCode.timeout(const Duration(seconds: 10));
  expect(exitCode, 0, reason: '$stdoutLog\n$stderrLog');
  expect(stdoutLog.toString(), contains('shutting down'));
  return id;
}

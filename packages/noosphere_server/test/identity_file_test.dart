@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../bin/src/identity_file.dart';

void main() {
  late Directory directory;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('noosphere-identity-');
    path = '${directory.path}/identity/key';
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'CLI provider reloads the stored identity with restricted permissions',
    () async {
      final first = await loadOrCreateIdentityFile(path);
      final second = await loadOrCreateIdentityFile(path);
      expect(second.toBytes(), first.toBytes());
      expect(await File(path).readAsBytes(), first.toBytes());
      if (!Platform.isWindows) {
        expect((await File(path).stat()).mode & 0x1ff, 0x180);
      }
    },
  );

  test('concurrent processes create exactly one identity', () async {
    final probe = File('${directory.path}/probe.dart');
    final provider = File('bin/src/identity_file.dart').absolute.uri;
    await probe.writeAsString('''
import 'dart:convert';
import '$provider';
Future<void> main(List<String> args) async {
  final key = await loadOrCreateIdentityFile(args.single);
  print(base64Encode(key.toBytes()));
}
''');
    final results = await Future.wait(
      List.generate(
        4,
        (_) => Process.run(Platform.resolvedExecutable, [
          '--packages=${File('../../.dart_tool/package_config.json').absolute.path}',
          probe.path,
          path,
        ]),
      ),
    );
    for (final result in results) {
      expect(result.exitCode, 0, reason: result.stderr.toString());
    }
    final identities = results
        .map((result) => result.stdout.toString().trim())
        .toSet();
    expect(identities, hasLength(1));
    expect(base64Decode(identities.single), await File(path).readAsBytes());
  });

  test('invalid stored identity fails without replacing it', () async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(
      loadOrCreateIdentityFile(path),
      throwsA(isA<Exception>()),
    );
    expect(await file.readAsBytes(), [1, 2, 3]);
  });
}

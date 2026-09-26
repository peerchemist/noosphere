@TestOn('vm')
library;

import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:test/test.dart';

import 'data.dart';

void main() {
  setUpAll(() async {
    await loadFrosty();
    await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  });

  test('persistent secret keeps the same server endpoint ID', () async {
    final temporary = await Directory.systemTemp.createTemp('iroh-server-');
    addTearDown(() => temporary.delete(recursive: true));
    final config = IrohConfig(
      server: serverConfig,
      secretKeyPath: '${temporary.path}/identity/secret.key',
      relay: IrohRelayConfig.disabled(),
      nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
    );

    final first = await IrohServer.start(config);
    final firstId = first.id;
    await first.close();
    final second = await IrohServer.start(config);
    addTearDown(second.close);

    expect(second.id, firstId);
    expect(await File(config.secretKeyPath).length(), SecretKey.lengthBytes);
    if (!Platform.isWindows) {
      final mode = (await File(config.secretKeyPath).stat()).mode & 0x1ff;
      expect(mode, 0x180, reason: 'secret key must have mode 0600');
    }
  });

  test(
    'provided secret starts server without accessing configured path',
    () async {
      final temporary = await Directory.systemTemp.createTemp('iroh-server-');
      addTearDown(() => temporary.delete(recursive: true));
      final secretPath = '${temporary.path}/must-not-exist/secret.key';
      final config = IrohConfig(
        server: serverConfig,
        secretKeyPath: secretPath,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      );
      final secretKey = SecretKey.generate();

      final server = await IrohServer.startWithSecretKey(
        config,
        secretKey: secretKey,
      );
      addTearDown(server.close);

      expect(server.id, secretKey.publicKey);
      expect(await File(secretPath).exists(), isFalse);
      expect(
        await Directory('${temporary.path}/must-not-exist').exists(),
        isFalse,
      );
    },
  );

  test('close releases a blocked accept and is idempotent', () async {
    final temporary = await Directory.systemTemp.createTemp('iroh-server-');
    addTearDown(() => temporary.delete(recursive: true));
    final server = await IrohServer.start(
      IrohConfig(
        server: serverConfig,
        secretKeyPath: '${temporary.path}/secret.key',
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
    );

    final accepted = server.accept();
    await Future.wait([server.close(), server.close()]);

    expect(await accepted, isNull);
    expect(server.isClosed, isTrue);
  });
}

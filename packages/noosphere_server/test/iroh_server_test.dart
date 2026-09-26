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

  IrohConfig config() => IrohConfig(
    server: serverConfig,
    relay: IrohRelayConfig.disabled(),
    nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
  );

  test('host-supplied secret keeps the endpoint ID across restarts', () async {
    final secret = SecretKey.generate();
    final first = await IrohServer.start(
      config(),
      secretKey: secret,
      persistence: newServerPersistence(),
    );
    final firstId = first.id;
    await first.close();
    final second = await IrohServer.start(
      config(),
      secretKey: SecretKey.fromBytes(secret.toBytes()),
      persistence: newServerPersistence(),
    );
    addTearDown(second.close);

    expect(second.id, firstId);
    expect(second.id, secret.publicKey);
  });

  test('embedding alias uses the supplied identity', () async {
    final secret = SecretKey.generate();
    final server = await IrohServer.start(
      config(),
      secretKey: secret,
      persistence: newServerPersistence(),
    );
    addTearDown(server.close);
    expect(server.id, secret.publicKey);
  });

  test('close releases a blocked accept and is idempotent', () async {
    final server = await IrohServer.start(
      config(),
      secretKey: SecretKey.generate(),
      persistence: newServerPersistence(),
    );
    final accepted = server.accept();
    await Future.wait([server.close(), server.close()]);

    expect(await accepted, isNull);
    expect(server.isClosed, isTrue);
  });
}

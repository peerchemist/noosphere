@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_protocol/wire.dart' as wire;
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'data.dart';

void main() {
  setUpAll(() async {
    await loadFrosty();
    await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  });

  Future<IrohServer> serve({
    int maxConnections = 4,
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    final identity = SecretKey.generate();
    final server = await IrohServer.start(
      IrohConfig(
        server: serverConfig,
        relay: IrohRelayConfig.disabled(),
        maxConnections: maxConnections,
        authTimeout: timeout,
        rpcTimeout: timeout,
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
      secretKey: identity,
      persistence: InMemoryServerPersistence(),
      rooms: await RoomManager.open(
        coordinatorEndpointId: identity.publicKey.asBytes(),
        persistence: InMemoryRoomPersistence(),
      ),
    );
    final serving = server.serve();
    addTearDown(() async {
      await server.close();
      await serving;
    });
    return server;
  }

  Future<Connection> connect(IrohServer server, String alpn) async {
    final endpoint = await Endpoint.bind(
      alpns: [alpn.codeUnits],
      relayMode: RelayMode.disabled,
    );
    addTearDown(endpoint.close);
    return endpoint.connect(_address(server), alpn.codeUnits);
  }

  Future<(IrohClientApi, SessionID)> login(IrohServer server) async {
    final api = await IrohClientApi.connect(
      IrohClientTransportConfig(
        bootstrapAddress: _address(server),
        pinnedServerId: server.id,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
    );
    addTearDown(api.close);
    final challenge = await api.login(
      groupFingerprint: groupConfig.fingerprint,
      participantId: ids.first,
    );
    final session = await api.respondToChallenge(
      Signed.sign(obj: challenge.challenge, key: getPrivkey(0)),
    );
    final subscription = session.events.listen((_) {});
    addTearDown(subscription.cancel);
    return (api, session.id);
  }

  for (final alpn in [
    noosphereIrohAlpn,
    noospherePublicFeedAlpn,
    noosphereEnrollmentAlpn,
  ]) {
    test('$alpn closes idle connections without a first stream', () async {
      final server = await serve();
      final connection = await connect(server, alpn);
      expect(
        await connection.closed().timeout(const Duration(seconds: 4)),
        contains('deadline exceeded'),
      );
      final (api, sid) = await login(server);
      expect((await api.extendSession(sid)).isExpired, isFalse);
    });
  }

  test('public and enrollment saturation preserves signer capacity', () async {
    final server = await serve(timeout: const Duration(seconds: 5));
    final public = await connect(server, noospherePublicFeedAlpn);
    final enrollment = await connect(server, noosphereEnrollmentAlpn);
    final excess = await connect(server, noospherePublicFeedAlpn);
    expect(
      await excess.closed().timeout(const Duration(seconds: 2)),
      contains('connection limit reached'),
    );
    final (api, sid) = await login(server);
    expect((await api.extendSession(sid)).isExpired, isFalse);
    public.close();
    enrollment.close();
  });

  test('a one-connection budget admits only signer traffic', () async {
    final server = await serve(
      maxConnections: 1,
      timeout: const Duration(seconds: 5),
    );
    for (final alpn in [noospherePublicFeedAlpn, noosphereEnrollmentAlpn]) {
      final connection = await connect(server, alpn);
      expect(
        await connection.closed().timeout(const Duration(seconds: 2)),
        contains('connection limit reached'),
      );
    }
    final (api, sid) = await login(server);
    final excess = await connect(server, noosphereIrohAlpn);
    expect(
      await excess.closed().timeout(const Duration(seconds: 2)),
      contains('connection limit reached'),
    );
    expect((await api.extendSession(sid)).isExpired, isFalse);
  });

  test('unauthenticated signer saturation expires and permits login', () async {
    final server = await serve(maxConnections: 2);
    final first = await connect(server, noosphereIrohAlpn);
    final second = await connect(server, noosphereIrohAlpn);
    final excess = await connect(server, noosphereIrohAlpn);
    expect(
      await excess.closed().timeout(const Duration(seconds: 2)),
      contains('connection limit reached'),
    );
    for (final connection in [first, second]) {
      expect(
        await connection.closed().timeout(const Duration(seconds: 4)),
        contains('authentication deadline exceeded'),
      );
    }
    final (api, sid) = await login(server);
    expect((await api.extendSession(sid)).isExpired, isFalse);
  });

  test(
    'a login challenge does not cancel the authentication deadline',
    () async {
      final server = await serve();
      final connection = await connect(server, noosphereIrohAlpn);
      final (send, receive) = await connection.openBi();
      await send.writeAll([
        ...wire.encodeQuicVarInt(wire.RoastOperation.login.id),
        ...wire.LoginRequest(
          groupFingerprint: groupConfig.fingerprint,
          participantId: ids.first.toBytes(),
          protocolVersion: noosphereRoastProtocolVersion,
        ).writeToBuffer(),
      ]);
      await send.finish();
      final response = <int>[];
      while (true) {
        final chunk = await receive.read(4096);
        if (chunk == null) break;
        response.addAll(chunk);
      }
      expect(response.first, wire.RpcResponseStatus.success);
      expect(
        wire.LoginResponse.fromBuffer(response.sublist(1)).challenge,
        isNotEmpty,
      );
      expect(
        await connection.closed().timeout(const Duration(seconds: 4)),
        contains('authentication deadline exceeded'),
      );
    },
  );

  test('authenticated signer survives the authentication deadline', () async {
    final server = await serve();
    final (api, sid) = await login(server);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    expect((await api.extendSession(sid)).isExpired, isFalse);
  });

  test('public idle deadline restarts after a completed RPC', () async {
    final server = await serve();
    final connection = await connect(server, noospherePublicFeedAlpn);
    // Complete an ordinary request: an unknown feed is a valid NOT_FOUND RPC.
    for (var i = 0; i < 4; i++) {
      final (send, receive) = await connection.openBi();
      await send.writeAll([
        ...wire.encodeQuicVarInt(wire.PublicFeedOperation.getPublicFeed.id),
        ...wire.GetPublicFeedRequest(feedId: List.filled(32, 1))
            .writeToBuffer(),
      ]);
      await send.finish();
      final response = <int>[];
      while (true) {
        final chunk = await receive.read(4096);
        if (chunk == null) break;
        response.addAll(chunk);
      }
      expect(response.first, wire.RpcResponseStatus.error);
      final error = wire.ProtocolError.fromBuffer(response.sublist(1));
      expect(error.code, wire.ProtocolErrorCode.PROTOCOL_ERROR_NOT_FOUND);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    expect(
      await connection.closed().timeout(const Duration(seconds: 4)),
      contains('idle connection deadline exceeded'),
    );
  });
}

EndpointAddr _address(IrohServer server) => EndpointAddr(
  server.id,
  ipAddrs: server.endpoint.boundSockets.map((address) {
    final split = address.lastIndexOf(':');
    return address.startsWith('[')
        ? '[::1]${address.substring(split)}'
        : '127.0.0.1${address.substring(split)}';
  }).toList(),
);

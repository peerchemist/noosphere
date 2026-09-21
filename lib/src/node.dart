import 'dart:async';

import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:meta/meta.dart';
import 'package:noosphere_roast_server/noosphere_roast_server.dart';

import 'client_options.dart';
import 'initialization.dart';
import 'node_testing.dart';
import 'server_identity_store.dart';
import 'server_options.dart';

const _sentinelSecretKeyPath = 'host-managed://iroh-secret';

/// A running Flutter-owned combination of server and client roles.
final class NoosphereNode {
  NoosphereNode._(this._serverRole, this._clientRole);

  static Future<NoosphereNode> start({
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  }) async {
    _validateRoles(server, client);
    await NoosphereFlutter.initialize();
    return _start(
      startServer: server != null,
      startClient: client != null,
      backend: _NativeBackend(server, client),
    );
  }

  @visibleForTesting
  static Future<NoosphereNode> startForTesting({
    required bool server,
    required bool client,
    required NoosphereNodeBackend backend,
  }) {
    if (!server && !client) {
      throw ArgumentError('At least one Noosphere node role is required.');
    }
    return _start(startServer: server, startClient: client, backend: backend);
  }

  static void _validateRoles(
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  ) {
    if (server == null && client == null) {
      throw ArgumentError('At least one Noosphere node role is required.');
    }
  }

  static Future<NoosphereNode> _start({
    required bool startServer,
    required bool startClient,
    required NoosphereNodeBackend backend,
  }) async {
    NoosphereServerRole? serverRole;
    NoosphereClientRole? clientRole;
    try {
      if (startServer) serverRole = await backend.startServer();
      if (startClient) clientRole = await backend.startClient();
      return NoosphereNode._(serverRole, clientRole);
    } catch (error, stackTrace) {
      await _ignoreCleanupErrors(clientRole?.close);
      await _ignoreCleanupErrors(serverRole?.close);
      await _ignoreCleanupErrors(serverRole?.waitForServe);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  final NoosphereServerRole? _serverRole;
  final NoosphereClientRole? _clientRole;
  Future<void>? _closing;

  IrohServer? get server => _serverRole?.server;
  ReconnectingIrohClient? get client => _clientRole?.client;
  EndpointId? get serverId => server?.id;
  EndpointAddr? get serverAddress => server?.address;

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> run(Future<void> Function()? operation) async {
      if (operation == null) return;
      try {
        await operation();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await run(_clientRole?.close);
    await run(_serverRole?.close);
    await run(_serverRole?.waitForServe);

    if (firstError case final error?) {
      Error.throwWithStackTrace(error, firstStackTrace!);
    }
  }
}

Future<void> _ignoreCleanupErrors(Future<void> Function()? operation) async {
  if (operation == null) return;
  try {
    await operation();
  } on Object {
    // Startup must preserve its original error and stack trace.
  }
}

final class _NativeBackend(
  final EmbeddedServerOptions? serverOptions,
  final ClientNodeOptions? clientOptions,
) implements NoosphereNodeBackend {
  @override
  Future<NoosphereServerRole> startServer() async {
    final options = serverOptions!;
    final secretKey = await loadOrCreateServerIdentity(options.identityStore);
    final server = await IrohServer.startWithSecretKey(
      IrohConfig(
        server: options.serverConfig,
        secretKeyPath: _sentinelSecretKeyPath,
        relay: options.relay,
        alpn: options.alpn,
        authTimeout: options.authTimeout,
        rpcTimeout: options.rpcTimeout,
        shutdownTimeout: options.shutdownTimeout,
        maxEnvelopeLength: options.maxEnvelopeLength,
        maxConnections: options.maxConnections,
        maxStreamsPerConnection: options.maxStreamsPerConnection,
      ),
      secretKey: secretKey,
      handler: options.handler,
    );
    return _NativeServerRole.start(server);
  }

  @override
  Future<NoosphereClientRole> startClient() async {
    final options = clientOptions!;
    final client = await ReconnectingIrohClient.connect(
      clientConfig: options.clientConfig,
      transportConfig: options.toTransportConfig(),
      store: options.storage,
      getPrivateKey: options.getPrivateKey,
      reconnectConfig: options.reconnect,
    );
    return _NativeClientRole(client);
  }
}

final class _NativeServerRole implements NoosphereServerRole {
  _NativeServerRole._(this.server);

  static _NativeServerRole start(IrohServer server) {
    final role = _NativeServerRole._(server);
    role._serving = server.serve().then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        role
          .._serveError = error
          .._serveStackTrace = stackTrace;
      },
    );
    return role;
  }

  @override
  final IrohServer server;
  late final Future<void> _serving;
  Object? _serveError;
  StackTrace? _serveStackTrace;

  @override
  Future<void> close() => server.close();

  @override
  Future<void> waitForServe() async {
    await _serving;
    if (_serveError case final error?) {
      Error.throwWithStackTrace(error, _serveStackTrace!);
    }
  }
}

final class _NativeClientRole(@override final ReconnectingIrohClient client)
    implements NoosphereClientRole {
  @override
  Future<void> close() => client.close();
}

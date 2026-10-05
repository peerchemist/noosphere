import 'dart:async';

import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:meta/meta.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_server/noosphere_server.dart';

import 'client_connection.dart';
import 'client_options.dart';
import 'initialization.dart';
import 'node_testing.dart';
import 'server_options.dart';

/// Completion of an embedded server's serving loop.
///
/// [error] is null after normal completion. [NoosphereNode.serverDone] returns
/// this value without an unhandled error if an application does not observe it.
final class NoosphereServerTermination {
  const NoosphereServerTermination({this.error, this.stackTrace});
  final Object? error;
  final StackTrace? stackTrace;
}

/// A running Flutter-owned combination of server and client roles.
final class NoosphereNode {
  NoosphereNode._(this._serverRole, this._clientRole) {
    if (_serverRole != null) {
      _serverRunning = true;
      _serverDone = _observeServer();
    }
  }

  /// Starts the requested roles.
  ///
  /// When [client] targets [localCoordinator], and that server currently hosts
  /// the client's group, the participant uses an in-process session instead of
  /// opening a second Iroh endpoint and a loopback QUIC connection. A node that
  /// starts both [server] and [client] performs the same detection automatically.
  static Future<NoosphereNode> start({
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
    IrohServer? localCoordinator,
  }) async {
    _validateRoles(server, client);
    if (server != null && localCoordinator != null) {
      throw ArgumentError(
        'Provide server options or an existing local coordinator, not both.',
      );
    }
    await NoosphereFlutter.initialize();
    return _start(
      startServer: server != null,
      startClient: client != null,
      backend: _NativeBackend(server, client, localCoordinator),
    );
  }

  /// Starts after native bindings have already been initialized in the
  /// calling isolate. Used by the package-owned worker entry point so it never
  /// invokes root-isolate Flutter binding setup.
  @internal
  static Future<NoosphereNode> startInitialized({
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
    IrohServer? localCoordinator,
  }) {
    _validateRoles(server, client);
    return _start(
      startServer: server != null,
      startClient: client != null,
      backend: _NativeBackend(server, client, localCoordinator),
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
  bool _serverRunning = false;
  Future<NoosphereServerTermination>? _serverDone;

  /// Whether the embedded server is still serving and has not begun closing.
  bool get serverRunning => _serverRunning && _closing == null;

  /// Completes as soon as the serving loop ends, including before [close].
  /// Null for client-only nodes. Inspect the result's error for failure.
  Future<NoosphereServerTermination>? get serverDone => _serverDone;

  Future<NoosphereServerTermination> _observeServer() async {
    try {
      await _serverRole!.waitForServe();
      return const NoosphereServerTermination();
    } catch (error, stackTrace) {
      return NoosphereServerTermination(error: error, stackTrace: stackTrace);
    } finally {
      _serverRunning = false;
    }
  }

  IrohServer? get server => _serverRole?.server;
  NoosphereClientConnection? get client => _clientRole?.client;
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
    final termination = await _serverDone;
    firstError ??= termination?.error;
    firstStackTrace ??= termination?.stackTrace;

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

final class _NativeBackend implements NoosphereNodeBackend {
  _NativeBackend(
    this.serverOptions,
    this.clientOptions, [
    IrohServer? localCoordinator,
  ]) : _localCoordinator = localCoordinator;

  final EmbeddedServerOptions? serverOptions;
  final ClientNodeOptions? clientOptions;
  IrohServer? _localCoordinator;

  @override
  Future<NoosphereServerRole> startServer() async {
    final options = serverOptions!;
    final secretKey = await options.getIrohSecretKey();
    final roomPersistence = options.roomPersistence;
    final rooms = roomPersistence == null
        ? null
        : await RoomManager.open(
            coordinatorEndpointId: secretKey.publicKey.asBytes(),
            persistence: roomPersistence,
          );
    final server = await IrohServer.start(
      IrohConfig(
        server: options.serverConfig,
        relay: options.relay,
        alpn: options.alpn,
        authTimeout: options.authTimeout,
        rpcTimeout: options.rpcTimeout,
        shutdownTimeout: options.shutdownTimeout,
        maxMessageLength: options.maxMessageLength,
        maxConnections: options.maxConnections,
        maxStreamsPerConnection: options.maxStreamsPerConnection,
      ),
      secretKey: secretKey,
      persistence: options.serverPersistence,
      handler: options.handler,
      rooms: rooms,
    );
    _localCoordinator = server;
    return _NativeServerRole.start(server);
  }

  @override
  Future<NoosphereClientRole> startClient() async {
    final options = clientOptions!;
    final local = _localCoordinator;
    if (local != null &&
        local.canServeLocally(
          coordinatorId: options.pinnedServerId,
          groupFingerprint: options.clientConfig.group.fingerprint,
        )) {
      return _NativeClientRole(
        await _LocalClientConnection.connect(local, options),
      );
    }
    final client = await ReconnectingIrohClient.connect(
      clientConfig: options.clientConfig,
      transportConfig: options.toTransportConfig(),
      store: options.storage,
      getPrivateKey: options.getPrivateKey,
      reconnectConfig: options.reconnect,
    );
    return _NativeClientRole(_IrohClientConnection(client));
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

final class _NativeClientRole(@override final NoosphereClientConnection client)
    implements NoosphereClientRole {
  @override
  Future<void> close() => client.close();
}

final class _IrohClientConnection implements NoosphereClientConnection {
  _IrohClientConnection(this._client);

  final ReconnectingIrohClient _client;

  @override
  Client get current => _client.current;

  @override
  Stream<Client> get sessions => _client.sessions;

  @override
  bool get isConnected => _client.isConnected;

  @override
  bool get isLocal => false;

  @override
  IrohClientTransportConfig get transportConfig => _client.transportConfig;

  @override
  void updateTransportConfig(IrohClientTransportConfig config) =>
      _client.updateTransportConfig(config);

  @override
  Future<void> close() => _client.close();
}

final class _LocalClientConnection implements NoosphereClientConnection {
  _LocalClientConnection._(
    this._server,
    this._api,
    this._client,
    this._transportConfig,
  );

  static Future<_LocalClientConnection> connect(
    IrohServer server,
    ClientNodeOptions options,
  ) async {
    final api = server.openLocalApi(options.clientConfig.group.fingerprint);
    var connected = true;
    _LocalClientConnection? connection;
    try {
      final client = await Client.login(
        config: options.clientConfig,
        api: api,
        store: options.storage,
        getPrivateKey: options.getPrivateKey,
        onDisconnect: () {
          connected = false;
          connection?._connected = false;
        },
      );
      final result = _LocalClientConnection._(
        server,
        api,
        client,
        options.toTransportConfig(),
      ).._connected = connected;
      connection = result;
      return result;
    } catch (_) {
      await api.close();
      rethrow;
    }
  }

  final IrohServer _server;
  final LocalCoordinatorApi _api;
  final Client _client;
  IrohClientTransportConfig _transportConfig;
  bool _connected = true;
  bool _closed = false;
  Future<void>? _closing;

  @override
  Client get current {
    if (!isConnected) throw StateError('no active local client session');
    return _client;
  }

  @override
  Stream<Client> get sessions => const Stream.empty();

  @override
  bool get isConnected => _connected && !_closed && !_server.isClosed;

  @override
  bool get isLocal => true;

  @override
  IrohClientTransportConfig get transportConfig => _transportConfig;

  @override
  void updateTransportConfig(IrohClientTransportConfig config) {
    if (_closed) throw StateError('local client connection is closed');
    if (config.pinnedServerId != _server.id) {
      throw ArgumentError.value(
        config.pinnedServerId,
        'config.pinnedServerId',
        'cannot retarget a local coordinator connection',
      );
    }
    _transportConfig = config;
  }

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _connected = false;
    try {
      await _client.logout();
    } finally {
      await _api.close();
    }
  }
}

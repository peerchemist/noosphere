import 'dart:async';
import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:meta/meta.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_server/noosphere_server.dart';

import 'client_options.dart';
import 'initialization.dart';
import 'node_testing.dart';
import 'server_identity_store.dart';
import 'server_options.dart';

/// A running Flutter-owned combination of server and client roles.
final class NoosphereNode {
  NoosphereNode._(this._serverRole, this._clientRole, this._identityStore);

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
      identityStore: server?.identityStore,
    );
  }

  /// Starts after native bindings have already been initialized in the
  /// calling isolate. Used by the package-owned worker entry point so it never
  /// invokes root-isolate Flutter binding setup.
  @internal
  static Future<NoosphereNode> startInitialized({
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  }) {
    _validateRoles(server, client);
    return _start(
      startServer: server != null,
      startClient: client != null,
      backend: _NativeBackend(server, client),
      identityStore: server?.identityStore,
    );
  }

  @visibleForTesting
  static Future<NoosphereNode> startForTesting({
    required bool server,
    required bool client,
    required NoosphereNodeBackend backend,
    ServerIdentityStore? identityStore,
  }) {
    if (!server && !client) {
      throw ArgumentError('At least one Noosphere node role is required.');
    }
    return _start(
      startServer: server,
      startClient: client,
      backend: backend,
      identityStore: identityStore,
    );
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
    required ServerIdentityStore? identityStore,
  }) async {
    NoosphereServerRole? serverRole;
    NoosphereClientRole? clientRole;
    try {
      if (startServer) serverRole = await backend.startServer();
      if (startClient) clientRole = await backend.startClient();
      return NoosphereNode._(serverRole, clientRole, identityStore);
    } catch (error, stackTrace) {
      await _ignoreCleanupErrors(clientRole?.close);
      await _ignoreCleanupErrors(serverRole?.close);
      await _ignoreCleanupErrors(serverRole?.waitForServe);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  final NoosphereServerRole? _serverRole;
  final NoosphereClientRole? _clientRole;
  final ServerIdentityStore? _identityStore;
  Future<void>? _closing;

  IrohServer? get server => _serverRole?.server;
  ReconnectingIrohClient? get client => _clientRole?.client;
  EndpointId? get serverId => server?.id;
  EndpointAddr? get serverAddress => server?.address;

  /// Exports this embedded server's raw 32-byte Iroh secret key.
  ///
  /// The result is a secret key, not the public endpoint ID. Encrypt the
  /// backup and never log it. A fresh defensive copy is returned, but Dart
  /// managed memory cannot guarantee reliable zeroization. Restore it with
  /// [restoreStoredIrohServerIdentity] before starting a replacement node.
  ///
  /// Throws [StateError] when this node has no embedded server role.
  Future<Uint8List> exportIrohServerIdentity() async {
    final store = _identityStore;
    if (store == null) {
      throw StateError(
        'Cannot export an Iroh server identity from a client-only node.',
      );
    }
    return await exportStoredIrohServerIdentity(store);
  }

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
    final roomPersistence = options.roomPersistence;
    final rooms = roomPersistence == null
        ? null
        : await RoomManager.open(
            coordinatorEndpointId: secretKey.publicKey.asBytes(),
            persistence: roomPersistence,
          );
    final server = await IrohServer.startWithSecretKey(
      IrohConfig(
        server: options.serverConfig,
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
      rooms: rooms,
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

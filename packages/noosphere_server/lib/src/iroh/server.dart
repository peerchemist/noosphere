import 'dart:async';
import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';

import '../config/iroh.dart';
import '../server/api_handler.dart';
import 'connection_handler.dart';
import 'dispatcher.dart';

/// Bound Iroh endpoint and persistent server identity lifecycle.
final class IrohServer {
  IrohServer._({
    required this.config,
    required this.endpoint,
    required this.dispatcher,
  });

  static Future<IrohServer> start(
    IrohConfig config, {
    ServerApiHandler? handler,
  }) async {
    await Iroh.init(libraryPath: config.nativeLibraryPath);
    final secretKey = await _loadOrCreateSecret(File(config.secretKeyPath));
    return _bind(config, secretKey: secretKey, handler: handler);
  }

  /// Starts a server with an identity supplied by the embedding application.
  ///
  /// Unlike [start], this method does not read or write
  /// [IrohConfig.secretKeyPath]. It is intended for hosts such as Flutter
  /// applications that persist the endpoint identity in platform-provided
  /// secure storage.
  static Future<IrohServer> startWithSecretKey(
    IrohConfig config, {
    required SecretKey secretKey,
    ServerApiHandler? handler,
  }) async {
    await Iroh.init(libraryPath: config.nativeLibraryPath);
    return _bind(config, secretKey: secretKey, handler: handler);
  }

  static Future<IrohServer> _bind(
    IrohConfig config, {
    required SecretKey secretKey,
    ServerApiHandler? handler,
  }) async {
    final endpoint = await Endpoint.bind(
      secretKey: secretKey,
      alpns: [config.alpn.codeUnits],
      relayMode: config.relay.toRelayMode(),
    );
    final api = handler ?? ServerApiHandler(config: config.server);
    return IrohServer._(
      config: config,
      endpoint: endpoint,
      dispatcher: IrohDispatcher.single(api),
    );
  }

  final IrohConfig config;
  final Endpoint endpoint;
  final IrohDispatcher dispatcher;
  Future<void>? _closing;
  Future<void>? _serving;
  final Set<Future<void>> _connections = {};

  EndpointId get id => endpoint.id;
  EndpointAddr get address => endpoint.addr;
  bool get isClosed => endpoint.isClosed;

  Future<Connection?> accept() => endpoint.accept();

  Future<void> serve() => _serving ??= _serve();

  Future<void> _serve() async {
    while (!endpoint.isClosed) {
      final connection = await endpoint.accept();
      if (connection == null) break;
      if (_connections.length >= config.maxConnections) {
        connection.close(reason: 'connection limit reached'.codeUnits);
        continue;
      }
      late final Future<void> handling;
      handling = IrohConnectionHandler(
        connection: connection,
        dispatcher: dispatcher,
        config: config,
      ).run().whenComplete(() => _connections.remove(handling));
      _connections.add(handling);
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    await endpoint.close().timeout(
      config.shutdownTimeout,
      onTimeout: () => throw TimeoutException(
        'Iroh endpoint did not close within ${config.shutdownTimeout}',
      ),
    );
    try {
      await Future.wait(_connections.toList(), eagerError: false).timeout(
        config.shutdownTimeout,
        onTimeout: () => throw TimeoutException(
          'Iroh connections did not close within ${config.shutdownTimeout}',
        ),
      );
    } finally {
      await dispatcher.close().timeout(
        config.shutdownTimeout,
        onTimeout: () => throw TimeoutException(
          'Iroh dispatcher did not close within ${config.shutdownTimeout}',
        ),
      );
    }
  }
}

Future<SecretKey> _loadOrCreateSecret(File file) async {
  if (await file.exists()) {
    await _restrictSecretPermissions(file);
    return SecretKey.fromBytes(await file.readAsBytes());
  }

  await file.parent.create(recursive: true);
  final generated = SecretKey.generate();
  final temporary = File(
    '${file.path}.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}',
  );
  await temporary.writeAsBytes(generated.toBytes(), flush: true);
  await _restrictSecretPermissions(temporary);

  try {
    await temporary.rename(file.path);
    return generated;
  } on FileSystemException {
    // Another process may have won the create race. Never overwrite its key.
    if (await file.exists()) {
      if (await temporary.exists()) await temporary.delete();
      return SecretKey.fromBytes(await file.readAsBytes());
    }
    if (await temporary.exists()) await temporary.delete();
    rethrow;
  }
}

Future<void> _restrictSecretPermissions(File file) async {
  if (Platform.isWindows) return;
  final result = await Process.run('chmod', ['600', file.path]);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'could not restrict Iroh secret key permissions: ${result.stderr}',
      file.path,
    );
  }
}

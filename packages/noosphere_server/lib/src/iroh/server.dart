import 'dart:async';
import 'dart:io';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/config.dart';
import 'package:noosphere/iroh.dart';
import 'package:noosphere/room.dart';

import '../config/iroh.dart';
import '../config/server.dart';
import '../server/api_handler.dart';
import '../room/manager.dart';
import 'connection_handler.dart';
import 'dispatcher.dart';
import 'enrollment_connection_handler.dart';

/// Bound Iroh endpoint and persistent server identity lifecycle.
final class IrohServer {
  IrohServer._({
    required this.config,
    required this.endpoint,
    required this.dispatcher,
    required this.rooms,
  });

  static Future<IrohServer> start(
    IrohConfig config, {
    ServerApiHandler? handler,
    RoomManager? rooms,
  }) async {
    await Iroh.init(libraryPath: config.nativeLibraryPath);
    final secretKey = await _loadOrCreateSecret(File(config.secretKeyPath));
    return _bind(config, secretKey: secretKey, handler: handler, rooms: rooms);
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
    RoomManager? rooms,
  }) async {
    await Iroh.init(libraryPath: config.nativeLibraryPath);
    return _bind(config, secretKey: secretKey, handler: handler, rooms: rooms);
  }

  static Future<IrohServer> _bind(
    IrohConfig config, {
    required SecretKey secretKey,
    ServerApiHandler? handler,
    RoomManager? rooms,
  }) async {
    final endpoint = await Endpoint.bind(
      secretKey: secretKey,
      alpns: [
        config.alpn.codeUnits,
        if (rooms != null) noosphereEnrollmentAlpn.codeUnits,
      ],
      relayMode: config.relay.toRelayMode(),
    );
    if (rooms != null &&
        !cl.bytesEqual(rooms.coordinatorEndpointId, endpoint.id.asBytes())) {
      await endpoint.close();
      throw StateError(
        'room coordinator endpoint ID does not match the Iroh identity',
      );
    }
    final api = handler ?? ServerApiHandler(config: config.server);
    rooms?.updateBootstrap(
      relayUrls: [for (final relay in endpoint.addr.relayUrls) relay.value],
      ipAddrs: endpoint.addr.ipAddrs,
    );
    final dispatcher = IrohDispatcher.single(api);
    if (rooms != null) {
      for (final room in await rooms.getRooms()) {
        if (room.lifecycle == RoomLifecycle.frozen) {
          dispatcher.addHandler(
            ServerApiHandler(
              config: _configForGroup(config.server, room.groupConfig!),
            ),
          );
        }
      }
    }
    return IrohServer._(
      config: config,
      endpoint: endpoint,
      dispatcher: dispatcher,
      rooms: rooms,
    );
  }

  final IrohConfig config;
  final Endpoint endpoint;
  final IrohDispatcher dispatcher;
  final RoomManager? rooms;
  Future<void>? _closing;
  Future<void>? _serving;
  final Set<Future<void>> _connections = {};

  EndpointId get id => endpoint.id;
  EndpointAddr get address => endpoint.addr;
  bool get isClosed => endpoint.isClosed;

  Future<Connection?> accept() => endpoint.accept();

  Future<RoomSnapshot> createRoom({
    String? roomId,
    required int expectedParticipants,
    required int threshold,
  }) => _roomManager().createRoom(
    roomId: roomId,
    expectedParticipants: expectedParticipants,
    threshold: threshold,
  );

  Future<RoomSnapshot> getRoom(String roomId) => _roomManager().getRoom(roomId);

  Future<RoomInvite> issueRoomInvite({
    required String roomId,
    required cl.ECCompressedPublicKey expectedParticipantPublicKey,
    required DateTime expiresAt,
  }) {
    final manager = _roomManager();
    manager.updateBootstrap(
      relayUrls: [for (final relay in address.relayUrls) relay.value],
      ipAddrs: address.ipAddrs,
    );
    return manager.issueRoomInvite(
      roomId: roomId,
      expectedParticipantPublicKey: expectedParticipantPublicKey,
      expiresAt: expiresAt,
    );
  }

  Future<RoomSnapshot> revokeRoomInvite({
    required String roomId,
    required String inviteId,
  }) => _roomManager().revokeRoomInvite(roomId: roomId, inviteId: inviteId);

  /// Freezes a complete room and activates its canonical group on the existing
  /// ROAST ALPN without rebinding the endpoint or changing its identity.
  Future<RoomSnapshot> freezeRoom(String roomId) async {
    final manager = _roomManager();
    final room = await manager.freezeRoom(roomId);
    dispatcher.addHandler(
      ServerApiHandler(
        config: _configForGroup(config.server, room.groupConfig!),
      ),
    );
    return room;
  }

  Future<RoomSnapshot> closeRoom(String roomId) async {
    final manager = _roomManager();
    final before = await manager.getRoom(roomId);
    final closed = await manager.closeRoom(roomId);
    final fingerprint = before.groupFingerprint;
    if (fingerprint != null) await dispatcher.removeHandler(fingerprint);
    return closed;
  }

  RoomManager _roomManager() {
    final manager = rooms;
    if (manager == null) throw StateError('room enrollment is not enabled');
    return manager;
  }

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
      final alpn = String.fromCharCodes(connection.alpn);
      if (alpn == noosphereEnrollmentAlpn && rooms != null) {
        handling = IrohEnrollmentConnectionHandler(
          connection: connection,
          rooms: rooms!,
          timeout: config.authTimeout,
          maxMessageLength: config.maxEnvelopeLength,
          maxStreams: config.maxStreamsPerConnection,
        ).run().whenComplete(() => _connections.remove(handling));
      } else if (alpn == config.alpn) {
        handling = IrohConnectionHandler(
          connection: connection,
          dispatcher: dispatcher,
          config: config,
        ).run().whenComplete(() => _connections.remove(handling));
      } else {
        connection.close(reason: 'unsupported ALPN'.codeUnits);
        continue;
      }
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

ServerConfig _configForGroup(ServerConfig template, GroupConfig group) =>
    ServerConfig(
      group: group,
      challengeTTL: template.challengeTTL,
      sessionTTL: template.sessionTTL,
      minDkgRequestTTL: template.minDkgRequestTTL,
      maxDkgRequestTTL: template.maxDkgRequestTTL,
      minSignaturesRequestTTL: template.minSignaturesRequestTTL,
      maxSignaturesRequestTTL: template.maxSignaturesRequestTTL,
      minCompletedSignaturesTTL: template.minCompletedSignaturesTTL,
      ackCacheTTL: template.ackCacheTTL,
      keepAliveFreq: template.keepAliveFreq,
    );

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

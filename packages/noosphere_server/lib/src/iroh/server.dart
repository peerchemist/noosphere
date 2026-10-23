import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/config.dart';
import 'package:noosphere_protocol/iroh.dart';
import 'package:noosphere_protocol/room.dart';

import '../config/iroh.dart';
import '../config/server.dart';
import '../config/public_feed.dart';
import '../server/api_handler.dart';
import '../server/local_coordinator_api.dart';
import '../server/persistence.dart';
import '../room/manager.dart';
import 'connection_handler.dart';
import 'dispatcher.dart';
import 'enrollment_connection_handler.dart';
import 'public_feed_connection_handler.dart';

/// Bound Iroh endpoint using an identity supplied by the host.
final class IrohServer {
  IrohServer._({
    required this.config,
    required this.endpoint,
    required this.dispatcher,
    required this.rooms,
    required this.persistence,
    required this._signingKey,
    required this.onError,
  });

  /// Starts with a host-owned identity. The host must persist a newly created
  /// key before calling this method. No identity files are read or written.
  static Future<IrohServer> start(
    IrohConfig config, {
    required SecretKey secretKey,
    required ServerPersistence persistence,
    ServerApiHandler? handler,
    RoomManager? rooms,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    await Iroh.init(libraryPath: config.nativeLibraryPath);
    return _bind(
      config,
      secretKey: secretKey,
      persistence: persistence,
      handler: handler,
      rooms: rooms,
      onError: onError,
    );
  }

  static Future<IrohServer> _bind(
    IrohConfig config, {
    required SecretKey secretKey,
    required ServerPersistence persistence,
    ServerApiHandler? handler,
    RoomManager? rooms,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    final endpoint = await Endpoint.bind(
      secretKey: secretKey,
      alpns: [
        config.alpn.codeUnits,
        noospherePublicFeedAlpn.codeUnits,
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
    IrohDispatcher? dispatcher;
    try {
      final api =
          handler ??
          ServerApiHandler(config: config.server, persistence: persistence);
      await api.ready;
      dispatcher = IrohDispatcher.single(
        api,
        onError: (error, stackTrace) =>
            _reportHostError(onError, error, stackTrace),
      );
      if (rooms != null) {
        for (final room in await rooms.getRooms()) {
          if (room.lifecycle == RoomLifecycle.frozen) {
            final roomHandler = ServerApiHandler(
              config: _configForGroup(
                config.server,
                room.groupConfig!,
                config.roomPublicFeeds[room.groupConfig!.id],
              ),
              persistence: persistence,
            );
            await roomHandler.ready;
            dispatcher.addHandler(roomHandler);
          }
        }
      }
      return IrohServer._(
        config: config,
        endpoint: endpoint,
        dispatcher: dispatcher,
        rooms: rooms,
        persistence: persistence,
        signingKey: secretKey,
        onError: onError,
      );
    } catch (_) {
      await dispatcher?.close();
      await endpoint.close();
      rethrow;
    }
  }

  final IrohConfig config;
  final Endpoint endpoint;
  final IrohDispatcher dispatcher;
  final RoomManager? rooms;
  final ServerPersistence persistence;
  final SecretKey _signingKey;

  /// Reports unexpected background failures, including transport and scheduled
  /// maintenance failures. Request validation failures are returned to the
  /// peer instead. Defaults to stderr logging. An affected connection is
  /// closed when applicable; other connections keep serving.
  final void Function(Object error, StackTrace stackTrace)? onError;

  static void _reportHostError(
    void Function(Object error, StackTrace stackTrace)? report,
    Object error,
    StackTrace stackTrace,
  ) {
    if (report != null) {
      try {
        report(error, stackTrace);
        return;
      } catch (callbackError, callbackStack) {
        stderr.writeln(
          'Noosphere Iroh error callback failed: $callbackError\n$callbackStack',
        );
      }
    }
    stderr.writeln('Noosphere Iroh task failed: $error\n$stackTrace');
  }

  void _reportError(Object error, StackTrace stackTrace) =>
      _reportHostError(onError, error, stackTrace);

  Future<void>? _closing;
  Future<void>? _serving;
  final Set<Future<void>> _connections = {};
  int _auxiliaryConnections = 0;
  final Set<LocalCoordinatorApi> _localApis = {};

  EndpointId get id => endpoint.id;
  EndpointAddr get address => endpoint.addr;
  bool get isClosed => endpoint.isClosed;

  bool canServeLocally({
    required EndpointId coordinatorId,
    required List<int> groupFingerprint,
  }) =>
      !isClosed && coordinatorId == id && dispatcher.hasGroup(groupFingerprint);

  LocalCoordinatorApi openLocalApi(List<int> groupFingerprint) {
    if (isClosed) throw StateError('Iroh server is closed');
    late final LocalCoordinatorApi api;
    api = LocalCoordinatorApi.attach(
      dispatcher: dispatcher,
      groupFingerprint: Uint8List.fromList(groupFingerprint),
      onClose: (closed) => _localApis.remove(closed),
    );
    _localApis.add(api);
    return api;
  }

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
  }) => _roomManager().issueRoomInvite(
    roomId: roomId,
    expectedParticipantPublicKey: expectedParticipantPublicKey,
    expiresAt: expiresAt,
  );

  Future<RoomSnapshot> revokeRoomInvite({
    required String roomId,
    required String inviteId,
  }) => _roomManager().revokeRoomInvite(roomId: roomId, inviteId: inviteId);

  /// Freezes a complete room and activates its canonical group on the existing
  /// ROAST ALPN without rebinding the endpoint or changing its identity.
  Future<RoomSnapshot> freezeRoom(String roomId) async {
    final manager = _roomManager();
    final room = await manager.freezeRoom(roomId);
    final fingerprint = room.groupFingerprint!;
    if (dispatcher.hasGroup(fingerprint)) return room;
    final handler = ServerApiHandler(
      config: _configForGroup(
        config.server,
        room.groupConfig!,
        config.roomPublicFeeds[room.groupConfig!.id],
      ),
      persistence: persistence,
    );
    await handler.ready;
    dispatcher.addHandler(handler);
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
      final alpn = String.fromCharCodes(connection.alpn);
      final auxiliary =
          alpn == noospherePublicFeedAlpn || alpn == noosphereEnrollmentAlpn;
      // Public/enrollment traffic cannot consume the signer reservation.
      // With a one-connection budget, only signer traffic is admitted.
      if (_connections.length >= config.maxConnections ||
          (auxiliary && _auxiliaryConnections >= config.maxConnections ~/ 2)) {
        connection.close(reason: 'connection limit reached'.codeUnits);
        continue;
      }
      final Future<void> running;
      if (alpn == noosphereEnrollmentAlpn && rooms != null) {
        running = IrohEnrollmentConnectionHandler(
          connection: connection,
          onError: _reportError,
          rooms: rooms!,
          timeout: config.authTimeout,
          maxMessageLength: config.maxMessageLength,
          maxStreams: config.maxStreamsPerConnection,
        ).run();
      } else if (alpn == noospherePublicFeedAlpn) {
        running = PublicFeedConnectionHandler(
          connection: connection,
          onError: _reportError,
          dispatcher: dispatcher,
          config: config,
          signingKey: _signingKey,
        ).run();
      } else if (alpn == config.alpn) {
        running = IrohConnectionHandler(
          connection: connection,
          onError: _reportError,
          dispatcher: dispatcher,
          config: config,
        ).run();
      } else {
        connection.close(reason: 'unsupported ALPN'.codeUnits);
        continue;
      }
      if (auxiliary) _auxiliaryConnections++;
      late final Future<void> handling;
      handling = running
          .catchError((Object error, StackTrace stackTrace) {
            connection.close(reason: 'internal connection failure'.codeUnits);
            _reportError(error, stackTrace);
          })
          .whenComplete(() {
            _connections.remove(handling);
            if (auxiliary) _auxiliaryConnections--;
          });
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
      await Future.wait(
        _localApis.toList().map((api) => api.close()),
        eagerError: false,
      ).timeout(
        config.shutdownTimeout,
        onTimeout: () => throw TimeoutException(
          'local coordinator clients did not close within ${config.shutdownTimeout}',
        ),
      );
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

ServerConfig _configForGroup(
  ServerConfig template,
  GroupConfig group,
  PublicFeedConfig? publicFeed,
) => ServerConfig(
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
  publicFeed: publicFeed,
);

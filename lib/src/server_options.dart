import 'dart:async';

import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:noosphere/wire.dart';
import 'package:noosphere_server/noosphere_server.dart';

/// Supplies the deterministic Iroh identity for one embedded server.
///
/// The application owns mnemonic/seed custody. This callback is invoked once
/// during server setup. For a worker it runs in the host isolate before the
/// derived secret is copied into the worker startup message.
typedef GetIrohSecretKey = FutureOr<SecretKey> Function();

/// Maximum number of simultaneous QUIC streams accepted per client connection.
///
/// This includes the long-lived session/event stream. Four slots accommodate
/// that stream, the client's two RPC slots, and one slot of transition headroom.
const int defaultServerMaxStreamsPerConnection = 4;

/// Typed configuration for an embedded Noosphere server.
final class EmbeddedServerOptions({
  required final ServerConfig serverConfig,
  required final GetIrohSecretKey getIrohSecretKey,
  required final ServerPersistence serverPersistence,
  final RoomPersistence? roomPersistence,
  final ServerApiHandler? handler,
  final IrohRelayConfig? relay,
  final String alpn = noosphereIrohAlpn,
  final Duration authTimeout = IrohConfig.defaultAuthTimeout,
  final Duration rpcTimeout = IrohConfig.defaultRpcTimeout,
  final Duration shutdownTimeout = IrohConfig.defaultShutdownTimeout,
  final int maxMessageLength = defaultMaxMessageLength,
  final int maxConnections = IrohConfig.defaultMaxConnections,
  final int maxStreamsPerConnection = defaultServerMaxStreamsPerConnection,
}) {}

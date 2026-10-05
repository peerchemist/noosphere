import 'package:noosphere/wire.dart';
import 'package:noosphere_server/noosphere_server.dart';

import 'server_identity_store.dart';

/// Maximum number of simultaneous QUIC streams accepted per client connection.
///
/// This includes the long-lived session/event stream. Four slots accommodate
/// that stream, the client's two RPC slots, and one slot of transition headroom.
const int defaultServerMaxStreamsPerConnection = 4;

/// Typed configuration for an embedded Noosphere server.
final class EmbeddedServerOptions({
  required final ServerConfig serverConfig,
  required final ServerIdentityStore identityStore,
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

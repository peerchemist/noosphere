import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/iroh.dart';
import 'package:noosphere_protocol/wire.dart';

import 'server.dart';
import 'public_feed.dart';

extension IrohServerRelayMode on IrohRelayConfig {
  RelayMode toRelayMode() => switch (policy) {
    IrohRelayPolicy.defaultNetwork => RelayMode.n0Default,
    IrohRelayPolicy.disabled => RelayMode.disabled,
    IrohRelayPolicy.staging => RelayMode.staging,
    IrohRelayPolicy.custom => RelayMode.custom(RelayMap.fromUrls(urls)),
  };
}

final class IrohConfig {
  static const defaultAuthTimeout = Duration(seconds: 10);
  static const defaultRpcTimeout = Duration(seconds: 30);
  static const defaultShutdownTimeout = Duration(seconds: 5);
  static const defaultMaxConnections = 128;
  static const defaultMaxStreamsPerConnection = 32;

  IrohConfig({
    required this.server,
    IrohRelayConfig? relay,
    this.alpn = noosphereIrohAlpn,
    this.authTimeout = defaultAuthTimeout,
    this.rpcTimeout = defaultRpcTimeout,
    this.shutdownTimeout = defaultShutdownTimeout,
    this.maxMessageLength = defaultMaxMessageLength,
    this.maxConnections = defaultMaxConnections,
    this.maxStreamsPerConnection = defaultMaxStreamsPerConnection,
    this.nativeLibraryPath,
    Map<String, PublicFeedConfig> roomPublicFeeds = const {},
  }) : relay = relay ?? IrohRelayConfig.defaultNetwork(),
       roomPublicFeeds = Map.unmodifiable(roomPublicFeeds) {
    if (alpn.isEmpty) throw ArgumentError.value(alpn, 'alpn', 'is empty');
    if (alpn == noospherePublicFeedAlpn || alpn == noosphereEnrollmentAlpn) {
      throw ArgumentError.value(
        alpn,
        'alpn',
        'reserved public/enrollment ALPN',
      );
    }
    if (authTimeout <= Duration.zero) {
      throw ArgumentError.value(authTimeout, 'authTimeout');
    }
    if (rpcTimeout <= Duration.zero) {
      throw ArgumentError.value(rpcTimeout, 'rpcTimeout');
    }
    if (shutdownTimeout <= Duration.zero) {
      throw ArgumentError.value(shutdownTimeout, 'shutdownTimeout');
    }
    if (maxMessageLength < 1 || maxMessageLength > 0xffffffff) {
      throw RangeError.range(maxMessageLength, 1, 0xffffffff);
    }
    if (maxConnections < 1) {
      throw RangeError.range(maxConnections, 1, null);
    }
    if (maxStreamsPerConnection < 1) {
      throw RangeError.range(maxStreamsPerConnection, 1, null);
    }
  }

  final ServerConfig server;
  final IrohRelayConfig relay;
  final String alpn;
  final Duration authTimeout;
  final Duration rpcTimeout;
  final Duration shutdownTimeout;
  final int maxMessageLength;
  final int maxConnections;
  final int maxStreamsPerConnection;
  final String? nativeLibraryPath;

  /// Explicit opt-in for frozen room groups, keyed by their private group ID.
  /// Primary-group settings are supplied through [server]. IDs must be unique.
  final Map<String, PublicFeedConfig> roomPublicFeeds;
}

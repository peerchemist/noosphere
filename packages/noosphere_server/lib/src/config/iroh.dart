import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/iroh.dart';
import 'package:noosphere/wire.dart';

import 'server.dart';

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
    this.maxEnvelopeLength = defaultMaxEnvelopeLength,
    this.maxConnections = defaultMaxConnections,
    this.maxStreamsPerConnection = defaultMaxStreamsPerConnection,
    this.nativeLibraryPath,
  }) : relay = relay ?? IrohRelayConfig.defaultNetwork() {
    if (alpn.isEmpty) throw ArgumentError.value(alpn, 'alpn', 'is empty');
    if (authTimeout <= Duration.zero) {
      throw ArgumentError.value(authTimeout, 'authTimeout');
    }
    if (rpcTimeout <= Duration.zero) {
      throw ArgumentError.value(rpcTimeout, 'rpcTimeout');
    }
    if (shutdownTimeout <= Duration.zero) {
      throw ArgumentError.value(shutdownTimeout, 'shutdownTimeout');
    }
    if (maxEnvelopeLength < 1 || maxEnvelopeLength > 0xffffffff) {
      throw RangeError.range(maxEnvelopeLength, 1, 0xffffffff);
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
  final int maxEnvelopeLength;
  final int maxConnections;
  final int maxStreamsPerConnection;
  final String? nativeLibraryPath;
}

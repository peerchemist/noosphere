import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/wire.dart' show defaultMaxMessageLength;
import 'package:noosphere/iroh.dart';

export 'package:noosphere/iroh.dart';

extension IrohClientRelayMode on IrohRelayConfig {
  RelayMode toRelayMode() => switch (policy) {
    IrohRelayPolicy.defaultNetwork => RelayMode.n0Default,
    IrohRelayPolicy.disabled => RelayMode.disabled,
    IrohRelayPolicy.staging => RelayMode.staging,
    IrohRelayPolicy.custom => RelayMode.custom(RelayMap.fromUrls(urls)),
  };
}

final class IrohClientTransportConfig {
  static const defaultConnectTimeout = Duration(seconds: 15);
  static const defaultAuthTimeout = Duration(seconds: 10);
  static const defaultRpcTimeout = Duration(seconds: 30);
  static const defaultMaxConcurrentStreams = 32;

  IrohClientTransportConfig({
    required this.bootstrapAddress,
    required this.pinnedServerId,
    IrohRelayConfig? relay,
    this.alpn = noosphereIrohAlpn,
    this.connectTimeout = defaultConnectTimeout,
    this.authTimeout = defaultAuthTimeout,
    this.rpcTimeout = defaultRpcTimeout,
    this.maxMessageLength = defaultMaxMessageLength,
    this.maxConcurrentStreams = defaultMaxConcurrentStreams,
    this.nativeLibraryPath,
  }) : relay = relay ?? IrohRelayConfig.defaultNetwork() {
    if (alpn.isEmpty) throw ArgumentError.value(alpn, 'alpn', 'is empty');
    if (connectTimeout <= Duration.zero) {
      throw ArgumentError.value(connectTimeout, 'connectTimeout');
    }
    if (authTimeout <= Duration.zero) {
      throw ArgumentError.value(authTimeout, 'authTimeout');
    }
    if (rpcTimeout <= Duration.zero) {
      throw ArgumentError.value(rpcTimeout, 'rpcTimeout');
    }
    if (maxMessageLength < 1 || maxMessageLength > 0xffffffff) {
      throw RangeError.range(maxMessageLength, 1, 0xffffffff);
    }
    if (maxConcurrentStreams < 1) {
      throw RangeError.range(maxConcurrentStreams, 1, null);
    }
  }

  /// Address hints used to find the server. Its embedded ID must match the
  /// independently configured [pinnedServerId] before any connection starts.
  final EndpointAddr bootstrapAddress;
  final EndpointId pinnedServerId;
  final IrohRelayConfig relay;
  final String alpn;
  final Duration connectTimeout;
  final Duration authTimeout;
  final Duration rpcTimeout;
  final int maxMessageLength;
  final int maxConcurrentStreams;
  final String? nativeLibraryPath;
}

import 'package:noosphere/noosphere.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart';

import 'server.dart';

final class IrohConfig with MapWritable {
  static const defaultAuthTimeout = Duration(seconds: 10);
  static const defaultRpcTimeout = Duration(seconds: 30);
  static const defaultShutdownTimeout = Duration(seconds: 5);
  static const defaultMaxConnections = 128;
  static const defaultMaxStreamsPerConnection = 32;

  IrohConfig({
    required this.server,
    required this.secretKeyPath,
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
    if (secretKeyPath.isEmpty) {
      throw ArgumentError.value(secretKeyPath, 'secretKeyPath', 'is empty');
    }
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

  factory IrohConfig.fromMapReader(MapReader reader) {
    final relayReader = reader['relay'];
    final policy = relayReader['policy'].value<String>() ?? 'default-network';
    final relay = switch (policy) {
      'default-network' => IrohRelayConfig.defaultNetwork(),
      'disabled' => IrohRelayConfig.disabled(),
      'staging' => IrohRelayConfig.staging(),
      'custom' => IrohRelayConfig.custom(
        relayReader['urls'].require<List<Object?>>().map((url) {
          if (url is! String) {
            throw MapReaderException('relay.urls must contain strings');
          }
          return url;
        }).toList(),
      ),
      _ => throw MapReaderException('Unknown relay.policy: $policy'),
    };

    return IrohConfig(
      server: ServerConfig.fromMapReader(reader['server']),
      secretKeyPath: reader['secret-key-path'].require(),
      relay: relay,
      alpn: reader['alpn'].value<String>() ?? noosphereIrohAlpn,
      authTimeout:
          reader['timeouts-ms']['auth'].duration() ?? defaultAuthTimeout,
      rpcTimeout: reader['timeouts-ms']['rpc'].duration() ?? defaultRpcTimeout,
      shutdownTimeout:
          reader['timeouts-ms']['shutdown'].duration() ??
          defaultShutdownTimeout,
      maxEnvelopeLength:
          reader['limits']['max-envelope-bytes'].value<int>() ??
          defaultMaxEnvelopeLength,
      maxConnections:
          reader['limits']['max-connections'].value<int>() ??
          defaultMaxConnections,
      maxStreamsPerConnection:
          reader['limits']['max-streams-per-connection'].value<int>() ??
          defaultMaxStreamsPerConnection,
      nativeLibraryPath: reader['native-library-path'].value<String>(),
    );
  }

  factory IrohConfig.fromYaml(String yaml) =>
      IrohConfig.fromMapReader(MapReader.fromYaml(yaml));

  final ServerConfig server;
  final String secretKeyPath;
  final IrohRelayConfig relay;
  final String alpn;
  final Duration authTimeout;
  final Duration rpcTimeout;
  final Duration shutdownTimeout;
  final int maxEnvelopeLength;
  final int maxConnections;
  final int maxStreamsPerConnection;
  final String? nativeLibraryPath;

  @override
  Map<Object, Object> map() {
    final result = <Object, Object>{
      'secret-key-path': secretKeyPath,
      'alpn': alpn,
      'relay': {
        'policy': switch (relay.policy) {
          IrohRelayPolicy.defaultNetwork => 'default-network',
          IrohRelayPolicy.disabled => 'disabled',
          IrohRelayPolicy.staging => 'staging',
          IrohRelayPolicy.custom => 'custom',
        },
        if (relay.urls.isNotEmpty) 'urls': relay.urls,
      },
      'timeouts-ms': {
        'auth': authTimeout.inMilliseconds,
        'rpc': rpcTimeout.inMilliseconds,
        'shutdown': shutdownTimeout.inMilliseconds,
      },
      'limits': {
        'max-envelope-bytes': maxEnvelopeLength,
        'max-connections': maxConnections,
        'max-streams-per-connection': maxStreamsPerConnection,
      },
      'server': server.map(),
    };
    if (nativeLibraryPath case final libraryPath?) {
      result['native-library-path'] = libraryPath;
    }
    return result;
  }
}

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/noosphere.dart' show defaultMaxEnvelopeLength;
import 'package:noosphere_server/noosphere_server.dart';
import 'package:yaml/yaml.dart';

/// File configuration for the standalone server executable only.
final class CliConfig {
  CliConfig._(this.server, this.secretKeyPath, this.stateDirectory);

  factory CliConfig.fromYaml(String source, {required String configPath}) {
    final reader = _MapReader.fromYaml(source);
    return CliConfig._(
      _readIroh(reader),
      reader['secret-key-path'].require<String>(),
      reader['state-directory'].value<String>() ?? '$configPath.state',
    );
  }

  final IrohConfig server;
  final String secretKeyPath;
  final String stateDirectory;
}

GroupConfig _readGroup(_MapReader reader) {
  final keysNode = reader["participant-keys"];

  return GroupConfig(
    id: reader["id"].require(),
    participants: {
      for (final idString in keysNode.keysOf<String>())
        Identifier.fromHex(idString): cl.ECCompressedPublicKey.fromHex(
          keysNode[idString].require(),
        ),
    },
  );
}

ServerConfig _readServer(_MapReader reader) => ServerConfig(
  group: _readGroup(reader["group"]),
  challengeTTL: reader.getTTL("challenge") ?? ServerConfig.defaultChallengeTTL,
  sessionTTL: reader.getTTL("session") ?? ServerConfig.defaultSessionTTL,
  minDkgRequestTTL:
      reader.getTTL("min-dkg-request") ?? ServerConfig.defaultMinDkgRequestTTL,
  maxDkgRequestTTL:
      reader.getTTL("max-dkg-request") ?? ServerConfig.defaultMaxDkgRequestTTL,
  minSignaturesRequestTTL:
      reader.getTTL("min-signatures-request") ??
      ServerConfig.defaultMinSignaturesRequestTTL,
  maxSignaturesRequestTTL:
      reader.getTTL("max-signatures-request") ??
      ServerConfig.defaultMaxSignaturesRequestTTL,
  minCompletedSignaturesTTL:
      reader.getTTL("min-completed-signatures") ??
      ServerConfig.defaultMinCompletedSignaturesTTL,
  ackCacheTTL: reader.getTTL("ack-cache") ?? ServerConfig.defaultAckCacheTTL,
  keepAliveFreq: reader["keep-alive-event-ms"].duration(),
);

IrohConfig _readIroh(_MapReader reader) {
  final relayReader = reader['relay'];
  final policy = relayReader['policy'].value<String>() ?? 'default-network';
  final relay = switch (policy) {
    'default-network' => IrohRelayConfig.defaultNetwork(),
    'disabled' => IrohRelayConfig.disabled(),
    'staging' => IrohRelayConfig.staging(),
    'custom' => IrohRelayConfig.custom(
      relayReader['urls'].require<List<Object?>>().map((url) {
        if (url is! String) {
          throw FormatException('relay.urls must contain strings');
        }
        return url;
      }).toList(),
    ),
    _ => throw FormatException('Unknown relay.policy: $policy'),
  };

  return IrohConfig(
    server: _readServer(reader['server']),
    relay: relay,
    alpn: reader['alpn'].value<String>() ?? noosphereIrohAlpn,
    authTimeout:
        reader['timeouts-ms']['auth'].duration() ??
        IrohConfig.defaultAuthTimeout,
    rpcTimeout:
        reader['timeouts-ms']['rpc'].duration() ?? IrohConfig.defaultRpcTimeout,
    shutdownTimeout:
        reader['timeouts-ms']['shutdown'].duration() ??
        IrohConfig.defaultShutdownTimeout,
    maxEnvelopeLength:
        reader['limits']['max-envelope-bytes'].value<int>() ??
        defaultMaxEnvelopeLength,
    maxConnections:
        reader['limits']['max-connections'].value<int>() ??
        IrohConfig.defaultMaxConnections,
    maxStreamsPerConnection:
        reader['limits']['max-streams-per-connection'].value<int>() ??
        IrohConfig.defaultMaxStreamsPerConnection,
    nativeLibraryPath: reader['native-library-path'].value<String>(),
  );
}

/// Reads a map from YAML
class _MapReader {
  final Object? _value;
  final List<Object> _path;

  _MapReader._(this._value, this._path);
  _MapReader.fromYaml(String yaml) : this._(loadYaml(yaml), []);

  String _joinedPath() => _path.join(".");

  _MapReader operator [](Object key) =>
      _MapReader._(_value is! Map ? null : _value[key], [..._path, key]);

  T? value<T>() => _value is T ? _value : null;

  T require<T>() => value<T>() == null
      ? throw FormatException("No value of type $T at ${_joinedPath()}")
      : value<T>()!;

  Iterable<T> keysOf<T>() => _value == null
      ? Iterable.empty()
      : (_value is! Map || _value.keys.any((v) => v is! T)
            ? throw FormatException("${_joinedPath()} is not map with $T keys")
            : _value.keys.map((k) => k as T));

  Duration? duration() {
    final ms = value<int>();
    return ms == null ? null : Duration(milliseconds: ms);
  }

  Duration? getTTL(String name) => this["ms-lifetimes"][name].duration();
}

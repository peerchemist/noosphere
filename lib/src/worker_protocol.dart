import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:noosphere_roast_server/noosphere_roast_server.dart';

import 'client_options.dart';
import 'server_identity_store.dart';
import 'server_options.dart';

const int workerProtocolVersion = 1;
const int defaultWorkerMaxMessageBytes = 8 * 1024 * 1024;

Map<String, Object?> encodeServerOptions(EmbeddedServerOptions options) {
  if (options.handler != null) {
    throw ArgumentError.value(
      options.handler,
      'server.handler',
      'custom server handlers cannot cross the worker boundary',
    );
  }
  return {
    'serverConfig': options.serverConfig.toBytes(),
    'relay': encodeRelay(options.relay),
    'alpn': options.alpn,
    'authTimeout': options.authTimeout.inMicroseconds,
    'rpcTimeout': options.rpcTimeout.inMicroseconds,
    'shutdownTimeout': options.shutdownTimeout.inMicroseconds,
    'maxEnvelopeLength': options.maxEnvelopeLength,
    'maxConnections': options.maxConnections,
    'maxStreamsPerConnection': options.maxStreamsPerConnection,
  };
}

EmbeddedServerOptions decodeServerOptions(
  Map<Object?, Object?> value,
  ServerIdentityStore identityStore,
) => EmbeddedServerOptions(
  serverConfig: ServerConfig.fromBytes(asBytes(value['serverConfig'])),
  identityStore: identityStore,
  relay: decodeRelay(value['relay']),
  alpn: value['alpn']! as String,
  authTimeout: micros(value['authTimeout']),
  rpcTimeout: micros(value['rpcTimeout']),
  shutdownTimeout: micros(value['shutdownTimeout']),
  maxEnvelopeLength: value['maxEnvelopeLength']! as int,
  maxConnections: value['maxConnections']! as int,
  maxStreamsPerConnection: value['maxStreamsPerConnection']! as int,
);

Map<String, Object?> encodeClientOptions(ClientNodeOptions options) => {
  'group': options.clientConfig.group.toBytes(),
  'participant': options.clientConfig.id.toBytes(),
  'minDkg': options.clientConfig.minDkgRequestTTL.inMicroseconds,
  'maxDkg': options.clientConfig.maxDkgRequestTTL.inMicroseconds,
  'minSignatures': options.clientConfig.minSignaturesTTL.inMicroseconds,
  'maxSignatures': options.clientConfig.maxSignaturesTTL.inMicroseconds,
  'address': {
    'id': options.bootstrapAddress.id.asBytes(),
    'relayUrls': [
      for (final relay in options.bootstrapAddress.relayUrls) relay.value,
    ],
    'ipAddrs': options.bootstrapAddress.ipAddrs,
  },
  'pinnedServerId': options.pinnedServerId.asBytes(),
  'relay': encodeRelay(options.relay),
  'alpn': options.alpn,
  'connectTimeout': options.connectTimeout.inMicroseconds,
  'authTimeout': options.authTimeout.inMicroseconds,
  'rpcTimeout': options.rpcTimeout.inMicroseconds,
  'maxEnvelopeLength': options.maxEnvelopeLength,
  'maxConcurrentStreams': options.maxConcurrentStreams,
  'reconnect': {
    'initialDelay': options.reconnect.initialDelay.inMicroseconds,
    'maxDelay': options.reconnect.maxDelay.inMicroseconds,
    'multiplier': options.reconnect.multiplier,
    'jitter': options.reconnect.jitter,
  },
};

ClientNodeOptions decodeClientOptions(
  Map<Object?, Object?> value,
  ClientStorageInterface storage,
  GetPrivateKey getPrivateKey,
) {
  final address = value['address']! as Map<Object?, Object?>;
  final reconnect = value['reconnect']! as Map<Object?, Object?>;
  return ClientNodeOptions(
    clientConfig: ClientConfig(
      group: GroupConfig.fromBytes(asBytes(value['group'])),
      id: Identifier.fromBytes(asBytes(value['participant'])),
      minDkgRequestTTL: micros(value['minDkg']),
      maxDkgRequestTTL: micros(value['maxDkg']),
      minSignaturesTTL: micros(value['minSignatures']),
      maxSignaturesTTL: micros(value['maxSignatures']),
    ),
    bootstrapAddress: EndpointAddr(
      PublicKey.fromBytes(asBytes(address['id'])),
      relayUrls: [
        for (final url in address['relayUrls']! as List)
          RelayUrl.parse(url as String),
      ],
      ipAddrs: (address['ipAddrs']! as List).cast<String>(),
    ),
    pinnedServerId: PublicKey.fromBytes(asBytes(value['pinnedServerId'])),
    storage: storage,
    getPrivateKey: getPrivateKey,
    relay: decodeRelay(value['relay']),
    alpn: value['alpn']! as String,
    connectTimeout: micros(value['connectTimeout']),
    authTimeout: micros(value['authTimeout']),
    rpcTimeout: micros(value['rpcTimeout']),
    maxEnvelopeLength: value['maxEnvelopeLength']! as int,
    maxConcurrentStreams: value['maxConcurrentStreams']! as int,
    reconnect: IrohReconnectConfig(
      initialDelay: micros(reconnect['initialDelay']),
      maxDelay: micros(reconnect['maxDelay']),
      multiplier: reconnect['multiplier']! as double,
      jitter: reconnect['jitter']! as double,
    ),
  );
}

Map<String, Object?>? encodeRelay(IrohRelayConfig? relay) =>
    relay == null ? null : {'policy': relay.policy.index, 'urls': relay.urls};

IrohRelayConfig? decodeRelay(Object? message) {
  if (message == null) return null;
  final value = message as Map<Object?, Object?>;
  final policy = IrohRelayPolicy.values[value['policy']! as int];
  final urls = (value['urls']! as List).cast<String>();
  return switch (policy) {
    IrohRelayPolicy.defaultNetwork => IrohRelayConfig.defaultNetwork(),
    IrohRelayPolicy.disabled => IrohRelayConfig.disabled(),
    IrohRelayPolicy.staging => IrohRelayConfig.staging(),
    IrohRelayPolicy.custom => IrohRelayConfig.custom(urls),
  };
}

Duration micros(Object? value) => Duration(microseconds: value! as int);

Uint8List asBytes(Object? value) => value is Uint8List
    ? Uint8List.fromList(value)
    : Uint8List.fromList((value! as List).cast<int>());

int approximateMessageBytes(Object? value) => switch (value) {
  null => 0,
  final String value => value.length * 2,
  final Uint8List value => value.length,
  final List value => value.fold<int>(
    0,
    (sum, item) => sum + approximateMessageBytes(item),
  ),
  final Map value => value.entries.fold<int>(
    0,
    (sum, entry) =>
        sum +
        approximateMessageBytes(entry.key) +
        approximateMessageBytes(entry.value),
  ),
  _ => 8,
};

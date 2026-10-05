import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_server/noosphere_server.dart';

import '../client_options.dart';
import '../server_options.dart';

Future<Map<String, Object?>> encodeServerOptions(
  EmbeddedServerOptions options,
) async {
  if (options.handler != null) {
    throw ArgumentError.value(
      options.handler,
      'server.handler',
      'custom server handlers cannot cross the worker boundary',
    );
  }
  final secretKey = await options.getIrohSecretKey();
  return {
    'serverConfig': options.serverConfig.toBytes(),
    'irohSecretKey': secretKey.toBytes(),
    'roomPersistence': options.roomPersistence != null,
    'relay': encodeRelay(options.relay),
    'alpn': options.alpn,
    'authTimeout': options.authTimeout.inMicroseconds,
    'rpcTimeout': options.rpcTimeout.inMicroseconds,
    'shutdownTimeout': options.shutdownTimeout.inMicroseconds,
    'maxMessageLength': options.maxMessageLength,
    'maxConnections': options.maxConnections,
    'maxStreamsPerConnection': options.maxStreamsPerConnection,
  };
}

EmbeddedServerOptions decodeServerOptions(
  Map<Object?, Object?> value,
  ServerPersistence serverPersistence,
  RoomPersistence roomPersistence,
) => EmbeddedServerOptions(
  serverConfig: ServerConfig.fromBytes(asBytes(value['serverConfig'])),
  getIrohSecretKey: () => SecretKey.fromBytes(asBytes(value['irohSecretKey'])),
  serverPersistence: serverPersistence,
  roomPersistence: value['roomPersistence'] == true ? roomPersistence : null,
  relay: decodeRelay(value['relay']),
  alpn: value['alpn']! as String,
  authTimeout: micros(value['authTimeout']),
  rpcTimeout: micros(value['rpcTimeout']),
  shutdownTimeout: micros(value['shutdownTimeout']),
  maxMessageLength: value['maxMessageLength']! as int,
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
  'address': encodeEndpointAddress(options.bootstrapAddress),
  'pinnedServerId': options.pinnedServerId.asBytes(),
  'relay': encodeRelay(options.relay),
  'alpn': options.alpn,
  'connectTimeout': options.connectTimeout.inMicroseconds,
  'authTimeout': options.authTimeout.inMicroseconds,
  'rpcTimeout': options.rpcTimeout.inMicroseconds,
  'maxMessageLength': options.maxMessageLength,
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
    bootstrapAddress: decodeEndpointAddress(
      value['address']! as Map<Object?, Object?>,
    ),
    pinnedServerId: PublicKey.fromBytes(asBytes(value['pinnedServerId'])),
    storage: storage,
    getPrivateKey: getPrivateKey,
    relay: decodeRelay(value['relay']),
    alpn: value['alpn']! as String,
    connectTimeout: micros(value['connectTimeout']),
    authTimeout: micros(value['authTimeout']),
    rpcTimeout: micros(value['rpcTimeout']),
    maxMessageLength: value['maxMessageLength']! as int,
    maxConcurrentStreams: value['maxConcurrentStreams']! as int,
    reconnect: IrohReconnectConfig(
      initialDelay: micros(reconnect['initialDelay']),
      maxDelay: micros(reconnect['maxDelay']),
      multiplier: reconnect['multiplier']! as double,
      jitter: reconnect['jitter']! as double,
    ),
  );
}

Map<String, Object?> encodeEndpointAddress(EndpointAddr address) => {
  'id': address.id.asBytes(),
  'relayUrls': [for (final relay in address.relayUrls) relay.value],
  'ipAddrs': address.ipAddrs,
};

EndpointAddr decodeEndpointAddress(Map<Object?, Object?> value) => EndpointAddr(
  PublicKey.fromBytes(asBytes(value['id'])),
  relayUrls: [
    for (final url in value['relayUrls']! as List)
      RelayUrl.parse(url as String),
  ],
  ipAddrs: (value['ipAddrs']! as List).cast<String>(),
);

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

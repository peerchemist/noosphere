import 'dart:async';
import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_server/noosphere_server.dart';

import 'client_options.dart';
import 'server_identity_store.dart';
import 'server_options.dart';
import 'worker_models.dart';

// Host and worker ship together; R&D changes revise this baseline in place.
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
    'roomPersistence': options.roomPersistence != null,
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
  ServerPersistence serverPersistence,
  RoomPersistence roomPersistence,
) => EmbeddedServerOptions(
  serverConfig: ServerConfig.fromBytes(asBytes(value['serverConfig'])),
  identityStore: identityStore,
  serverPersistence: serverPersistence,
  roomPersistence: value['roomPersistence'] == true ? roomPersistence : null,
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
  'address': encodeEndpointAddress(options.bootstrapAddress),
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
  final WorkerCoordinatorAddress value => _workerDtoBytes(value),
  final WorkerDkgStatus value => _workerDtoBytes(value),
  final WorkerKeyInfo value => _workerDtoBytes(value),
  final WorkerSigningRequest value => _workerDtoBytes(value),
  final NoosphereWorkerSnapshot value => _workerDtoBytes(value),
  final NoosphereWorkerEvent value => _workerDtoBytes(value),
  _ => 8,
};

int _workerDtoBytes(Object value) => switch (value) {
  final WorkerCoordinatorAddress value => _strings([
    value.id,
    ...value.relayUrls,
    ...value.ipAddrs,
  ]),
  final WorkerDkgStatus value =>
    _strings([
          value.name,
          value.description,
          value.creator,
          value.stage,
          ...value.completedParticipants,
        ]) +
        value.proposalBytes.length +
        16,
  final WorkerKeyInfo value => _strings([
    value.groupKeyHex,
    value.name,
    value.description,
  ]),
  final WorkerSigningRequest value =>
    _strings([value.creator, value.status]) +
        value.id.length +
        value.proposalBytes.length +
        8,
  final NoosphereWorkerSnapshot value =>
    _strings([value.setupId, ...value.onlineParticipants]) +
        (value.coordinator == null ? 0 : _workerDtoBytes(value.coordinator!)) +
        value.dkgs.fold<int>(0, (sum, item) => sum + _workerDtoBytes(item)) +
        value.signingRequests.fold<int>(
          0,
          (sum, item) => sum + _workerDtoBytes(item),
        ) +
        value.keys.fold<int>(0, (sum, item) => sum + _workerDtoBytes(item)) +
        24,
  final WorkerSnapshotEvent value => _workerDtoBytes(value.snapshot),
  final WorkerParticipantEvent value => _strings([
    value.setupId,
    value.participant,
  ]),
  final WorkerDkgEvent value =>
    _strings([value.setupId, ?value.failure]) + _workerDtoBytes(value.status),
  final WorkerSigningRequestEvent value =>
    _strings([value.setupId]) + _workerDtoBytes(value.request),
  final WorkerSigningResultEvent value =>
    _strings([value.setupId, value.creator]) +
        value.requestId.length +
        value.proposalBytes.length +
        value.signatures.fold<int>(0, (sum, bytes) => sum + bytes.length),
  final WorkerKeyUpdatedEvent value =>
    _strings([value.setupId]) + _workerDtoBytes(value.key),
  final WorkerSessionReplacedEvent value => _strings([value.setupId]),
  final WorkerFailureEvent value => _strings([
    value.setupId,
    value.operation,
    value.message,
  ]),
  _ => throw ArgumentError.value(value, 'value', 'not a worker DTO'),
};

int _strings(Iterable<String> values) =>
    values.fold(0, (sum, value) => sum + value.length * 2);

Map<String, Object?> encodeSignaturesNonces(SignaturesNonces nonces) => {
  'expiryMicros': nonces.expiry.time.microsecondsSinceEpoch,
  'values': [
    for (final entry in nonces.map.entries)
      {'index': entry.key, 'nonce': entry.value.toBytes()},
  ],
};

SignaturesNonces decodeSignaturesNonces(Map<Object?, Object?> value) =>
    SignaturesNonces(
      {
        for (final item in value['values']! as List)
          (item as Map<Object?, Object?>)['index']! as int:
              SigningNonces.fromBytes(asBytes(item['nonce'])),
      },
      Expiry.fromTime(
        DateTime.fromMicrosecondsSinceEpoch(value['expiryMicros']! as int),
      ),
    );

/// Minimal FIFO used where protocol or storage mutations must not overlap.
final class SerialExecutor {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

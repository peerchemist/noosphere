import 'dart:typed_data';

import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

ClientNodeOptions nativeTestClientOptions({
  required GroupConfig group,
  required Identifier participant,
  required ECPrivateKey key,
  required EndpointAddr address,
  ClientStorageInterface? storage,
}) => ClientNodeOptions(
  clientConfig: ClientConfig(group: group, id: participant),
  bootstrapAddress: address,
  pinnedServerId: address.id,
  relay: IrohRelayConfig.disabled(),
  storage: storage ?? InMemoryClientStorage(),
  getPrivateKey: (_) async => key,
  reconnect: const IrohReconnectConfig(
    initialDelay: Duration(milliseconds: 100),
    maxDelay: Duration(seconds: 1),
    jitter: 0,
  ),
);

Future<EndpointAddr> reachableTestAddress(IrohServer server) async {
  final current = server.address;
  if (current.ipAddrs.isNotEmpty || current.relayUrls.isNotEmpty) {
    return current;
  }
  return server.endpoint
      .watchAddr()
      .firstWhere(
        (address) => address.ipAddrs.isNotEmpty || address.relayUrls.isNotEmpty,
      )
      .timeout(const Duration(seconds: 15));
}

final class MemoryIdentityStore implements ServerIdentityStore {
  Uint8List? _secret;
  int writes = 0;

  @override
  Future<Uint8List?> read() async =>
      _secret == null ? null : Uint8List.fromList(_secret!);

  @override
  Future<void> write(Uint8List secret) async {
    writes++;
    _secret = Uint8List.fromList(secret);
  }
}

final class MemoryServerPersistence implements ServerPersistence {
  final _delegate = InMemoryServerPersistence();

  @override
  Future<ServerStateSnapshot?> load(String groupId) => _delegate.load(groupId);

  @override
  Future<void> write(String groupId, ServerStateSnapshot state) =>
      _delegate.write(groupId, state);
}

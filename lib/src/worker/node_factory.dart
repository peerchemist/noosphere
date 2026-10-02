import 'package:iroh_flutter/iroh_flutter.dart' show EndpointAddr;
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart';

import '../client_options.dart';
import '../iroh_node.dart';
import '../server_options.dart';

/// Injectable lifecycle boundary. Implementations own all native handles.
abstract interface class WorkerNode {
  EndpointAddr? get serverAddress;
  bool get serverRunning;
  Future<NoosphereServerTermination>? get serverDone;
  WorkerClientConnection? get client;
  Future<void> close();
  Future<void> stopServingForTesting();
}

abstract interface class WorkerClientConnection {
  Client get current;
  Stream<Client> get sessions;
  bool get isConnected;
  void updateTransportConfig(IrohClientTransportConfig config);
}

typedef WorkerNodeFactory = Future<WorkerNode> Function({
  EmbeddedServerOptions? server,
  ClientNodeOptions? client,
});

Future<WorkerNode> startWorkerNode({
  EmbeddedServerOptions? server,
  ClientNodeOptions? client,
}) async => _NativeWorkerNode(
  await NoosphereNode.startInitialized(server: server, client: client),
);

final class _NativeWorkerNode(this.node) implements WorkerNode {
  final NoosphereNode node;
  @override
  EndpointAddr? get serverAddress => node.serverAddress;
  @override
  bool get serverRunning => node.serverRunning;
  @override
  Future<NoosphereServerTermination>? get serverDone => node.serverDone;
  @override
  late final WorkerClientConnection? client = node.client == null
      ? null
      : _NativeClientConnection(node.client!);
  @override
  Future<void> close() => node.close();
  @override
  Future<void> stopServingForTesting() => node.server!.close();
}

final class _NativeClientConnection(this.client)
    implements WorkerClientConnection {
  final ReconnectingIrohClient client;
  @override
  Client get current => client.current;
  @override
  Stream<Client> get sessions => client.sessions;
  @override
  bool get isConnected => client.isConnected;
  @override
  void updateTransportConfig(IrohClientTransportConfig config) =>
      client.updateTransportConfig(config);
}

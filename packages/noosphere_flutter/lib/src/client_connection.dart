import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart';

/// Active Noosphere participant connection, backed by either Iroh or a
/// coordinator hosted in the same process.
abstract interface class RuntimeClientConnection {
  Client get current;
  Stream<Client> get sessions;
  bool get isConnected;
  bool get isLocal;
  IrohClientTransportConfig get transportConfig;

  void updateTransportConfig(IrohClientTransportConfig config);

  Future<void> close();
}

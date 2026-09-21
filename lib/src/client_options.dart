import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:noosphere_roast_client/iroh_protocol.dart';
import 'package:noosphere_roast_server/noosphere_roast_server.dart';

/// Typed configuration for a reconnecting Noosphere client endpoint.
final class ClientNodeOptions({
  required final ClientConfig clientConfig,
  required final EndpointAddr bootstrapAddress,
  required final EndpointId pinnedServerId,
  required final ClientStorageInterface storage,
  required final GetPrivateKey getPrivateKey,
  final IrohRelayConfig? relay,
  final String alpn = noosphereIrohAlpn,
  final Duration connectTimeout =
      IrohClientTransportConfig.defaultConnectTimeout,
  final Duration authTimeout = IrohClientTransportConfig.defaultAuthTimeout,
  final Duration rpcTimeout = IrohClientTransportConfig.defaultRpcTimeout,
  final int maxEnvelopeLength = defaultMaxEnvelopeLength,
  final int maxConcurrentStreams =
      IrohClientTransportConfig.defaultMaxConcurrentStreams,
  final IrohReconnectConfig reconnect = const IrohReconnectConfig(),
}) {
  IrohClientTransportConfig toTransportConfig() => IrohClientTransportConfig(
    bootstrapAddress: bootstrapAddress,
    pinnedServerId: pinnedServerId,
    relay: relay,
    alpn: alpn,
    connectTimeout: connectTimeout,
    authTimeout: authTimeout,
    rpcTimeout: rpcTimeout,
    maxEnvelopeLength: maxEnvelopeLength,
    maxConcurrentStreams: maxConcurrentStreams,
  );
}

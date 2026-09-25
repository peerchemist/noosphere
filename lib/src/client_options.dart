import 'package:iroh_flutter/iroh_flutter.dart';
import 'package:noosphere/noosphere.dart';
import 'package:noosphere_server/noosphere_server.dart';

/// Maximum number of RPC streams a Flutter client opens concurrently.
///
/// The long-lived session/event stream is separate and does not count toward
/// this limit. Two RPC slots allow one domain operation and one session or
/// acknowledgement operation to make progress at the same time.
const int defaultClientMaxConcurrentStreams = 2;

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
  final int maxConcurrentStreams = defaultClientMaxConcurrentStreams,
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

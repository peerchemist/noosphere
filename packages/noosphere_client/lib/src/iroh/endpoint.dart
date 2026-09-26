import 'package:iroh_quic/iroh_quic.dart';

import 'config.dart';

final class PinnedEndpointMismatchException implements Exception {
  const PinnedEndpointMismatchException({
    required this.expected,
    required this.actual,
  });

  final EndpointId expected;
  final EndpointId actual;

  @override
  String toString() =>
      'PinnedEndpointMismatchException(expected: ${expected.toZ32()}, '
      'actual: ${actual.toZ32()})';
}

/// Owns a newly bound endpoint or borrows one managed by the application.
final class IrohClientEndpoint {
  IrohClientEndpoint._(this.endpoint, this.ownsEndpoint);

  static Future<IrohClientEndpoint> bind(
    IrohClientTransportConfig config, {
    SecretKey? secretKey,
  }) async {
    await Iroh.init(libraryPath: config.nativeLibraryPath);
    final endpoint = await Endpoint.bind(
      secretKey: secretKey,
      relayMode: config.relay.toRelayMode(),
    );
    return IrohClientEndpoint._(endpoint, true);
  }

  factory IrohClientEndpoint.borrowed(Endpoint endpoint) =>
      IrohClientEndpoint._(endpoint, false);

  final Endpoint endpoint;
  final bool ownsEndpoint;
  bool _closed = false;
  Future<void>? _closing;

  bool get isClosed => _closed;

  Future<Connection> connect(IrohClientTransportConfig config) async {
    if (_closed) throw StateError('client endpoint wrapper is closed');
    if (config.bootstrapAddress.id != config.pinnedServerId) {
      throw PinnedEndpointMismatchException(
        expected: config.pinnedServerId,
        actual: config.bootstrapAddress.id,
      );
    }

    final connection = await endpoint
        .connect(config.bootstrapAddress, config.alpn.codeUnits)
        .timeout(config.connectTimeout);
    if (connection.remoteId != config.pinnedServerId) {
      final actual = connection.remoteId;
      connection.close(reason: 'endpoint ID mismatch'.codeUnits);
      throw PinnedEndpointMismatchException(
        expected: config.pinnedServerId,
        actual: actual,
      );
    }
    return connection;
  }

  Future<void> close() {
    _closed = true;
    if (!ownsEndpoint) return Future.value();
    return _closing ??= endpoint.close();
  }
}

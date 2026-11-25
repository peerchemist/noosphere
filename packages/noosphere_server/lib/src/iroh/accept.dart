import 'package:iroh_quic/iroh_quic.dart' show IrohAcceptException;

/// Returns the next successful handshake, or null after the listener closes.
/// A handshake failure affects only that connection. Listener errors escape
/// so the host can decide whether to restart the endpoint.
Future<T?> nextAcceptedConnection<I extends Object, T extends Object>({
  required Future<I?> Function() nextIncoming,
  required Future<T> Function(I) accept,
  required bool Function() isClosed,
  required void Function(Object error, StackTrace stackTrace) onHandshakeError,
}) async {
  while (!isClosed()) {
    final incoming = await nextIncoming();
    if (incoming == null) return null;
    try {
      return await accept(incoming);
    } on IrohAcceptException catch (error, stackTrace) {
      if (!isClosed()) onHandshakeError(error, stackTrace);
    }
  }
  return null;
}

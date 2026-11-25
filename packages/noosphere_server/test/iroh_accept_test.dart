import 'package:iroh_quic/iroh_quic.dart' show IrohAcceptException;
import 'package:noosphere_server/src/iroh/accept.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a failed handshake leaves the listener ready for the next peer',
    () async {
      const failure = IrohAcceptException('simulated handshake failure');
      final failures = <Object>[];
      final incoming = [1, 2].iterator;

      final connection = await nextAcceptedConnection(
        nextIncoming: () async => incoming.moveNext() ? incoming.current : null,
        accept: (attempt) async => attempt == 1 ? throw failure : 'connected',
        isClosed: () => false,
        onHandshakeError: (error, _) => failures.add(error),
      );

      expect(connection, 'connected');
      expect(failures, [failure]);
    },
  );

  test('listener errors propagate to the coordinator supervisor', () async {
    const failure = IrohAcceptException('simulated listener failure');
    await expectLater(
      nextAcceptedConnection<int, int>(
        nextIncoming: () async => throw failure,
        accept: (incoming) async => incoming,
        isClosed: () => false,
        onHandshakeError: (_, _) => fail('Listener failure is not a handshake'),
      ),
      throwsA(same(failure)),
    );
  });
}

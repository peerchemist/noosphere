import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/domain.dart';
import 'package:test/test.dart';

void main() {
  late SigningCommitment commitment;
  setUpAll(() async {
    await loadFrosty();
    commitment = SigningCommitment.fromBytes(
      cl.hexToBytes(
        '00230f8ab302de8e5cc1582be4b6b5a1e8be2d482dabe86d2e3368d1a98785fb'
        '27bfcdfdf72902ec04d9f8bb9b423927defe454295d07e0609c029f6c6778a218'
        'fe9d575c125d9',
      ),
    );
  });

  test('rejects indexes outside the unsigned 16-bit wire range', () {
    for (final sigI in [-1, 0x10000]) {
      expect(
        () => SignatureReply(sigI: sigI, nextCommitment: commitment),
        throwsRangeError,
      );
    }
  });

  test('round-trips indexes at the unsigned 16-bit wire boundaries', () {
    for (final sigI in [0, 0xffff]) {
      final reply = SignatureReply(sigI: sigI, nextCommitment: commitment);

      final decoded = SignatureReply.fromBytes(reply.toBytes());

      expect(decoded.sigI, sigI);
      expect(decoded.nextCommitment.toBytes(), commitment.toBytes());
      expect(decoded.share, isNull);
    }
  });
}

import 'package:coinlib/coinlib.dart';
import 'package:noosphere/domain.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(loadFrosty);

  test('builds the unhardened threshold BIP-86 hierarchy', () {
    expect(thresholdBip86DerivationPath(coinType: 6, account: 2), [
      86,
      6,
      2,
      0,
      0,
    ]);
    expect(
      () => thresholdBip86DerivationPath(coinType: 6, account: HDKey.hardenBit),
      throwsRangeError,
    );
  });

  test('derives the same group key as Frosty', () {
    final groupKey = ECCompressedPublicKey.fromPubkey(
      ECPrivateKey.fromHex('01'.padLeft(64, '0')).pubkey,
    );
    final path = thresholdBip86DerivationPath(coinType: 6, account: 2);
    final expected = path.fold(
      HDGroupKeyInfo.master(groupKey: groupKey, threshold: 2),
      (key, index) => key.derive(index),
    );

    final actual = deriveThresholdGroupKey(
      groupKey: groupKey,
      threshold: 2,
      path: path,
    );

    expect(actual.groupKey, expected.groupKey);
    expect(actual.hdInfo.toBytes(), expected.hdInfo.toBytes());
  });
}

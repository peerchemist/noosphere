import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/src/iroh_identity.dart';

void main() {
  test('uses the fixed BIP-85 32-byte entropy path', () {
    expect(irohIdentityDerivationPath(0), "m/83696968'/128169'/32'/0'");
    expect(irohIdentityDerivationPath(7), "m/83696968'/128169'/32'/7'");
    expect(() => irohIdentityDerivationPath(-1), throwsRangeError);
    expect(() => irohIdentityDerivationPath(0x80000000), throwsRangeError);
  });

  test('derives a stable Iroh secret from a BIP-39 seed', () {
    final seed = Uint8List.fromList(List<int>.generate(64, (index) => index));

    final first = deriveIrohSecretKeyFromBip39Seed(seed);
    final second = deriveIrohSecretKeyFromBip39Seed(seed);

    expect(
      _hex(first.toBytes()),
      'c3de6a25201465fd8e915622739c18f4ec4319c08196790ba8df405e525db987',
    );
    expect(second.toBytes(), orderedEquals(first.toBytes()));
    expect(
      deriveIrohSecretKeyFromBip39Seed(seed, index: 1).toBytes(),
      isNot(orderedEquals(first.toBytes())),
    );
  });

  test('requires the 512-bit output of BIP-39', () {
    expect(
      () => deriveIrohSecretKeyFromBip39Seed(Uint8List(32)),
      throwsArgumentError,
    );
  });
}

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

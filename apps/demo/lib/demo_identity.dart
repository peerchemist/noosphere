import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:crypto/crypto.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

/// Public, well-known BIP-39 test vector. Never use this mnemonic for funds.
const demoTestMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon about';

const demoTestMnemonicPassphrase = '';
const demoIrohIdentityIndex = 0;

/// Peercoin BIP-44 external-chain keys used as the two demo identities.
const demoParticipantDerivationPaths = ["m/44'/6'/0'/0/0", "m/44'/6'/0'/0/1"];

// BIP-39 seed derivation for the fixed ASCII demo vector.
Uint8List _deriveDemoSeed() {
  final hmac = Hmac(sha512, utf8.encode(demoTestMnemonic));
  final salt = Uint8List.fromList([
    ...utf8.encode('mnemonic$demoTestMnemonicPassphrase'),
    0,
    0,
    0,
    1,
  ]);
  var block = Uint8List.fromList(hmac.convert(salt).bytes);
  final seed = Uint8List.fromList(block);
  for (var iteration = 1; iteration < 2048; iteration++) {
    block = Uint8List.fromList(hmac.convert(block).bytes);
    for (var i = 0; i < seed.length; i++) {
      seed[i] ^= block[i];
    }
  }
  return seed;
}

/// All long-lived demo identities derived from [demoTestMnemonic].
final class DemoIdentityMaterial {
  DemoIdentityMaterial._({
    required this.irohSecretKey,
    required this.participantKeys,
  });

  factory DemoIdentityMaterial.derive() {
    final seed = _deriveDemoSeed();
    try {
      final root = cl.HDPrivateKey.fromSeed(seed);
      return DemoIdentityMaterial._(
        irohSecretKey: deriveIrohSecretKeyFromBip39Seed(
          seed,
          index: demoIrohIdentityIndex,
        ),
        participantKeys: List.unmodifiable([
          for (final path in demoParticipantDerivationPaths)
            root.derivePath(path).privateKey,
        ]),
      );
    } finally {
      // Limit how long the full wallet seed remains in this demo's memory.
      seed.fillRange(0, seed.length, 0);
    }
  }

  final SecretKey irohSecretKey;
  final List<cl.ECPrivateKey> participantKeys;
}

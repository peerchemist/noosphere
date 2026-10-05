import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_flutter/noosphere_flutter.dart';

/// Public, well-known BIP-39 test vector. Never use this mnemonic for funds.
const demoTestMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon about';

const demoTestMnemonicPassphrase = '';
const demoIrohIdentityIndex = 0;

/// Peercoin BIP-44 external-chain keys used as the two demo identities.
const demoParticipantDerivationPaths = ["m/44'/6'/0'/0/0", "m/44'/6'/0'/0/1"];

/// All long-lived demo identities derived from [demoTestMnemonic].
final class DemoIdentityMaterial {
  DemoIdentityMaterial._({
    required this.irohSecretKey,
    required this.participantKeys,
  });

  factory DemoIdentityMaterial.derive() {
    final seed = _deriveDemoBip39Seed();
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

/// BIP-39's PBKDF2-HMAC-SHA512 step for this ASCII-only public test vector.
///
/// General wallet code must also apply NFKD normalization to arbitrary mnemonic
/// and passphrase input before this step. That is unnecessary for these fixed
/// ASCII constants.
Uint8List _deriveDemoBip39Seed() {
  final password = Uint8List.fromList(utf8.encode(demoTestMnemonic));
  final salt = Uint8List.fromList(
    utf8.encode('mnemonic$demoTestMnemonicPassphrase'),
  );
  var round = cl.hmacSha512(
    password,
    Uint8List.fromList([...salt, 0, 0, 0, 1]),
  );
  final seed = Uint8List.fromList(round);
  for (var iteration = 1; iteration < 2048; iteration++) {
    round = cl.hmacSha512(password, round);
    for (var byte = 0; byte < seed.length; byte++) {
      seed[byte] ^= round[byte];
    }
  }
  return seed;
}

import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_flutter/noosphere_flutter.dart';

/// Public, well-known BIP-39 test vector. Never use this mnemonic for funds.
const demoTestMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon about';

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
    final mnemonic = Mnemonic.fromSentence(
      demoTestMnemonic,
      Language.english,
      passphrase: demoTestMnemonicPassphrase,
    );
    final seed = Uint8List.fromList(mnemonic.seed);
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

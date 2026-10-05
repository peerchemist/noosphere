import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart';
import 'package:iroh_flutter/iroh_flutter.dart';

/// BIP-85 path used for a 32-byte Iroh identity at [index].
///
/// `m/83696968'/128169'/32'/index'` is BIP-85's standardized raw-entropy
/// application. Every component is hardened, so the derived endpoint identity
/// cannot expose the wallet's parent key hierarchy.
String irohIdentityDerivationPath(int index) {
  RangeError.checkValueInInterval(index, 0, 0x7fffffff, 'index');
  return "m/83696968'/128169'/32'/$index'";
}

/// Derives a deterministic Iroh identity from a 64-byte BIP-39 seed.
///
/// The mnemonic and its optional passphrase remain application-owned. Pass the
/// 512-bit seed produced by BIP-39, not mnemonic text or its original entropy.
/// The default [index] is zero; use a different stable index when one mnemonic
/// intentionally owns more than one independent Iroh endpoint.
///
/// This implements BIP-85's 32-byte raw-entropy application and treats that
/// entropy as Iroh's Ed25519 secret seed. Every BIP-32 step is hardened and is
/// implemented without native elliptic-curve bindings, so it is safe to call
/// from a worker host isolate.
SecretKey deriveIrohSecretKeyFromBip39Seed(
  Uint8List bip39Seed, {
  int index = 0,
}) {
  if (bip39Seed.length != 64) {
    throw ArgumentError.value(
      bip39Seed.length,
      'bip39Seed',
      'must contain the 64-byte seed produced by BIP-39',
    );
  }

  var node = _Bip32PrivateNode.master(bip39Seed);
  for (final component in [83696968, 128169, 32, index]) {
    node = node.deriveHardened(component);
  }
  final entropy = hmacSha512(
    Uint8List.fromList(utf8.encode('bip-entropy-from-k')),
    node.key,
  );
  return SecretKey.fromBytes(entropy.sublist(0, SecretKey.lengthBytes));
}

final _secp256k1Order = BigInt.parse(
  'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
  radix: 16,
);

final class _Bip32PrivateNode {
  const _Bip32PrivateNode(this.key, this.chainCode);

  factory _Bip32PrivateNode.master(Uint8List seed) {
    final digest = hmacSha512(
      Uint8List.fromList(utf8.encode('Bitcoin seed')),
      seed,
    );
    return _fromDigest(digest, operation: 'master-key derivation');
  }

  final Uint8List key;
  final Uint8List chainCode;

  _Bip32PrivateNode deriveHardened(int index) {
    RangeError.checkValueInInterval(index, 0, 0x7fffffff, 'index');
    final childNumber = index | 0x80000000;
    final digest = hmacSha512(
      chainCode,
      Uint8List.fromList([0, ...key, ..._uint32(childNumber)]),
    );
    final tweak = _bigInt(digest.sublist(0, 32));
    if (tweak >= _secp256k1Order) {
      throw StateError('BIP-32 produced an invalid hardened child key.');
    }
    final child = (tweak + _bigInt(key)) % _secp256k1Order;
    if (child == BigInt.zero) {
      throw StateError('BIP-32 produced an invalid hardened child key.');
    }
    return _Bip32PrivateNode(
      _serialize256(child),
      Uint8List.fromList(digest.sublist(32)),
    );
  }

  static _Bip32PrivateNode _fromDigest(
    Uint8List digest, {
    required String operation,
  }) {
    final key = Uint8List.fromList(digest.sublist(0, 32));
    final scalar = _bigInt(key);
    if (scalar == BigInt.zero || scalar >= _secp256k1Order) {
      throw StateError('BIP-32 produced an invalid $operation.');
    }
    return _Bip32PrivateNode(key, Uint8List.fromList(digest.sublist(32)));
  }
}

BigInt _bigInt(Iterable<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

Uint8List _serialize256(BigInt value) {
  final bytes = Uint8List(32);
  for (var index = bytes.length - 1; index >= 0; index--) {
    bytes[index] = (value & BigInt.from(0xff)).toInt();
    value >>= 8;
  }
  return bytes;
}

List<int> _uint32(int value) => [
  value >> 24,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

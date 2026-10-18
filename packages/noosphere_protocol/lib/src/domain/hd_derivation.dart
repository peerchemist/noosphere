import 'package:coinlib/coinlib.dart';
import 'package:frosty/frosty.dart';

const int thresholdBip86Purpose = 86;

/// Returns the unhardened threshold-key equivalent of a BIP-86 path.
///
/// FROST has no aggregate private key, so hardened BIP-32 derivation is not
/// possible. The path retains BIP-86's purpose, coin, account, change and
/// address-index hierarchy while deriving every component from the DKG group
/// key as an unhardened child.
List<int> thresholdBip86DerivationPath({
  required int coinType,
  required int account,
  int change = 0,
  int addressIndex = 0,
}) {
  final path = [thresholdBip86Purpose, coinType, account, change, addressIndex];
  for (final index in path) {
    HDKeyInfo.checkIndex(index);
  }
  return List.unmodifiable(path);
}

/// Derives any FROST HD key information through an unhardened path.
T deriveThresholdHdKey<T extends HDDerivableInfo>(T root, Iterable<int> path) {
  var derived = root;
  for (final index in path) {
    HDKeyInfo.checkIndex(index);
    derived = derived.derive(index) as T;
  }
  return derived;
}

/// Derives a public FROST group key from its DKG root.
HDGroupKeyInfo deriveThresholdGroupKey({
  required ECCompressedPublicKey groupKey,
  required int threshold,
  required Iterable<int> path,
}) => deriveThresholdHdKey(
  HDGroupKeyInfo.master(groupKey: groupKey, threshold: threshold),
  path,
);

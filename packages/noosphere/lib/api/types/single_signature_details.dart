import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common/serial.dart';
import 'package:collection/collection.dart';
import 'package:frosty/frosty.dart';

import '../hd_derivation.dart';

/// Details for a single signature in a signatures request.
///
/// Consumers should determine if they desire to make these signatures for the
/// given details.
class SingleSignatureDetails with cl.Writable, NoosphereWritable {
  /// The message hash to be signed and the MAST tweak.
  final SignDetails signDetails;

  /// The master group key to use
  final cl.ECCompressedPublicKey groupKey;

  /// The unhardened-only derivation path to obtain the key necessary for
  /// signing
  final List<int> hdDerivation;

  SingleSignatureDetails({
    required SignDetails signDetails,
    required this.groupKey,
    required List<int> hdDerivation,
  }) : signDetails = _ImmutableSignDetails(signDetails),
       hdDerivation = List.unmodifiable(hdDerivation) {
    RangeError.checkValueInInterval(
      hdDerivation.length,
      0,
      0xff,
      "hdDerivation",
      "is too long",
    );
    for (final i in hdDerivation) {
      HDKeyInfo.checkIndex(i);
    }
  }

  SingleSignatureDetails.fromReader(cl.BytesReader reader)
    : this(
        signDetails: SignDetails.fromReader(reader),
        groupKey: cl.ECCompressedPublicKey(reader.readSlice(33)),
        hdDerivation: List.generate(
          reader.readUInt8(),
          (_) => reader.readUInt32(),
        ),
      );

  /// Convenience constructor to construct from serialised [bytes].
  factory SingleSignatureDetails.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SingleSignatureDetails.fromReader);

  /// Convenience constructor to construct from encoded [hex].
  factory SingleSignatureDetails.fromHex(String hex) =>
      SingleSignatureDetails.fromBytes(cl.hexToBytes(hex));

  @override
  void write(cl.Writer writer) {
    signDetails.write(writer);
    writer.writeSlice(groupKey.data);
    writer.writeUInt8(hdDerivation.length);
    for (final i in hdDerivation) {
      writer.writeUInt32(i);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SingleSignatureDetails &&
          signDetails == other.signDetails &&
          groupKey == other.groupKey &&
          ListEquality<int>().equals(hdDerivation, other.hdDerivation));

  @override
  int get hashCode =>
      Object.hash(signDetails, groupKey, Object.hashAll(hdDerivation));

  T derive<T extends HDDerivableInfo>(T info) =>
      deriveThresholdHdKey(info, hdDerivation);
}

// Frosty 5 exposes mutable message and MAST arrays. A signed Noosphere proposal
// must own those bytes before hashing, validation, or nonce preparation.
final class _ImmutableSignDetails extends SignDetails with NoosphereWritable {
  _ImmutableSignDetails(SignDetails details)
    : super(
        message: Uint8List.fromList(details.message).asUnmodifiableView(),
        mastHash: details.mastHash == null
            ? null
            : Uint8List.fromList(details.mastHash!).asUnmodifiableView(),
      );
}

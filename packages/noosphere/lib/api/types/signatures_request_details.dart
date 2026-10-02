import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere/common/serial.dart';

import 'expiry.dart';
import 'signature_metadata.dart';
import 'signed.dart';
import 'signed_message_payload.dart';
import 'single_signature_details.dart';

/// 16-byte ID for a [SignaturesRequestDetails] that implements equality
/// comparison
class SignaturesRequestId with cl.Writable, NoosphereWritable {
  final Uint8List _hash;
  SignaturesRequestId._(this._hash) {
    assert(_hash.length == 16);
  }

  SignaturesRequestId.fromReader(cl.BytesReader reader)
    : this._(reader.readSlice(16));

  /// Convenience constructor to construct from serialised [bytes].
  factory SignaturesRequestId.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SignaturesRequestId.fromReader);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignaturesRequestId && cl.bytesEqual(_hash, other._hash));

  @override
  int get hashCode => Object.hashAll(_hash);

  @override
  void write(cl.Writer writer) {
    writer.writeSlice(_hash);
  }
}

/// Details of requested required signatures
class SignaturesRequestDetails with cl.Writable, NoosphereWritable, Signable {
  /// Maximum UTF-8 byte length of the request explanation.
  static const int maxMessageBytes = 1024;

  /// A request can be for one or more signatures at a time
  final List<SingleSignatureDetails> requiredSigs;

  /// The metadata contains details specific to the request and can vary
  /// depending on the type of request.
  final SignatureMetadata metadata;
  final Expiry expiry;

  /// Free-form explanation from the requester, empty when omitted, limited to
  /// [maxMessageBytes] UTF-8 bytes.
  ///
  /// Included in the request signature and ID, but does not change the
  /// messages in [requiredSigs] that the threshold signers will sign.
  final String message;

  SignaturesRequestDetails._({
    required List<SingleSignatureDetails> requiredSigs,
    SignatureMetadata? metadata,
    required this.expiry,
    this.message = '',
    bool allowNegativeExpiry = false,
  }) : requiredSigs = List.unmodifiable(requiredSigs),
       metadata = metadata ?? EmptySignatureMetadata() {
    if (message.length > maxMessageBytes ||
        utf8.encode(message).length > maxMessageBytes) {
      throw ArgumentError('message exceeds $maxMessageBytes UTF-8 bytes');
    }
    if (requiredSigs.toSet().length != requiredSigs.length ||
        requiredSigs.length > 0xffff ||
        requiredSigs.isEmpty) {
      throw ArgumentError.value(
        requiredSigs,
        "requiredSigs",
        "does not contain up-to 0xffff unique values",
      );
    }
    if (!allowNegativeExpiry) {
      expiry.requireNotExpired();
    }
    if (!this.metadata.verifyRequiredSigs(requiredSigs)) {
      throw InvalidMetaData("Required signatures not valid for metadata");
    }
  }

  SignaturesRequestDetails({
    required List<SingleSignatureDetails> requiredSigs,
    SignatureMetadata? metadata,
    required Expiry expiry,
    String message = '',
  }) : this._(
         requiredSigs: requiredSigs,
         metadata: metadata,
         expiry: expiry,
         message: message,
       );

  /// Creates an untweaked BIP-340 request for a versioned text payload.
  factory SignaturesRequestDetails.forMessage({
    required String text,
    required cl.ECCompressedPublicKey groupKey,
    required Expiry expiry,
    String message = '',
    int version = SignedMessagePayload.currentVersion,
  }) {
    final payload = SignedMessagePayload(text: text, version: version);
    return SignaturesRequestDetails(
      requiredSigs: [
        SingleSignatureDetails(
          signDetails: SignDetails(message: payload.digest, mastHash: null),
          groupKey: groupKey,
          hdDerivation: const [],
        ),
      ],
      metadata: MessageSignatureMetadata(payload: payload),
      expiry: expiry,
      message: message,
    );
  }

  SignaturesRequestDetails.allowNegativeExpiry({
    required List<SingleSignatureDetails> requiredSigs,
    SignatureMetadata? metadata,
    required Expiry expiry,
    String message = '',
  }) : this._(
         requiredSigs: requiredSigs,
         metadata: metadata,
         expiry: expiry,
         message: message,
         allowNegativeExpiry: true,
       );

  SignaturesRequestDetails.fromReader(cl.BytesReader reader)
    : this(
        requiredSigs: List.generate(
          reader.readUInt16(),
          (_) => SingleSignatureDetails.fromReader(reader),
        ),
        metadata: SignatureMetadata.fromReader(reader),
        expiry: Expiry.fromReader(reader),
        message: _readMessage(reader),
      );

  SignaturesRequestDetails.fromReaderAllowNegativeExpiry(cl.BytesReader reader)
    : this.allowNegativeExpiry(
        requiredSigs: List.generate(
          reader.readUInt16(),
          (_) => SingleSignatureDetails.fromReader(reader),
        ),
        metadata: SignatureMetadata.fromReader(reader),
        expiry: Expiry.fromReader(reader),
        message: _readMessage(reader),
      );

  static String _readMessage(cl.BytesReader reader) {
    final length = reader.readVarInt();
    if (length > BigInt.from(maxMessageBytes)) {
      throw FormatException('message exceeds $maxMessageBytes UTF-8 bytes');
    }
    return utf8.decode(reader.readSlice(length.toInt()));
  }

  /// Convenience constructor to construct from serialised [bytes].
  factory SignaturesRequestDetails.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SignaturesRequestDetails.fromReader);

  /// Decodes a historical, completed request that may already be expired.
  ///
  /// Active and newly submitted requests must use [fromBytes], which retains
  /// the normal expiry validation.
  factory SignaturesRequestDetails.fromBytesAllowExpired(Uint8List bytes) =>
      readNoosphere(
        bytes,
        SignaturesRequestDetails.fromReaderAllowNegativeExpiry,
      );

  /// Convenience constructor to construct from encoded [hex].
  factory SignaturesRequestDetails.fromHex(String hex) =>
      SignaturesRequestDetails.fromBytes(cl.hexToBytes(hex));

  static final _hasher = cl.getTaggedHasher("SignaturesRequestDetails");

  @override
  Uint8List get uncachedSigHash => _hasher(toBytes());

  @override
  void write(cl.Writer writer) {
    writer.writeUInt16(requiredSigs.length);
    for (final sig in requiredSigs) {
      sig.write(writer);
    }
    metadata.write(writer);
    expiry.write(writer);
    writer.writeString(message);
  }

  SignaturesRequestId get id => SignaturesRequestId._(sigHash.sublist(0, 16));
}

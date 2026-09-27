import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common/serial.dart';

import 'expiry.dart';
import 'signature_metadata.dart';
import 'signed.dart';
import 'single_signature_details.dart';

/// 16-byte ID for a [SignaturesRequestDetails] that implements equality
/// comparison
class SignaturesRequestId with cl.Writable {
  final Uint8List _hash;
  SignaturesRequestId._(this._hash) {
    assert(_hash.length == 16);
  }

  SignaturesRequestId.fromReader(cl.BytesReader reader)
    : this._(reader.readSlice(16));

  /// Convenience constructor to construct from serialised [bytes].
  SignaturesRequestId.fromBytes(Uint8List bytes)
    : this.fromReader(cl.BytesReader(bytes));

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
class SignaturesRequestDetails with cl.Writable, Signable {
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

  // Legacy requests did not serialize [message]. Keep their original wire
  // representation so their ID and requester signature remain valid while
  // they are restored from persisted server/client state.
  final bool _serializeMessage;

  SignaturesRequestDetails._({
    required List<SingleSignatureDetails> requiredSigs,
    SignatureMetadata? metadata,
    required this.expiry,
    this.message = '',
    bool allowNegativeExpiry = false,
    this._serializeMessage = true,
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

  SignaturesRequestDetails._fromLegacyReader(
    cl.BytesReader reader, {
    required bool allowNegativeExpiry,
  }) : this._(
         requiredSigs: List.generate(
           reader.readUInt16(),
           (_) => SingleSignatureDetails.fromReader(reader),
         ),
         metadata: SignatureMetadata.fromReader(reader),
         expiry: Expiry.fromReader(reader),
         allowNegativeExpiry: allowNegativeExpiry,
         serializeMessage: false,
       );

  static String _readMessage(cl.BytesReader reader) {
    final length = reader.readVarInt();
    if (length > BigInt.from(maxMessageBytes)) {
      throw FormatException('message exceeds $maxMessageBytes UTF-8 bytes');
    }
    return utf8.decode(reader.readSlice(length.toInt()));
  }

  /// Convenience constructor to construct from serialised [bytes].
  ///
  /// Also accepts the legacy encoding that predates [message].
  factory SignaturesRequestDetails.fromBytes(Uint8List bytes) =>
      _fromExactBytes(bytes, allowNegativeExpiry: false);

  static SignaturesRequestDetails _fromExactBytes(
    Uint8List bytes, {
    required bool allowNegativeExpiry,
  }) {
    Object? currentError;
    StackTrace? currentStack;
    try {
      return _readExact(
        bytes,
        (reader) => allowNegativeExpiry
            ? SignaturesRequestDetails.fromReaderAllowNegativeExpiry(reader)
            : SignaturesRequestDetails.fromReader(reader),
      );
    } catch (error, stack) {
      currentError = error;
      currentStack = stack;
    }

    try {
      return _readExact(
        bytes,
        (reader) => SignaturesRequestDetails._fromLegacyReader(
          reader,
          allowNegativeExpiry: allowNegativeExpiry,
        ),
      );
    } catch (_) {
      Error.throwWithStackTrace(currentError, currentStack);
    }
  }

  /// Decodes signed details from an exact byte slice, including requests made
  /// before the optional [message] field was introduced.
  static Signed<SignaturesRequestDetails> signedFromBytes(
    Uint8List bytes, {
    bool allowNegativeExpiry = false,
  }) {
    Object? currentError;
    StackTrace? currentStack;
    try {
      return _readExact(
        bytes,
        (reader) => Signed.fromReader(
          reader,
          () => allowNegativeExpiry
              ? SignaturesRequestDetails.fromReaderAllowNegativeExpiry(reader)
              : SignaturesRequestDetails.fromReader(reader),
        ),
      );
    } catch (error, stack) {
      currentError = error;
      currentStack = stack;
    }

    try {
      return _readExact(
        bytes,
        (reader) => Signed.fromReader(
          reader,
          () => SignaturesRequestDetails._fromLegacyReader(
            reader,
            allowNegativeExpiry: allowNegativeExpiry,
          ),
        ),
      );
    } catch (_) {
      Error.throwWithStackTrace(currentError, currentStack);
    }
  }

  static T _readExact<T>(
    Uint8List bytes,
    T Function(cl.BytesReader reader) read,
  ) {
    // BytesReader uses the entire backing buffer, ignoring a view's bounds.
    // Copy the exact slice so parsing and atEnd respect those bounds.
    final reader = cl.BytesReader(Uint8List.fromList(bytes));
    final value = read(reader);
    if (!reader.atEnd) {
      throw FormatException('Unexpected trailing bytes');
    }
    return value;
  }

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
    if (_serializeMessage) writer.writeString(message);
  }

  SignaturesRequestId get id => SignaturesRequestId._(sigHash.sublist(0, 16));
}

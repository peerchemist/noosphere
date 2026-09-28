import 'dart:convert';

import 'package:coinlib/coinlib.dart' as cl;

import 'signature_metadata.dart';
import 'signatures_request_details.dart';
import 'signed_message_payload.dart';

/// A portable BIP-340 signature over a Noosphere signed-message payload.
class SignedMessage {
  static const String jsonFormat = 'noosphere-signed-message';

  final SignedMessagePayload payload;
  final cl.ECCompressedPublicKey publicKey;
  final cl.SchnorrSignature signature;

  SignedMessage._({
    required this.payload,
    required this.publicKey,
    required this.signature,
  });

  factory SignedMessage({
    required String text,
    required cl.ECCompressedPublicKey publicKey,
    required cl.SchnorrSignature signature,
    int version = SignedMessagePayload.currentVersion,
  }) => SignedMessage._(
    payload: SignedMessagePayload(text: text, version: version),
    publicKey: cl.ECCompressedPublicKey.fromXOnly(publicKey.x),
    signature: cl.SchnorrSignature(signature.data),
  );

  /// Builds and validates a result from a completed signature request.
  factory SignedMessage.fromCompletedRequest({
    required SignaturesRequestDetails details,
    required List<cl.SchnorrSignature> signatures,
  }) {
    final metadata = details.metadata;
    if (metadata is! MessageSignatureMetadata) {
      throw InvalidMetaData('request is not a message-signing request');
    }
    if (!metadata.verifyRequiredSigs(details.requiredSigs)) {
      throw InvalidMetaData('message-signing request metadata is invalid');
    }
    if (signatures.length != 1) {
      throw ArgumentError.value(
        signatures,
        'signatures',
        'message-signing completion must contain exactly one signature',
      );
    }

    final result = SignedMessage(
      version: metadata.payload.version,
      text: metadata.payload.text,
      publicKey: details.requiredSigs.single.groupKey,
      signature: signatures.single,
    );
    if (!result.verify()) {
      throw ArgumentError.value(
        signatures.single,
        'signatures',
        'completed message signature is invalid',
      );
    }
    return result;
  }

  /// Shorter alias for [SignedMessage.fromCompletedRequest].
  factory SignedMessage.fromCompletion({
    required SignaturesRequestDetails details,
    required List<cl.SchnorrSignature> signatures,
  }) => SignedMessage.fromCompletedRequest(
    details: details,
    signatures: signatures,
  );

  factory SignedMessage.fromJson(Map<String, Object?> json) {
    if (json['format'] != jsonFormat) {
      throw const FormatException('invalid signed-message JSON format');
    }

    final version = json['version'];
    final text = json['text'];
    final publicKeyHex = json['publicKey'];
    final signatureHex = json['signature'];
    if (version is! int ||
        text is! String ||
        publicKeyHex is! String ||
        signatureHex is! String) {
      throw const FormatException('invalid signed-message JSON field type');
    }
    if (!_canonicalHex(publicKeyHex, 64)) {
      throw const FormatException('publicKey must be 64 lowercase hex digits');
    }
    if (!_canonicalHex(signatureHex, 128)) {
      throw const FormatException('signature must be 128 lowercase hex digits');
    }

    try {
      return SignedMessage(
        version: version,
        text: text,
        publicKey: cl.ECCompressedPublicKey.fromXOnlyHex(publicKeyHex),
        signature: cl.SchnorrSignature.fromHex(signatureHex),
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message?.toString() ?? error.toString());
    } on cl.InvalidPublicKey {
      throw const FormatException('invalid signed-message public key');
    }
  }

  factory SignedMessage.fromJsonString(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('signed-message JSON must be an object');
    }
    return SignedMessage.fromJson(decoded.cast<String, Object?>());
  }

  int get version => payload.version;
  int get formatVersion => payload.version;
  String get text => payload.text;

  bool verify() => signature.verify(publicKey, payload.digest);

  Map<String, Object> toJson() {
    if (!verify()) {
      throw StateError('cannot export an invalid signed message');
    }
    return {
      'format': jsonFormat,
      'version': version,
      'text': text,
      'publicKey': publicKey.xhex,
      'signature': cl.bytesToHex(signature.data),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static bool _canonicalHex(String value, int length) =>
      value.length == length && RegExp(r'^[0-9a-f]+$').hasMatch(value);
}

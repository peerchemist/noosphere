part of '../signature_metadata.dart';

/// Identifies and validates a wallet-style Noosphere message signature.
class MessageSignatureMetadata extends SignatureMetadata {
  @override
  final int type = 2;

  final SignedMessagePayload payload;

  MessageSignatureMetadata({required this.payload});

  MessageSignatureMetadata.fromReader(cl.BytesReader reader)
    : this(payload: SignedMessagePayload.fromReader(reader));

  @override
  void write(cl.Writer writer) {
    writer.writeUInt8(type);
    payload.write(writer);
  }

  @override
  bool verifyRequiredSigs(List<SingleSignatureDetails> requiredSigs) {
    if (requiredSigs.length != 1) return false;
    final requiredSig = requiredSigs.single;
    return cl.bytesEqual(requiredSig.signDetails.message, payload.digest) &&
        requiredSig.signDetails.mastHash == null &&
        requiredSig.hdDerivation.isEmpty;
  }
}

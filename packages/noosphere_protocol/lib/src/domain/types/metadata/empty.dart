part of '../signature_metadata.dart';

class EmptySignatureMetadata extends SignatureMetadata {
  @override
  final int type = 0;

  @override
  void write(cl.Writer writer) {
    writer.writeUInt8(type);
  }

  @override
  bool verifyRequiredSigs(List<SingleSignatureDetails> requiredSigs) => true;
}

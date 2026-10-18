part of '../signature_metadata.dart';

class UnknownSignatureMetadata extends SignatureMetadata {
  @override
  final int type;
  final Uint8List data;

  UnknownSignatureMetadata(this.type, Uint8List data)
    : data = Uint8List.fromList(data).asUnmodifiableView() {
    RangeError.checkValueInInterval(type, 3, 0xff, 'type');
  }

  @override
  void write(cl.Writer writer) {
    writer.writeUInt8(type);
    writer.writeSlice(data);
  }

  @override
  bool verifyRequiredSigs(List<SingleSignatureDetails> requiredSigs) => false;
}

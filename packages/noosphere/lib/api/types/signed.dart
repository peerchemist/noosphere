import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common/serial.dart';

mixin Signable on cl.Writable {
  Uint8List get uncachedSigHash;
  Uint8List? _hashCache;
  Uint8List get sigHash =>
      _hashCache ??= Uint8List.fromList(uncachedSigHash).asUnmodifiableView();
}

/// A 32-byte hash used directly for a signature
class SignableHash with cl.Writable, NoosphereWritable, Signable {
  final Uint8List bytes;
  SignableHash(Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    RangeError.checkValueInInterval(bytes.length, 32, 32);
  }
  @override
  Uint8List get uncachedSigHash => bytes;
  @override
  void write(cl.Writer writer) {
    writer.writeSlice(bytes);
  }
}

class Signed<T extends Signable> with cl.Writable, NoosphereWritable {
  final T obj;
  final cl.SchnorrSignature signature;

  Signed({required this.obj, required this.signature});
  Signed.sign({required T obj, required cl.ECPrivateKey key})
    : this(obj: obj, signature: cl.SchnorrSignature.sign(key, obj.sigHash));
  Signed.fromReader(cl.BytesReader reader, T Function() readObj)
    : this(obj: readObj(), signature: reader.readSignature());
  factory Signed.fromBytes(
    Uint8List bytes,
    T Function(cl.BytesReader) readObj,
  ) {
    final reader = NoosphereBytesReader(bytes);
    final signed = Signed.fromReader(reader, () => readObj(reader));
    if (!reader.atEnd) throw const FormatException('trailing signed data');
    return signed;
  }

  bool verify(cl.ECPublicKey publickey) =>
      signature.verify(publickey, obj.sigHash);

  @override
  void write(cl.Writer writer) {
    obj.write(writer);
    writer.writeSignature(signature);
  }
}

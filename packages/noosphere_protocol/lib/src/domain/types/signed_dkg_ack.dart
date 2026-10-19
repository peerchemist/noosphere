import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/src/common/serial.dart';
import 'package:frosty/frosty.dart';

import 'dkg_ack.dart';
import 'signed.dart';

/// A signed [DkgAck] and the [signer]. These are equal when the [signer] and
/// group key and ceremony transcript context are the same.
class SignedDkgAck with cl.Writable, NoosphereWritable {
  final Identifier signer;
  final Signed<DkgAck> signed;

  SignedDkgAck({required this.signer, required this.signed});
  SignedDkgAck.fromReader(cl.BytesReader reader)
    : this(
        signer: reader.readIdentifier(),
        signed: Signed.fromReader(reader, () => DkgAck.fromReader(reader)),
      );
  factory SignedDkgAck.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SignedDkgAck.fromReader);

  @override
  /// Equal only when the complete signed value is byte-for-byte identical.
  /// This keeps conflicting values visible when a batch is represented as a
  /// set so the receiver can reject the whole batch before mutation.
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignedDkgAck &&
          signer == other.signer &&
          cl.bytesEqual(signed.toBytes(), other.signed.toBytes()));

  @override
  int get hashCode => Object.hash(signer, Object.hashAll(signed.toBytes()));

  @override
  void write(cl.Writer writer) {
    writer.writeIdentifier(signer);
    signed.write(writer);
  }
}

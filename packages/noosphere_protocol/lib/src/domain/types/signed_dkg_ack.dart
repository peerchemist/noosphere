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
  /// Equal when the signer, group key and ceremony transcript are the same
  /// regardless of acceptance.
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignedDkgAck &&
          signer == other.signer &&
          signed.obj.groupKey == other.signed.obj.groupKey &&
          cl.bytesEqual(
            signed.obj.ceremonyId ?? Uint8List(0),
            other.signed.obj.ceremonyId ?? Uint8List(0),
          ) &&
          cl.bytesEqual(
            signed.obj.transcriptHash ?? Uint8List(0),
            other.signed.obj.transcriptHash ?? Uint8List(0),
          ));

  @override
  int get hashCode => Object.hash(
    signer,
    signed.obj.groupKey,
    Object.hashAll(signed.obj.ceremonyId ?? const []),
    Object.hashAll(signed.obj.transcriptHash ?? const []),
  );

  @override
  void write(cl.Writer writer) {
    writer.writeIdentifier(signer);
    signed.write(writer);
  }
}

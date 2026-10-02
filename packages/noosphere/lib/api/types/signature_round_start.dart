import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common/serial.dart';
import 'package:frosty/frosty.dart';

class SignatureRoundStart with cl.Writable, NoosphereWritable {
  final int sigI;
  final SigningCommitmentSet commitments;
  SignatureRoundStart({required this.sigI, required this.commitments});
  SignatureRoundStart.fromReader(cl.BytesReader reader)
    : this(
        sigI: reader.readUInt16(),
        commitments: SigningCommitmentSet.fromReader(reader),
      );
  factory SignatureRoundStart.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SignatureRoundStart.fromReader);

  @override
  void write(cl.Writer writer) {
    writer.writeUInt16(sigI);
    commitments.write(writer);
  }
}

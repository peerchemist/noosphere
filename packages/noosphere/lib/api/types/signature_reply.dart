import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common/serial.dart';
import 'package:frosty/frosty.dart';

/// A ROAST reply for a single signature at the position [sigI] in a request.
class SignatureReply with cl.Writable, NoosphereWritable {
  final int sigI;

  /// The next commitment must always be provided.
  final SigningCommitment nextCommitment;

  /// When a ROAST round has been initiated, the signature share is provided.
  final SignatureShare? share;

  SignatureReply({
    required this.sigI,
    required this.nextCommitment,
    this.share,
  });

  SignatureReply.fromReader(cl.BytesReader reader)
    : this(
        sigI: reader.readUInt16(),
        nextCommitment: SigningCommitment.fromBytes(reader.readVarSlice()),
        share: reader.readBool()
            ? SignatureShare.fromBytes(reader.readVarSlice())
            : null,
      );

  /// Convenience constructor to construct from serialised [bytes].
  factory SignatureReply.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SignatureReply.fromReader);

  @override
  void write(cl.Writer writer) {
    writer.writeUInt16(sigI);
    writer.writeVarSlice(nextCommitment.toBytes());
    writer.writeBool(share != null);
    if (share != null) {
      writer.writeVarSlice(share!.toBytes());
    }
  }
}

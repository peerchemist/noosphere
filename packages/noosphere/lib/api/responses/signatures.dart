import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/api/types/signature_round_start.dart';
import 'package:noosphere/common/serial.dart';
import 'package:frosty/frosty.dart';

sealed class SignaturesResponse with cl.Writable, NoosphereWritable {}

/// Provides the [SigningCommitmentSet]s when new ROAST rounds are initiated.
class SignatureNewRoundsResponse extends SignaturesResponse {
  final List<SignatureRoundStart> rounds;
  SignatureNewRoundsResponse(List<SignatureRoundStart> rounds)
    : rounds = List.unmodifiable(rounds);

  SignatureNewRoundsResponse.fromReader(cl.BytesReader reader)
    : this(
        reader.readWritableVector(
          (bytes) => SignatureRoundStart.fromBytes(bytes),
        ),
      );

  /// Convenience constructor to construct from serialised [bytes].
  factory SignatureNewRoundsResponse.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SignatureNewRoundsResponse.fromReader);

  @override
  void write(cl.Writer writer) {
    writer.writeWritableVector(rounds);
  }
}

/// Provides all of the final signatures when ROAST is complete.
class SignaturesCompleteResponse extends SignaturesResponse {
  final List<cl.SchnorrSignature> signatures;
  SignaturesCompleteResponse(List<cl.SchnorrSignature> signatures)
    : signatures = List.unmodifiable(signatures);

  SignaturesCompleteResponse.fromReader(cl.BytesReader reader)
    : this(reader.readSignatureVector());

  /// Convenience constructor to construct from serialised [bytes].
  factory SignaturesCompleteResponse.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SignaturesCompleteResponse.fromReader);

  @override
  void write(cl.Writer writer) {
    writer.writeSignatureVector(signatures);
  }
}

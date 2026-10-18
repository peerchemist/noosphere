import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/src/common/serial.dart';
import 'package:noosphere_protocol/src/domain/types/expirable.dart';
import 'package:noosphere_protocol/src/domain/types/expiry.dart';
import 'package:noosphere_protocol/src/domain/types/onetime_numbers.dart';

class ExpirableAuthChallengeResponse
    with cl.Writable, NoosphereWritable
    implements Expirable {
  final AuthChallenge challenge;
  @override
  final Expiry expiry;

  ExpirableAuthChallengeResponse({
    required this.challenge,
    required this.expiry,
  });

  ExpirableAuthChallengeResponse.fromReader(cl.BytesReader reader)
    : this(
        challenge: AuthChallenge.fromReader(reader),
        expiry: Expiry.fromReader(reader),
      );

  /// Convenience constructor to construct from serialised [bytes].
  factory ExpirableAuthChallengeResponse.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, ExpirableAuthChallengeResponse.fromReader);

  @override
  void write(cl.Writer writer) {
    challenge.write(writer);
    expiry.write(writer);
  }
}

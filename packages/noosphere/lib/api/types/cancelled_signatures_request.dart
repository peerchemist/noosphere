import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common/serial.dart';

import 'expirable.dart';
import 'expiry.dart';
import 'signatures_request_details.dart';

/// A cancellation retains only the request ID and its original expiry.
final class CancelledSignaturesRequest(this.requestId, this.expiry)
    with cl.Writable, NoosphereWritable
    implements Expirable {
  final SignaturesRequestId requestId;
  @override
  final Expiry expiry;

  new fromReader(cl.BytesReader reader)
    : this(SignaturesRequestId.fromReader(reader), Expiry.fromReader(reader));

  factory fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, CancelledSignaturesRequest.fromReader);

  @override
  void write(cl.Writer writer) {
    requestId.write(writer);
    expiry.write(writer);
  }
}

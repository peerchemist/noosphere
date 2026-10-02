import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common.dart';

class Expiry with cl.Writable, NoosphereWritable {
  final DateTime time;

  Expiry(Duration ttl) : time = DateTime.now().add(ttl);
  Expiry.fromTime(this.time);
  Expiry.fromReader(cl.BytesReader reader) : time = reader.readTime();
  factory Expiry.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, Expiry.fromReader);

  bool get isExpired => time.isBefore(DateTime.now());

  @override
  void write(cl.Writer writer) {
    writer.writeTime(time);
  }

  Duration get ttl => time.difference(DateTime.now());

  void requireNotExpired() {
    if (isExpired) throw ArgumentError.value(time.toString());
  }

  Expiry clampUpperTTL(Duration maxTTL) =>
      ttl.compareTo(maxTTL) <= 0 ? this : Expiry(maxTTL);
}

import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common.dart';
import 'package:noosphere/config.dart';
import 'package:noosphere/domain.dart';

class ServerConfig with cl.Writable {
  static const defaultChallengeTTL = Duration(seconds: 20);
  static const defaultSessionTTL = Duration(minutes: 1);
  static const defaultMinDkgRequestTTL = Duration(minutes: 29);
  static const defaultMaxDkgRequestTTL = Duration(days: 7);
  static const defaultMinSignaturesRequestTTL = Duration(seconds: 25);
  static const defaultMaxSignaturesRequestTTL = Duration(days: 14);
  static const defaultMinCompletedSignaturesTTL = Duration(days: 1);
  static const defaultAckCacheTTL = Duration(minutes: 1);

  final GroupConfig group;
  final Duration challengeTTL;
  final Duration sessionTTL;
  final Duration minDkgRequestTTL;
  final Duration maxDkgRequestTTL;
  final Duration minSignaturesRequestTTL;
  final Duration maxSignaturesRequestTTL;
  final Duration minCompletedSignaturesTTL;
  final Duration ackCacheTTL;

  /// A [KeepaliveEvent] will be sent to clients periodically.
  final Duration? keepAliveFreq;

  ServerConfig({
    required this.group,
    this.challengeTTL = defaultChallengeTTL,
    this.sessionTTL = defaultSessionTTL,
    this.minDkgRequestTTL = defaultMinDkgRequestTTL,
    this.maxDkgRequestTTL = defaultMaxDkgRequestTTL,
    this.minSignaturesRequestTTL = defaultMinSignaturesRequestTTL,
    this.maxSignaturesRequestTTL = defaultMaxSignaturesRequestTTL,
    this.minCompletedSignaturesTTL = defaultMinCompletedSignaturesTTL,
    this.ackCacheTTL = defaultAckCacheTTL,
    this.keepAliveFreq,
  });

  /// Convenience constructor to construct from serialised [bytes].
  ServerConfig.fromBytes(Uint8List bytes)
    : this.fromReader(cl.BytesReader(bytes));

  /// Convenience constructor to construct from encoded [hex].
  ServerConfig.fromHex(String hex) : this.fromBytes(cl.hexToBytes(hex));

  ServerConfig.fromReader(cl.BytesReader reader)
    : this(
        group: GroupConfig.fromReader(reader),
        challengeTTL: reader.readDuration(),
        sessionTTL: reader.readDuration(),
        minDkgRequestTTL: reader.readDuration(),
        maxDkgRequestTTL: reader.readDuration(),
        minSignaturesRequestTTL: reader.readDuration(),
        maxSignaturesRequestTTL: reader.readDuration(),
        minCompletedSignaturesTTL: reader.readDuration(),
        ackCacheTTL: reader.readDuration(),
        keepAliveFreq: reader.readBool() ? reader.readDuration() : null,
      );

  @override
  void write(cl.Writer writer) {
    group.write(writer);

    writer.writeDuration(challengeTTL);
    writer.writeDuration(sessionTTL);
    writer.writeDuration(minDkgRequestTTL);
    writer.writeDuration(maxDkgRequestTTL);
    writer.writeDuration(minSignaturesRequestTTL);
    writer.writeDuration(maxSignaturesRequestTTL);
    writer.writeDuration(minCompletedSignaturesTTL);
    writer.writeDuration(ackCacheTTL);

    bool useKeepalive = keepAliveFreq != null;
    writer.writeBool(useKeepalive);
    if (useKeepalive) {
      writer.writeDuration(keepAliveFreq!);
    }
  }
}

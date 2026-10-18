import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/common.dart';
import 'package:noosphere_protocol/config.dart';
import 'package:noosphere_protocol/domain.dart';
import 'package:noosphere_protocol/public_feed.dart';

import 'public_feed.dart';

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

  /// Null disables public access and recording. Each group needs its own ID.
  final PublicFeedConfig? publicFeed;

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
    this.publicFeed,
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
        publicFeed: reader.atEnd ? null : _readPublicFeed(reader),
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
    if (publicFeed case final feed?) {
      writer.writeUInt8(1); // Optional server-config extension version.
      writer.writeSlice(feed.feedId.toBytes());
      writer.writeUInt32(feed.maxEntries);
      writer.writeDuration(feed.maxAge);
    }
  }
}

PublicFeedConfig _readPublicFeed(cl.BytesReader reader) {
  if (reader.readUInt8() != 1) {
    throw const FormatException('Unknown feed config version');
  }
  return PublicFeedConfig(
    feedId: PublicFeedId.fromBytes(reader.readSlice(32)),
    maxEntries: reader.readUInt32(),
    maxAge: reader.readDuration(),
  );
}

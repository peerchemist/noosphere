import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/common.dart';
import 'package:noosphere_protocol/config.dart';
import 'package:noosphere_protocol/domain.dart';
import 'package:noosphere_protocol/message_limits.dart';
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

  static const defaultMaxDkgParticipants = 64;
  static const maxActiveDkgs = 32;
  static const maxEncryptedDkgShareBytes = encryptedDkgShareMaxBytes;
  static const maxDkgStateBytes = 16 * 1024 * 1024;
  static const maxDkgRequestsPerMinute = 8;

  static const maxActiveSignaturesRequests = 32;
  static const maxRetainedSignaturesRequests = 128;
  static const maxSignaturesPerRequest = 16;
  static const maxSigningRequestBytes = 16 * 1024;
  static const maxSigningRequestsPerMinute = 8;
  static const maxRecoveryKeys = 32;
  static const maxEncryptedRecoveryShareBytes = 256;
  static const maxRecoveryStateBytes = 4 * 1024 * 1024;
  static const maxRecoveryRequestsPerMinute = 32;

  final GroupConfig group;

  /// Maximum size accepted for both configured DKG groups and new rooms.
  final int maxDkgParticipants;
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
    this.maxDkgParticipants = defaultMaxDkgParticipants,
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
  }) {
    RangeError.checkValueInInterval(maxDkgParticipants, 2, 0xffff);
    if (group.participants.length > maxDkgParticipants) {
      throw ArgumentError('DKG groups are limited to $maxDkgParticipants');
    }
  }

  /// Convenience constructor to construct from serialised [bytes].
  factory ServerConfig.fromBytes(Uint8List bytes) =>
      ServerConfig.fromReader(cl.BytesReader(bytes));

  /// Convenience constructor to construct from encoded [hex].
  factory ServerConfig.fromHex(String hex) =>
      ServerConfig.fromBytes(cl.hexToBytes(hex));

  factory ServerConfig.fromReader(cl.BytesReader reader) {
    final group = GroupConfig.fromReader(reader);
    final challengeTTL = reader.readDuration();
    final sessionTTL = reader.readDuration();
    final minDkgRequestTTL = reader.readDuration();
    final maxDkgRequestTTL = reader.readDuration();
    final minSignaturesRequestTTL = reader.readDuration();
    final maxSignaturesRequestTTL = reader.readDuration();
    final minCompletedSignaturesTTL = reader.readDuration();
    final ackCacheTTL = reader.readDuration();
    final keepAliveFreq = reader.readBool() ? reader.readDuration() : null;
    final extension = _readExtension(reader);
    return ServerConfig(
      group: group,
      maxDkgParticipants: extension.maxDkgParticipants,
      challengeTTL: challengeTTL,
      sessionTTL: sessionTTL,
      minDkgRequestTTL: minDkgRequestTTL,
      maxDkgRequestTTL: maxDkgRequestTTL,
      minSignaturesRequestTTL: minSignaturesRequestTTL,
      maxSignaturesRequestTTL: maxSignaturesRequestTTL,
      minCompletedSignaturesTTL: minCompletedSignaturesTTL,
      ackCacheTTL: ackCacheTTL,
      keepAliveFreq: keepAliveFreq,
      publicFeed: extension.publicFeed,
    );
  }

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
    if (maxDkgParticipants != defaultMaxDkgParticipants) {
      writer.writeUInt8(2); // Optional server-config extension version.
      writer.writeUInt16(maxDkgParticipants);
      writer.writeBool(publicFeed != null);
      if (publicFeed case final feed?) _writePublicFeed(writer, feed);
    } else if (publicFeed case final feed?) {
      writer.writeUInt8(1); // Legacy public-feed-only extension.
      _writePublicFeed(writer, feed);
    }
  }
}

({int maxDkgParticipants, PublicFeedConfig? publicFeed}) _readExtension(
  cl.BytesReader reader,
) {
  if (reader.atEnd) {
    return (
      maxDkgParticipants: ServerConfig.defaultMaxDkgParticipants,
      publicFeed: null,
    );
  }
  return switch (reader.readUInt8()) {
    1 => (
      maxDkgParticipants: ServerConfig.defaultMaxDkgParticipants,
      publicFeed: _readPublicFeed(reader),
    ),
    2 => (
      maxDkgParticipants: reader.readUInt16(),
      publicFeed: reader.readBool() ? _readPublicFeed(reader) : null,
    ),
    _ => throw const FormatException('Unknown server config extension'),
  };
}

PublicFeedConfig _readPublicFeed(cl.BytesReader reader) {
  return PublicFeedConfig(
    feedId: PublicFeedId.fromBytes(reader.readSlice(32)),
    maxEntries: reader.readUInt32(),
    maxAge: reader.readDuration(),
  );
}

void _writePublicFeed(cl.Writer writer, PublicFeedConfig feed) {
  writer.writeSlice(feed.feedId.toBytes());
  writer.writeUInt32(feed.maxEntries);
  writer.writeDuration(feed.maxAge);
}

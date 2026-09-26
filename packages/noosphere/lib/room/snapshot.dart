import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere/common/serial.dart';
import 'package:noosphere/config/group.dart';

enum RoomLifecycle { enrolling, frozen, closed }

enum RoomInviteStatus { pending, used, revoked, expired }

final class RoomInviteSnapshot {
  RoomInviteSnapshot({
    required this.inviteId,
    required this.expectedParticipantPublicKey,
    required Uint8List tokenHash,
    required this.issuedAt,
    required this.expiresAt,
    required this.usedAt,
    required this.revokedAt,
    required this.status,
  }) : tokenHash = Uint8List.fromList(tokenHash);

  final String inviteId;
  final cl.ECCompressedPublicKey expectedParticipantPublicKey;
  final Uint8List tokenHash;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime? revokedAt;
  final RoomInviteStatus status;
}

final class RoomParticipantSnapshot {
  const RoomParticipantSnapshot({
    required this.publicKey,
    required this.enrolledAt,
    required this.identifier,
  });

  final cl.ECCompressedPublicKey publicKey;
  final DateTime enrolledAt;
  final Identifier? identifier;
}

/// Sanitized room state. It never contains invite tokens or private keys.
final class RoomSnapshot with cl.Writable {
  RoomSnapshot({
    required this.roomId,
    required this.lifecycle,
    required this.expectedParticipants,
    required this.threshold,
    required Uint8List coordinatorEndpointId,
    required Iterable<RoomInviteSnapshot> invites,
    required Iterable<RoomParticipantSnapshot> participants,
    required this.groupConfig,
  }) : coordinatorEndpointId = Uint8List.fromList(coordinatorEndpointId),
       invites = List.unmodifiable(invites),
       participants = List.unmodifiable(participants);

  factory RoomSnapshot.fromBytes(Uint8List bytes) {
    final reader = cl.BytesReader(bytes);
    if (reader.readString() != 'noosphere/room-snapshot/1') {
      throw const FormatException('unsupported room snapshot');
    }
    final lifecycle = reader.readUInt8();
    if (lifecycle >= RoomLifecycle.values.length) {
      throw const FormatException('invalid room lifecycle');
    }
    final roomId = reader.readString();
    final expectedParticipants = reader.readUInt16();
    final threshold = reader.readUInt16();
    final coordinatorEndpointId = reader.readSlice(32);
    final invites = List.generate(reader.readUInt16(), (_) {
      final status = reader.readUInt8();
      if (status >= RoomInviteStatus.values.length) {
        throw const FormatException('invalid invite status');
      }
      return RoomInviteSnapshot(
        inviteId: reader.readString(),
        expectedParticipantPublicKey: reader.readPubKey(),
        tokenHash: reader.readSlice(32),
        issuedAt: reader.readTime(),
        expiresAt: reader.readTime(),
        usedAt: reader.readBool() ? reader.readTime() : null,
        revokedAt: reader.readBool() ? reader.readTime() : null,
        status: RoomInviteStatus.values[status],
      );
    });
    final participants = List.generate(
      reader.readUInt16(),
      (_) => RoomParticipantSnapshot(
        publicKey: reader.readPubKey(),
        enrolledAt: reader.readTime(),
        identifier: reader.readBool() ? reader.readIdentifier() : null,
      ),
    );
    final group = reader.readBool()
        ? GroupConfig.fromBytes(reader.readVarSlice())
        : null;
    if (group != null &&
        !cl.bytesEqual(group.fingerprint, reader.readSlice(32))) {
      throw const FormatException('stored group fingerprint does not match');
    }
    if (!reader.atEnd) throw const FormatException('trailing snapshot data');
    return RoomSnapshot(
      roomId: roomId,
      lifecycle: RoomLifecycle.values[lifecycle],
      expectedParticipants: expectedParticipants,
      threshold: threshold,
      coordinatorEndpointId: coordinatorEndpointId,
      invites: invites,
      participants: participants,
      groupConfig: group,
    );
  }

  final String roomId;
  final RoomLifecycle lifecycle;
  final int expectedParticipants;
  final int threshold;
  final Uint8List coordinatorEndpointId;
  final List<RoomInviteSnapshot> invites;
  final List<RoomParticipantSnapshot> participants;
  final GroupConfig? groupConfig;

  Uint8List? get groupFingerprint => groupConfig?.fingerprint;
  bool get isFull => participants.length >= expectedParticipants;

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString('noosphere/room-snapshot/1')
      ..writeUInt8(lifecycle.index)
      ..writeString(roomId)
      ..writeUInt16(expectedParticipants)
      ..writeUInt16(threshold)
      ..writeSlice(coordinatorEndpointId)
      ..writeUInt16(invites.length);
    for (final invite in invites) {
      writer
        ..writeUInt8(invite.status.index)
        ..writeString(invite.inviteId)
        ..writePubKey(invite.expectedParticipantPublicKey)
        ..writeSlice(invite.tokenHash)
        ..writeTime(invite.issuedAt)
        ..writeTime(invite.expiresAt)
        ..writeBool(invite.usedAt != null);
      if (invite.usedAt != null) writer.writeTime(invite.usedAt!);
      writer.writeBool(invite.revokedAt != null);
      if (invite.revokedAt != null) writer.writeTime(invite.revokedAt!);
    }
    writer.writeUInt16(participants.length);
    for (final participant in participants) {
      writer
        ..writePubKey(participant.publicKey)
        ..writeTime(participant.enrolledAt)
        ..writeBool(participant.identifier != null);
      if (participant.identifier != null) {
        writer.writeIdentifier(participant.identifier!);
      }
    }
    writer.writeBool(groupConfig != null);
    if (groupConfig != null) {
      writer
        ..writeVarSlice(groupConfig!.toBytes())
        ..writeSlice(groupConfig!.fingerprint);
    }
  }
}

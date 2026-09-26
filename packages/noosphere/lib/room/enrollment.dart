import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/common/serial.dart';
import 'package:noosphere/room/invite.dart';
import 'package:noosphere/room/snapshot.dart';

/// Transport-independent enrollment request contract.
abstract interface class RoomEnrollmentApi {
  Future<EnrollmentChallenge> beginEnrollment({
    required RoomInvite invite,
    required cl.ECCompressedPublicKey participantPublicKey,
  });

  Future<RoomSnapshot> redeemRoomInvite(Signed<EnrollmentTranscript> proof);
}

/// Canonical, domain-separated proof-of-possession payload.
final class EnrollmentTranscript with cl.Writable, Signable {
  EnrollmentTranscript({
    this.version = noosphereEnrollmentProtocolVersion,
    required this.roomId,
    required this.inviteId,
    required Uint8List inviteTokenHash,
    required this.expectedParticipantPublicKey,
    required Uint8List coordinatorEndpointId,
    required Uint8List serverNonce,
  }) : _inviteTokenHash = _copy32(inviteTokenHash, 'inviteTokenHash'),
       _coordinatorEndpointId = _copy32(
         coordinatorEndpointId,
         'coordinatorEndpointId',
       ),
       _serverNonce = _copy32(serverNonce, 'serverNonce') {
    if (version != noosphereEnrollmentProtocolVersion) {
      throw UnsupportedRoomInviteVersion(version);
    }
    if (roomId.isEmpty || inviteId.isEmpty) {
      throw ArgumentError('roomId and inviteId must not be empty');
    }
  }

  factory EnrollmentTranscript.forInvite(
    RoomInvite invite,
    Uint8List serverNonce,
  ) => EnrollmentTranscript(
    version: invite.version,
    roomId: invite.roomId,
    inviteId: invite.inviteId,
    inviteTokenHash: invite.tokenHash,
    expectedParticipantPublicKey: invite.expectedParticipantPublicKey,
    coordinatorEndpointId: invite.coordinatorEndpointId,
    serverNonce: serverNonce,
  );

  factory EnrollmentTranscript.fromBytes(Uint8List bytes) {
    final reader = cl.BytesReader(bytes);
    final domain = reader.readString();
    if (domain != noosphereEnrollmentProtocol) {
      throw const FormatException('invalid enrollment transcript domain');
    }
    final transcript = EnrollmentTranscript(
      version: reader.readUInt16(),
      roomId: reader.readString(),
      inviteId: reader.readString(),
      inviteTokenHash: reader.readSlice(32),
      expectedParticipantPublicKey: reader.readPubKey(),
      coordinatorEndpointId: reader.readSlice(32),
      serverNonce: reader.readSlice(32),
    );
    if (!reader.atEnd) {
      throw const FormatException('trailing enrollment transcript data');
    }
    return transcript;
  }

  final int version;
  final String roomId;
  final String inviteId;
  final Uint8List _inviteTokenHash;
  final cl.ECCompressedPublicKey expectedParticipantPublicKey;
  final Uint8List _coordinatorEndpointId;
  final Uint8List _serverNonce;

  Uint8List get inviteTokenHash => Uint8List.fromList(_inviteTokenHash);
  Uint8List get coordinatorEndpointId =>
      Uint8List.fromList(_coordinatorEndpointId);
  Uint8List get serverNonce => Uint8List.fromList(_serverNonce);

  @override
  Uint8List get uncachedSigHash => cl.sha256Hash(toBytes());

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString(noosphereEnrollmentProtocol)
      ..writeUInt16(version)
      ..writeString(roomId)
      ..writeString(inviteId)
      ..writeSlice(_inviteTokenHash)
      ..writePubKey(expectedParticipantPublicKey)
      ..writeSlice(_coordinatorEndpointId)
      ..writeSlice(_serverNonce);
  }
}

final class EnrollmentChallenge with cl.Writable {
  EnrollmentChallenge({required this.transcript, required this.expiresAt});

  factory EnrollmentChallenge.fromBytes(Uint8List bytes) {
    final reader = cl.BytesReader(bytes);
    final challenge = EnrollmentChallenge(
      transcript: EnrollmentTranscript.fromBytes(reader.readVarSlice()),
      expiresAt: reader.readTime(),
    );
    if (!reader.atEnd) throw const FormatException('trailing challenge data');
    return challenge;
  }

  final EnrollmentTranscript transcript;
  final DateTime expiresAt;

  Signed<EnrollmentTranscript> sign(cl.ECPrivateKey privateKey) {
    final expected = transcript.expectedParticipantPublicKey.data;
    final actual = cl.ECCompressedPublicKey.fromPubkey(privateKey.pubkey).data;
    if (!cl.bytesEqual(expected, actual)) {
      throw ArgumentError('private key does not match enrollment challenge');
    }
    return Signed.sign(obj: transcript, key: privateKey);
  }

  @override
  void write(cl.Writer writer) {
    writer
      ..writeVarSlice(transcript.toBytes())
      ..writeTime(expiresAt);
  }
}

Uint8List _copy32(Uint8List bytes, String name) {
  if (bytes.length != 32) {
    throw ArgumentError.value(bytes.length, name, 'must contain 32 bytes');
  }
  return Uint8List.fromList(bytes);
}

import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/room.dart';

import '../config/client.dart';
import 'client.dart';

/// Performs the client half of a pubkey-bound room enrollment.
final class RoomEnrollmentClient {
  const RoomEnrollmentClient(this.api);

  final RoomEnrollmentApi api;

  Future<RoomSnapshot> joinRoom(
    RoomInvite invite,
    GetPrivateKey getPrivateKey, {
    DateTime? now,
  }) async {
    final key = await getPrivateKey(KeyPurpose.roomEnrollment);
    invite.requirePrivateKey(key);
    final publicKey = cl.ECCompressedPublicKey.fromPubkey(key.pubkey);
    final challenge = await api.beginEnrollment(
      invite: invite,
      participantPublicKey: publicKey,
    );
    final time = now ?? DateTime.now();
    if (!challenge.expiresAt.isAfter(time)) {
      throw StateError('coordinator returned an expired enrollment challenge');
    }
    final expected = EnrollmentTranscript.forInvite(
      invite,
      challenge.transcript.serverNonce,
    );
    if (!_same(expected.toBytes(), challenge.transcript.toBytes())) {
      throw StateError(
        'coordinator enrollment transcript does not match invite',
      );
    }
    return api.redeemRoomInvite(challenge.sign(key));
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var index = 0; index < a.length; index++) {
    difference |= a[index] ^ b[index];
  }
  return difference == 0;
}

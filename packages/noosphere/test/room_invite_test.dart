import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/room.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(cl.loadCoinlib);

  group('RoomInvite', () {
    test('round-trips its versioned external encoding', () {
      final key = cl.ECPrivateKey.generate();
      final invite = RoomInvite(
        roomId: 'room-a',
        inviteId: 'invite-a',
        token: Uint8List.fromList(List.generate(32, (i) => i)),
        expectedParticipantPublicKey: cl.ECCompressedPublicKey.fromPubkey(
          key.pubkey,
        ),
        coordinatorEndpointId: Uint8List(32)..[0] = 42,
        expiresAt: DateTime.utc(2030, 1, 2, 3, 4, 5),
      );

      final decoded = RoomInvite.decode(invite.encode());
      expect(decoded.toBytes(), invite.toBytes());
      expect(decoded.tokenHash, cl.sha256Hash(invite.token));
      expect(decoded.matchesPrivateKey(key), isTrue);
      expect(decoded.matchesPrivateKey(cl.ECPrivateKey.generate()), isFalse);
    });

    test('rejects unsupported versions', () {
      expect(
        () => RoomInvite(
          version: 2,
          roomId: 'room',
          inviteId: 'invite',
          token: Uint8List(32),
          expectedParticipantPublicKey: cl.ECCompressedPublicKey.fromPubkey(
            cl.ECPrivateKey.generate().pubkey,
          ),
          coordinatorEndpointId: Uint8List(32),
          expiresAt: DateTime.utc(2030),
        ),
        throwsA(isA<UnsupportedRoomInviteVersion>()),
      );
    });
  });

  test('enrollment transcript is canonical and domain separated', () {
    final key = cl.ECPrivateKey.generate();
    final invite = RoomInvite(
      roomId: 'canonical-room',
      inviteId: 'canonical-invite',
      token: Uint8List.fromList(List.filled(32, 7)),
      expectedParticipantPublicKey: cl.ECCompressedPublicKey.fromPubkey(
        key.pubkey,
      ),
      coordinatorEndpointId: Uint8List.fromList(List.filled(32, 8)),
      expiresAt: DateTime.utc(2030),
    );
    final transcript = EnrollmentTranscript.forInvite(
      invite,
      Uint8List.fromList(List.filled(32, 9)),
    );
    final decoded = EnrollmentTranscript.fromBytes(transcript.toBytes());

    expect(decoded.toBytes(), transcript.toBytes());
    expect(decoded.sigHash, cl.sha256Hash(transcript.toBytes()));
    expect(
      EnrollmentChallenge(
        transcript: transcript,
        expiresAt: DateTime.utc(2030),
      ).sign(key).verify(invite.expectedParticipantPublicKey),
      isTrue,
    );
  });
}

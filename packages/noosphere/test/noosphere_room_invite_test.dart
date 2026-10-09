import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/room.dart';
import 'package:test/test.dart';

const _prefix = 'sygnature-roast-v1:';

void main() {
  setUpAll(cl.loadCoinlib);

  late RoomInvite invite;

  setUp(() {
    invite = RoomInvite(
      roomId: 'room',
      inviteId: 'invite',
      token: Uint8List.fromList(List.generate(32, (index) => index)),
      expectedParticipantPublicKey: cl.ECCompressedPublicKey.fromPubkey(
        cl.ECPrivateKey.generate().pubkey,
      ),
      coordinatorEndpointId: Uint8List(32)..[0] = 42,
      expiresAt: DateTime.utc(2030, 1, 2, 3, 4, 5),
    );
  });

  test('wraps the existing RoomInvite encoding in a clickable prefix', () {
    final link = NoosphereRoomInvite(prefix: _prefix, invite: invite);

    expect(link.encode(), '$_prefix${invite.encode()}');
    expect(link.encode(), isNot(contains('=')));
  });

  test('decodes the wrapped RoomInvite', () {
    final encoded = NoosphereRoomInvite(
      prefix: _prefix,
      invite: invite,
    ).encode();
    final decoded = NoosphereRoomInvite.decode(encoded, prefix: _prefix);

    expect(decoded.prefix, _prefix);
    expect(decoded.invite.toBytes(), invite.toBytes());
  });

  test('rejects a link with a different application prefix', () {
    final encoded = NoosphereRoomInvite(
      prefix: 'other-app:',
      invite: invite,
    ).encode();

    expect(
      () => NoosphereRoomInvite.decode(encoded, prefix: _prefix),
      throwsFormatException,
    );
  });
}

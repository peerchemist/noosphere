import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/config.dart';
import 'package:noosphere/domain.dart';
import 'package:noosphere/wire.dart' as wire;
import 'package:test/test.dart';

// Fixed, hand-described preview fixtures. Do not regenerate these from the
// implementation during a test; byte changes require a compatibility review.
void main() {
  setUpAll(loadFrosty);

  test(
    'group roster encoding has stable identifier order and field widths',
    () {
      const firstId =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const secondId =
          '0000000000000000000000000000000000000000000000000000000000000002';
      const firstKey =
          '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
      const secondKey =
          '02c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
      // CompactSize UTF-8 length + "public-preview", LE u16 count, then
      // sorted pairs of 32-byte identifiers and 33-byte compressed keys.
      const golden =
          '0e7075626c69632d70726576696577'
          '0200'
          '$firstId$firstKey$secondId$secondKey';
      final group = GroupConfig(
        id: 'public-preview',
        participants: {
          Identifier.fromHex(secondId): cl.ECCompressedPublicKey.fromHex(
            secondKey,
          ),
          Identifier.fromHex(firstId): cl.ECCompressedPublicKey.fromHex(
            firstKey,
          ),
        },
      );
      expect(group.toHex(), golden);
      final decoded = GroupConfig.fromHex(golden);
      expect(decoded.id, group.id);
      expect(decoded.participants.keys.map((id) => id.toString()), [
        firstId,
        secondId,
      ]);
      expect(decoded.fingerprint, group.fingerprint);
    },
  );

  test('DKG details retain timestamp units and field order', () {
    // Name "key", description "demo", LE u16 threshold 2, LE u64
    // milliseconds 1000000000000 (2001-09-09T01:46:40Z).
    const golden = '036b65790464656d6f02000010a5d4e8000000';
    final details = NewDkgDetails.allowNegativeExpiry(
      name: 'key',
      description: 'demo',
      threshold: 2,
      expiry: Expiry.fromTime(
        DateTime.fromMillisecondsSinceEpoch(1000000000000, isUtc: true),
      ),
    );
    expect(details.toHex(), golden);
    final decoded = NewDkgDetails.fromBytesAllowExpired(cl.hexToBytes(golden));
    expect(decoded.expiry.time.millisecondsSinceEpoch, 1000000000000);
    expect(decoded.sigHash, details.sigHash);
  });

  test('login protobuf and operation-prefixed stream retain fixed wire bytes', () async {
    // Two short opaque byte fields are sufficient to test protobuf layout;
    // they are deliberately not valid authentication credentials.
    const loginHex = '0a02aabb120201021801';
    final login = wire.LoginRequest(
      groupFingerprint: [0xaa, 0xbb],
      participantId: [1, 2],
      protocolVersion: noosphereRoastProtocolVersion,
    );
    expect(cl.bytesToHex(login.writeToBuffer()), loginHex);
    expect(
      wire.LoginRequest.fromBuffer(cl.hexToBytes(loginHex)).protocolVersion,
      1,
    );
    // Operation 1 is a one-byte QUIC varint, followed directly by LoginRequest.
    const streamHex = '01$loginHex';
    expect(
      cl.bytesToHex(
        Uint8List.fromList([
          ...wire.encodeQuicVarInt(wire.RoastOperation.login.id),
          ...login.writeToBuffer(),
        ]),
      ),
      streamHex,
    );
  });

  test('typed participant event retains fixed protobuf wire bytes', () {
    // EventMessage oneof field 1 contains ParticipantStatusEvent. Its field 1 is an
    // opaque participant ID and field 2 is the login boolean.
    const eventHex = '0a060a02aabb1001';
    final event = wire.EventMessage(
      participantStatus: wire.ParticipantStatusEvent(
        participantId: [0xaa, 0xbb],
        loggedIn: true,
      ),
    );
    expect(cl.bytesToHex(event.writeToBuffer()), eventHex);

    final decoded = wire.EventMessage.fromBuffer(cl.hexToBytes(eventHex));
    expect(decoded.whichEvent(), wire.EventMessage_Event.participantStatus);
    expect(decoded.participantStatus.participantId, [0xaa, 0xbb]);
    expect(decoded.participantStatus.loggedIn, isTrue);
  });
}

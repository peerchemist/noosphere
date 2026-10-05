import 'package:noosphere/wire.dart' as protocol;
import 'package:protobuf/protobuf.dart';
import 'package:test/test.dart';

void main() {
  test('operation IDs are unique and map back to concrete operations', () {
    expect(
      protocol.RoastOperation.values.map((operation) => operation.id).toSet(),
      hasLength(protocol.RoastOperation.values.length),
    );
    expect(
      protocol.EnrollmentOperation.values
          .map((operation) => operation.id)
          .toSet(),
      hasLength(protocol.EnrollmentOperation.values.length),
    );
    for (final operation in protocol.RoastOperation.values) {
      expect(protocol.RoastOperation.fromId(operation.id), operation);
    }
    expect(protocol.RoastOperation.fromId(999), isNull);
  });

  test('all concrete RPC request and response protobufs round-trip', () {
    final messages = <GeneratedMessage>[
      protocol.LoginRequest(groupFingerprint: [1]),
      protocol.SignedAuthChallenge(signature: [1]),
      protocol.Bytes(data: [1]),
      protocol.DkgRequest(sid: [1]),
      protocol.DkgToReject(sid: [1]),
      protocol.DkgCommitment(sid: [1]),
      protocol.DkgRound2(sid: [1]),
      protocol.DkgAcks(sid: [1]),
      protocol.DkgAckRequest(sid: [1]),
      protocol.SignaturesRequest(sid: [1]),
      protocol.SignaturesRejection(sid: [1]),
      protocol.SignaturesReplies(sid: [1]),
      protocol.SecretShare(sid: [1]),
      protocol.ConstructedKey(sid: [1]),
      protocol.StartSession(),
      protocol.BeginEnrollmentRequest(invite: [1]),
      protocol.RedeemRoomInviteRequest(transcript: [1]),
      protocol.LoginResponse(challenge: [1]),
      protocol.RespondToChallengeResponse(),
      protocol.ExtendSessionResponse(expiry: [1]),
      protocol.RequestNewDkgResponse(),
      protocol.RejectDkgResponse(),
      protocol.SubmitDkgCommitmentResponse(),
      protocol.SubmitDkgRound2Response(),
      protocol.SendDkgAcksResponse(),
      protocol.RequestDkgAcksResponse(
        acks: [
          [1],
        ],
      ),
      protocol.RequestSignaturesResponse(),
      protocol.RejectSignaturesRequestResponse(),
      protocol.SubmitSignatureRepliesResponse(
        noUpdate: protocol.NoSignatureUpdate(),
      ),
      protocol.ShareSecretShareResponse(),
      protocol.AckKeyConstructedResponse(),
      protocol.BeginEnrollmentResponse(challenge: [1]),
      protocol.RedeemRoomInviteResponse(snapshot: [1]),
    ];

    for (final message in messages) {
      final bytes = message.writeToBuffer();
      final decoded = message.createEmptyInstance()..mergeFromBuffer(bytes);
      expect(decoded.writeToBuffer(), bytes, reason: message.info_.messageName);
    }
  });

  test('protocol errors preserve an explicitly zero room failure code', () {
    final absent = protocol.ProtocolError.fromBuffer(
      protocol.ProtocolError().writeToBuffer(),
    );
    final zero = protocol.ProtocolError.fromBuffer(
      protocol.ProtocolError(roomFailureCode: 0).writeToBuffer(),
    );
    expect(absent.hasRoomFailureCode(), isFalse);
    expect(zero.hasRoomFailureCode(), isTrue);
  });

  test('session records remain concrete protobuf messages', () {
    final started = protocol.SessionStarted.fromBuffer(
      protocol.SessionStarted(sessionId: [5], snapshot: [6]).writeToBuffer(),
    );
    final event = protocol.EventMessage.fromBuffer(
      protocol.EventMessage(keepalive: protocol.KeepaliveEvent())
          .writeToBuffer(),
    );
    expect(started.sessionId, [5]);
    expect(started.snapshot, [6]);
    expect(event.whichEvent(), protocol.EventMessage_Event.keepalive);
  });
}

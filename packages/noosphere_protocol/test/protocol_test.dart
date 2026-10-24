import 'package:noosphere_protocol/wire.dart' as protocol;
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

  test('CBOR wire protocols do not reuse protobuf ALPN identifiers', () {
    expect(protocol.noosphereIrohAlpn, 'noosphere/roast-cbor/1');
    expect(
      protocol.noosphereEnrollmentAlpn,
      'noosphere/roast-enrollment-cbor/1',
    );
    expect(protocol.noospherePublicFeedAlpn, 'noosphere/public-feed-cbor/1');
    expect(protocol.noosphereIrohAlpn, isNot('noosphere/roast/1'));
  });

  test('all concrete RPC request and response CBOR messages round-trip', () {
    final messages =
        <(protocol.WireMessage, protocol.WireMessage Function(List<int>))>[
          (protocol.LoginRequest(), protocol.LoginRequest.fromBuffer),
          (
            protocol.SignedAuthChallenge(),
            protocol.SignedAuthChallenge.fromBuffer,
          ),
          (protocol.Bytes(), protocol.Bytes.fromBuffer),
          (protocol.DkgRequest(), protocol.DkgRequest.fromBuffer),
          (protocol.DkgReference(), protocol.DkgReference.fromBuffer),
          (protocol.DkgCommitment(), protocol.DkgCommitment.fromBuffer),
          (protocol.DkgRound2(), protocol.DkgRound2.fromBuffer),
          (protocol.DkgAcks(), protocol.DkgAcks.fromBuffer),
          (protocol.DkgAckRequest(), protocol.DkgAckRequest.fromBuffer),
          (protocol.SignaturesRequest(), protocol.SignaturesRequest.fromBuffer),
          (
            protocol.SignaturesRejection(),
            protocol.SignaturesRejection.fromBuffer,
          ),
          (
            protocol.CancelSignaturesRequest(),
            protocol.CancelSignaturesRequest.fromBuffer,
          ),
          (protocol.SignaturesReplies(), protocol.SignaturesReplies.fromBuffer),
          (protocol.SecretShare(), protocol.SecretShare.fromBuffer),
          (protocol.ConstructedKey(), protocol.ConstructedKey.fromBuffer),
          (protocol.StartSession(), protocol.StartSession.fromBuffer),
          (
            protocol.BeginEnrollmentRequest(),
            protocol.BeginEnrollmentRequest.fromBuffer,
          ),
          (
            protocol.RedeemRoomInviteRequest(),
            protocol.RedeemRoomInviteRequest.fromBuffer,
          ),
          (protocol.LoginResponse(), protocol.LoginResponse.fromBuffer),
          (
            protocol.RespondToChallengeResponse(),
            protocol.RespondToChallengeResponse.fromBuffer,
          ),
          (
            protocol.ExtendSessionResponse(),
            protocol.ExtendSessionResponse.fromBuffer,
          ),
          (
            protocol.RequestNewDkgResponse(),
            protocol.RequestNewDkgResponse.fromBuffer,
          ),
          (protocol.RejectDkgResponse(), protocol.RejectDkgResponse.fromBuffer),
          (
            protocol.SubmitDkgCommitmentResponse(),
            protocol.SubmitDkgCommitmentResponse.fromBuffer,
          ),
          (
            protocol.SubmitDkgRound2Response(),
            protocol.SubmitDkgRound2Response.fromBuffer,
          ),
          (
            protocol.SendDkgAcksResponse(),
            protocol.SendDkgAcksResponse.fromBuffer,
          ),
          (
            protocol.RequestDkgAcksResponse(),
            protocol.RequestDkgAcksResponse.fromBuffer,
          ),
          (
            protocol.RequestSignaturesResponse(),
            protocol.RequestSignaturesResponse.fromBuffer,
          ),
          (
            protocol.RejectSignaturesRequestResponse(),
            protocol.RejectSignaturesRequestResponse.fromBuffer,
          ),
          for (final result in protocol.CancelSignaturesRequestResult.values)
            (
              protocol.CancelSignaturesRequestResponse(result: result),
              protocol.CancelSignaturesRequestResponse.fromBuffer,
            ),
          (
            protocol.SubmitSignatureRepliesResponse(
              outcome: protocol.NoSignatureUpdate(),
            ),
            protocol.SubmitSignatureRepliesResponse.fromBuffer,
          ),
          (
            protocol.SubmitSignatureRepliesResponse(
              outcome: protocol.NewSignatureRound(data: [1]),
            ),
            protocol.SubmitSignatureRepliesResponse.fromBuffer,
          ),
          (
            protocol.SubmitSignatureRepliesResponse(
              outcome: protocol.CompletedSignatures(data: [2]),
            ),
            protocol.SubmitSignatureRepliesResponse.fromBuffer,
          ),
          (
            protocol.ShareSecretShareResponse(),
            protocol.ShareSecretShareResponse.fromBuffer,
          ),
          (
            protocol.AckKeyConstructedResponse(),
            protocol.AckKeyConstructedResponse.fromBuffer,
          ),
          (
            protocol.BeginEnrollmentResponse(),
            protocol.BeginEnrollmentResponse.fromBuffer,
          ),
          (
            protocol.RedeemRoomInviteResponse(),
            protocol.RedeemRoomInviteResponse.fromBuffer,
          ),
        ];

    for (final (message, decode) in messages) {
      final bytes = message.writeToBuffer();
      expect(decode(bytes).writeToBuffer(), bytes, reason: '$message');
    }
  });

  test('protocol errors preserve an explicitly zero room failure code', () {
    final absent = protocol.ProtocolError.fromBuffer(
      protocol.ProtocolError().writeToBuffer(),
    );
    final zero = protocol.ProtocolError.fromBuffer(
      protocol.ProtocolError(roomFailureCode: 0).writeToBuffer(),
    );
    expect(absent.roomFailureCode, isNull);
    expect(zero.roomFailureCode, 0);
  });

  test('session records remain concrete CBOR messages', () {
    final started = protocol.SessionStarted.fromBuffer(
      protocol.SessionStarted(sessionId: [5], snapshot: [6]).writeToBuffer(),
    );
    final event = protocol.EventMessage.fromBuffer(
      protocol.EventMessage(event: protocol.KeepaliveEvent()).writeToBuffer(),
    );
    expect(started.sessionId, [5]);
    expect(started.snapshot, [6]);
    expect(event.event, isA<protocol.KeepaliveEvent>());
  });
}

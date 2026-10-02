import 'package:noosphere/domain.dart' show noosphereRoastProtocolVersion;
import 'package:noosphere/noosphere.dart' as protocol;
import 'package:protobuf/protobuf.dart';
import 'package:test/test.dart';

void main() {
  group('protobuf messages', () {
    test('all domain messages round-trip their exact wire bytes', () {
      final cases = <(GeneratedMessage, GeneratedMessage Function(List<int>))>[
        (protocol.Bytes(data: [1, 2]), protocol.Bytes.fromBuffer),
        (
          protocol.LoginRequest(
            groupFingerprint: [1],
            participantId: [2],
            protocolVersion: noosphereRoastProtocolVersion,
          ),
          protocol.LoginRequest.fromBuffer,
        ),
        (
          protocol.SignedAuthChallenge(signature: [1], challenge: [2]),
          protocol.SignedAuthChallenge.fromBuffer,
        ),
        (
          protocol.DkgRequest(sid: [1], signedDetails: [2], commitment: [3]),
          protocol.DkgRequest.fromBuffer,
        ),
        (
          protocol.DkgToReject(sid: [1], name: 'dkg'),
          protocol.DkgToReject.fromBuffer,
        ),
        (
          protocol.DkgCommitment(sid: [1], name: 'dkg', commitment: [2]),
          protocol.DkgCommitment.fromBuffer,
        ),
        (
          protocol.DkgSecret(id: [1], secret: [2]),
          protocol.DkgSecret.fromBuffer,
        ),
        (
          protocol.DkgRound2(
            sid: [1],
            name: 'dkg',
            commitmentSetSignature: [2],
            secrets: [
              protocol.DkgSecret(id: [3], secret: [4]),
            ],
          ),
          protocol.DkgRound2.fromBuffer,
        ),
        (
          protocol.DkgAcks(
            sid: [1],
            acks: [
              [2],
              [3],
            ],
          ),
          protocol.DkgAcks.fromBuffer,
        ),
        (
          protocol.DkgAckRequest(
            sid: [1],
            requests: [
              [2],
            ],
          ),
          protocol.DkgAckRequest.fromBuffer,
        ),
        (
          protocol.SignaturesRequest(
            sid: [1],
            keys: [
              [2],
            ],
            signedDetails: [3],
            commitments: [
              [4],
            ],
          ),
          protocol.SignaturesRequest.fromBuffer,
        ),
        (
          protocol.SignaturesRejection(sid: [1], reqId: [2]),
          protocol.SignaturesRejection.fromBuffer,
        ),
        (
          protocol.SignaturesReplies(
            sid: [1],
            reqId: [2],
            replies: [
              [3],
            ],
          ),
          protocol.SignaturesReplies.fromBuffer,
        ),
        (
          protocol.EncryptedSecret(id: [1], share: [2]),
          protocol.EncryptedSecret.fromBuffer,
        ),
        (
          protocol.SecretShare(
            sid: [1],
            groupKey: [2],
            secrets: [
              protocol.EncryptedSecret(id: [3], share: [4]),
            ],
          ),
          protocol.SecretShare.fromBuffer,
        ),
        (
          protocol.ConstructedKey(sid: [1], constructedKey: [2]),
          protocol.ConstructedKey.fromBuffer,
        ),
        (
          protocol.Events(
            type: protocol.EventType.SIG_COMPLETE_EVENT,
            data: [1, 2],
          ),
          protocol.Events.fromBuffer,
        ),
      ];

      for (final (message, parseMessage) in cases) {
        final wireBytes = message.writeToBuffer();
        expect(
          parseMessage(wireBytes).writeToBuffer(),
          wireBytes,
          reason: message.info_.messageName,
        );
      }
    });
  });

  group('typed RPC envelopes', () {
    test('covers all ROAST and enrollment RPC types', () {
      final requests = <protocol.RpcRequest>[
        protocol.RpcRequest(login: protocol.LoginRequest()),
        protocol.RpcRequest(respondToChallenge: protocol.SignedAuthChallenge()),
        protocol.RpcRequest(extendSession: protocol.Bytes()),
        protocol.RpcRequest(requestNewDkg: protocol.DkgRequest()),
        protocol.RpcRequest(rejectDkg: protocol.DkgToReject()),
        protocol.RpcRequest(submitDkgCommitment: protocol.DkgCommitment()),
        protocol.RpcRequest(submitDkgRound2: protocol.DkgRound2()),
        protocol.RpcRequest(sendDkgAcks: protocol.DkgAcks()),
        protocol.RpcRequest(requestDkgAcks: protocol.DkgAckRequest()),
        protocol.RpcRequest(requestSignatures: protocol.SignaturesRequest()),
        protocol.RpcRequest(
          rejectSignaturesRequest: protocol.SignaturesRejection(),
        ),
        protocol.RpcRequest(
          submitSignatureReplies: protocol.SignaturesReplies(),
        ),
        protocol.RpcRequest(shareSecretShare: protocol.SecretShare()),
        protocol.RpcRequest(ackKeyConstructed: protocol.ConstructedKey()),
        protocol.RpcRequest(
          beginEnrollment: protocol.BeginEnrollmentRequest(
            invite: [1],
            participantPublicKey: [2],
          ),
        ),
        protocol.RpcRequest(
          redeemRoomInvite: protocol.RedeemRoomInviteRequest(
            transcript: [3],
            signature: [4],
          ),
        ),
      ];
      final responses = <protocol.RpcResponse>[
        protocol.RpcResponse(login: protocol.LoginResponse()),
        protocol.RpcResponse(
          respondToChallenge: protocol.RespondToChallengeResponse(),
        ),
        protocol.RpcResponse(extendSession: protocol.ExtendSessionResponse()),
        protocol.RpcResponse(requestNewDkg: protocol.RequestNewDkgResponse()),
        protocol.RpcResponse(rejectDkg: protocol.RejectDkgResponse()),
        protocol.RpcResponse(
          submitDkgCommitment: protocol.SubmitDkgCommitmentResponse(),
        ),
        protocol.RpcResponse(
          submitDkgRound2: protocol.SubmitDkgRound2Response(),
        ),
        protocol.RpcResponse(sendDkgAcks: protocol.SendDkgAcksResponse()),
        protocol.RpcResponse(requestDkgAcks: protocol.RequestDkgAcksResponse()),
        protocol.RpcResponse(
          requestSignatures: protocol.RequestSignaturesResponse(),
        ),
        protocol.RpcResponse(
          rejectSignaturesRequest: protocol.RejectSignaturesRequestResponse(),
        ),
        protocol.RpcResponse(
          submitSignatureReplies: protocol.SubmitSignatureRepliesResponse(),
        ),
        protocol.RpcResponse(
          shareSecretShare: protocol.ShareSecretShareResponse(),
        ),
        protocol.RpcResponse(
          ackKeyConstructed: protocol.AckKeyConstructedResponse(),
        ),
        protocol.RpcResponse(
          beginEnrollment: protocol.BeginEnrollmentResponse(challenge: [5]),
        ),
        protocol.RpcResponse(
          redeemRoomInvite: protocol.RedeemRoomInviteResponse(snapshot: [6]),
        ),
      ];

      expect(
        requests.map((request) => request.whichRequest()).toSet(),
        hasLength(16),
      );
      expect(
        responses.map((response) => response.whichResponse()).toSet(),
        hasLength(16),
      );
      expect(
        requests,
        everyElement(
          predicate<protocol.RpcRequest>(
            (request) =>
                request.whichRequest() != protocol.RpcRequest_Request.notSet,
          ),
        ),
      );
      expect(
        responses,
        everyElement(
          predicate<protocol.RpcResponse>(
            (response) =>
                response.whichResponse() !=
                protocol.RpcResponse_Response.notSet,
          ),
        ),
      );
    });

    test('distinguishes absent and zero-valued room failure codes', () {
      final absent = protocol.ProtocolError.fromBuffer(
        protocol.ProtocolError(
          code: protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
        ).writeToBuffer(),
      );
      final zero = protocol.ProtocolError.fromBuffer(
        protocol.ProtocolError(
          code: protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
          roomFailureCode: 0,
        ).writeToBuffer(),
      );
      expect(absent.hasRoomFailureCode(), isFalse);
      expect(zero.hasRoomFailureCode(), isTrue);
      expect(zero.roomFailureCode, 0);
    });

    test('round-trips request ID and nested request oneof', () {
      final envelope = protocol.Envelope(
        wireVersion: 1,
        rpcRequest: protocol.RpcRequest(
          requestId: [9, 8, 7],
          submitSignatureReplies: protocol.SignaturesReplies(
            sid: [1],
            reqId: [2],
            replies: [
              [3],
            ],
          ),
        ),
      );

      final decoded = protocol.Envelope.fromBuffer(envelope.writeToBuffer());

      expect(decoded.whichPayload(), protocol.Envelope_Payload.rpcRequest);
      expect(decoded.rpcRequest.requestId, [9, 8, 7]);
      expect(
        decoded.rpcRequest.whichRequest(),
        protocol.RpcRequest_Request.submitSignatureReplies,
      );
    });

    test('represents all submitSignatureReplies outcomes', () {
      final outcomes = <protocol.SubmitSignatureRepliesResponse>[
        protocol.SubmitSignatureRepliesResponse(
          noUpdate: protocol.NoSignatureUpdate(),
        ),
        protocol.SubmitSignatureRepliesResponse(
          newRound: protocol.NewSignatureRound(data: [1]),
        ),
        protocol.SubmitSignatureRepliesResponse(
          completed: protocol.CompletedSignatures(data: [2]),
        ),
      ];

      expect(
        outcomes
            .map(
              (outcome) => protocol.SubmitSignatureRepliesResponse.fromBuffer(
                outcome.writeToBuffer(),
              ).whichOutcome(),
            )
            .toSet(),
        {
          protocol.SubmitSignatureRepliesResponse_Outcome.noUpdate,
          protocol.SubmitSignatureRepliesResponse_Outcome.newRound,
          protocol.SubmitSignatureRepliesResponse_Outcome.completed,
        },
      );
    });
  });

  group('session messages', () {
    test('round-trips a snapshot and event', () {
      final started = protocol.Envelope(
        wireVersion: 1,
        sessionStarted: protocol.SessionStarted(sessionId: [5], snapshot: [6]),
      );
      final event = protocol.Envelope(
        wireVersion: 1,
        event: protocol.Events(
          type: protocol.EventType.KEEPALIVE_EVENT,
          data: [7],
        ),
      );

      final decodedStarted = protocol.Envelope.fromBuffer(
        started.writeToBuffer(),
      );
      final decodedEvent = protocol.Envelope.fromBuffer(event.writeToBuffer());

      expect(decodedStarted.sessionStarted.sessionId, [5]);
      expect(decodedStarted.sessionStarted.snapshot, [6]);
      expect(decodedEvent.event.type, protocol.EventType.KEEPALIVE_EVENT);
    });

    test('empty and unknown payloads remain unset', () {
      expect(
        protocol.Envelope().whichPayload(),
        protocol.Envelope_Payload.notSet,
      );

      // wire_version = 1 followed by unknown length-delimited field 99.
      final unknown = protocol.Envelope.fromBuffer([8, 1, 154, 6, 0]);
      expect(unknown.wireVersion, 1);
      expect(unknown.whichPayload(), protocol.Envelope_Payload.notSet);
    });
  });
}

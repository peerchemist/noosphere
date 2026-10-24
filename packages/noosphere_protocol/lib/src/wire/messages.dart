// ignore_for_file: camel_case_types, constant_identifier_names, use_null_aware_elements

import 'cbor_codec.dart';

enum CancelSignaturesRequestResult {
  CANCEL_SIGNATURES_CANCELLED(0),
  CANCEL_SIGNATURES_ALREADY_CANCELLED(1),
  CANCEL_SIGNATURES_ALREADY_COMPLETED(2),
  CANCEL_SIGNATURES_ALREADY_TERMINAL(3),
  CANCEL_SIGNATURES_NOT_FOUND(4);

  const CancelSignaturesRequestResult(this.id);
  final int id;

  static CancelSignaturesRequestResult fromId(int id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => throw FormatException('Unknown cancellation result $id'),
  );
}

enum SignaturesProgressStage {
  SIGNATURES_PROGRESS_COLLECTING(0),
  SIGNATURES_PROGRESS_SIGNING(1),
  SIGNATURES_PROGRESS_COMPLETED(2),
  SIGNATURES_PROGRESS_FAILED(3);

  const SignaturesProgressStage(this.id);
  final int id;

  static SignaturesProgressStage fromId(int id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () =>
        throw FormatException('Unknown signatures progress stage $id'),
  );
}

enum ProtocolErrorCode {
  PROTOCOL_ERROR_UNSPECIFIED(0),
  PROTOCOL_ERROR_INVALID_REQUEST(1),
  PROTOCOL_ERROR_UNAUTHENTICATED(2),
  PROTOCOL_ERROR_UNSUPPORTED_VERSION(3),
  PROTOCOL_ERROR_RESOURCE_EXHAUSTED(4),
  PROTOCOL_ERROR_DEADLINE_EXCEEDED(5),
  PROTOCOL_ERROR_INTERNAL(6),
  PROTOCOL_ERROR_UNKNOWN_OUTCOME(7),
  PROTOCOL_ERROR_SESSION_NOT_FOUND(8),
  PROTOCOL_ERROR_SESSION_EXPIRED(9),
  PROTOCOL_ERROR_NOT_FOUND(10);

  const ProtocolErrorCode(this.id);
  final int id;

  static ProtocolErrorCode fromId(int id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => throw FormatException('Unknown protocol error code $id'),
  );
}

final class Bytes({this.data = const []}) extends WireMessage {
  final List<int> data;
  factory Bytes.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1});
    return Bytes(data: readBytes(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: data};
}

final class LoginRequest({
  this.groupFingerprint = const [],
  this.participantId = const [],
  this.protocolVersion = 0,
}) extends WireMessage {
  final List<int> groupFingerprint;
  final List<int> participantId;
  final int protocolVersion;
  factory LoginRequest.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3});
    return LoginRequest(
      groupFingerprint: readBytes(map, 1),
      participantId: readBytes(map, 2),
      protocolVersion: readInt(map, 3, maximum: 0xffffffff),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: groupFingerprint,
    2: participantId,
    3: protocolVersion,
  };
}

final class SignedAuthChallenge({
  this.signature = const [],
  this.challenge = const [],
}) extends WireMessage {
  final List<int> signature;
  final List<int> challenge;
  factory SignedAuthChallenge.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return SignedAuthChallenge(
      signature: readBytes(map, 1),
      challenge: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: signature, 2: challenge};
}

final class DkgRequest({
  this.sid = const [],
  this.signedDetails = const [],
  this.commitment = const [],
}) extends WireMessage {
  final List<int> sid;
  final List<int> signedDetails;
  final List<int> commitment;
  factory DkgRequest.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3});
    return DkgRequest(
      sid: readBytes(map, 1),
      signedDetails: readBytes(map, 2),
      commitment: readBytes(map, 3),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sid, 2: signedDetails, 3: commitment};
}

final class DkgReference({
  this.sid = const [],
  this.name = '',
  this.ceremonyId = const [],
}) extends WireMessage {
  final List<int> sid;
  final String name;
  final List<int> ceremonyId;
  factory DkgReference.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3});
    return DkgReference(
      sid: readBytes(map, 1),
      name: readString(map, 2),
      ceremonyId: readBytes(map, 3),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sid, 2: name, 3: ceremonyId};
}

final class DkgCommitment({
  this.sid = const [],
  this.name = '',
  this.commitment = const [],
  this.ceremonyId = const [],
}) extends WireMessage {
  final List<int> sid;
  final String name;
  final List<int> commitment;
  final List<int> ceremonyId;
  factory DkgCommitment.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3, 4});
    return DkgCommitment(
      sid: readBytes(map, 1),
      name: readString(map, 2),
      commitment: readBytes(map, 3),
      ceremonyId: readBytes(map, 4),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: sid,
    2: name,
    3: commitment,
    4: ceremonyId,
  };
}

final class DkgSecret({this.id = const [], this.secret = const []})
    extends WireMessage {
  final List<int> id;
  final List<int> secret;
  factory DkgSecret.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return DkgSecret(id: readBytes(map, 1), secret: readBytes(map, 2));
  }
  @override
  Map<int, Object?> get cborFields => {1: id, 2: secret};
}

final class DkgRound2({
  this.sid = const [],
  this.name = '',
  this.commitmentSetSignature = const [],
  this.secrets = const [],
  this.ceremonyId = const [],
}) extends WireMessage {
  final List<int> sid;
  final String name;
  final List<int> commitmentSetSignature;
  final List<DkgSecret> secrets;
  final List<int> ceremonyId;
  factory DkgRound2.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3, 4, 5});
    return DkgRound2(
      sid: readBytes(map, 1),
      name: readString(map, 2),
      commitmentSetSignature: readBytes(map, 3),
      secrets: readListOf(map, 4, DkgSecret.fromCbor),
      ceremonyId: readBytes(map, 5),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: sid,
    2: name,
    3: commitmentSetSignature,
    4: secrets,
    5: ceremonyId,
  };
}

final class DkgAcks({this.sid = const [], this.acks = const []})
    extends WireMessage {
  final List<int> sid;
  final List<List<int>> acks;
  factory DkgAcks.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return DkgAcks(sid: readBytes(map, 1), acks: readBytesList(map, 2));
  }
  @override
  Map<int, Object?> get cborFields => {1: sid, 2: acks};
}

final class DkgAckRequest({this.sid = const [], this.requests = const []})
    extends WireMessage {
  final List<int> sid;
  final List<List<int>> requests;
  factory DkgAckRequest.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return DkgAckRequest(
      sid: readBytes(map, 1),
      requests: readBytesList(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sid, 2: requests};
}

final class SignaturesRequest({
  this.sid = const [],
  this.keys = const [],
  this.signedDetails = const [],
  this.commitments = const [],
}) extends WireMessage {
  final List<int> sid;
  final List<List<int>> keys;
  final List<int> signedDetails;
  final List<List<int>> commitments;
  factory SignaturesRequest.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3, 4});
    return SignaturesRequest(
      sid: readBytes(map, 1),
      keys: readBytesList(map, 2),
      signedDetails: readBytes(map, 3),
      commitments: readBytesList(map, 4),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: sid,
    2: keys,
    3: signedDetails,
    4: commitments,
  };
}

final class SignaturesRejection({this.sid = const [], this.reqId = const []})
    extends WireMessage {
  final List<int> sid;
  final List<int> reqId;
  factory SignaturesRejection.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return SignaturesRejection(
      sid: readBytes(map, 1),
      reqId: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sid, 2: reqId};
}

final class CancelSignaturesRequest({
  this.sessionId = const [],
  this.requestId = const [],
}) extends WireMessage {
  final List<int> sessionId;
  final List<int> requestId;
  factory CancelSignaturesRequest.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return CancelSignaturesRequest(
      sessionId: readBytes(map, 1),
      requestId: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sessionId, 2: requestId};
}

final class CancelSignaturesRequestResponse({
  required this.result,
  this.expiresAt = const [],
}) extends WireMessage {
  final CancelSignaturesRequestResult result;
  final List<int> expiresAt;
  factory CancelSignaturesRequestResponse.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return CancelSignaturesRequestResponse(
      result: CancelSignaturesRequestResult.fromId(readInt(map, 1)),
      expiresAt: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: result.id, 2: expiresAt};
}

final class SignaturesReplies({
  this.sid = const [],
  this.reqId = const [],
  this.replies = const [],
}) extends WireMessage {
  final List<int> sid;
  final List<int> reqId;
  final List<List<int>> replies;
  factory SignaturesReplies.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3});
    return SignaturesReplies(
      sid: readBytes(map, 1),
      reqId: readBytes(map, 2),
      replies: readBytesList(map, 3),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sid, 2: reqId, 3: replies};
}

final class EncryptedSecret({this.id = const [], this.share = const []})
    extends WireMessage {
  final List<int> id;
  final List<int> share;
  factory EncryptedSecret.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return EncryptedSecret(id: readBytes(map, 1), share: readBytes(map, 2));
  }
  @override
  Map<int, Object?> get cborFields => {1: id, 2: share};
}

final class SecretShare({
  this.sid = const [],
  this.groupKey = const [],
  this.secrets = const [],
}) extends WireMessage {
  final List<int> sid;
  final List<int> groupKey;
  final List<EncryptedSecret> secrets;
  factory SecretShare.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3});
    return SecretShare(
      sid: readBytes(map, 1),
      groupKey: readBytes(map, 2),
      secrets: readListOf(map, 3, EncryptedSecret.fromCbor),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sid, 2: groupKey, 3: secrets};
}

final class ConstructedKey({
  this.sid = const [],
  this.constructedKey = const [],
}) extends WireMessage {
  final List<int> sid;
  final List<int> constructedKey;
  factory ConstructedKey.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return ConstructedKey(
      sid: readBytes(map, 1),
      constructedKey: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sid, 2: constructedKey};
}

final class ProtocolError({
  this.code = ProtocolErrorCode.PROTOCOL_ERROR_UNSPECIFIED,
  this.message = '',
  this.retryable = false,
  this.roomFailureCode,
}) extends WireMessage {
  final ProtocolErrorCode code;
  final String message;
  final bool retryable;
  final int? roomFailureCode;
  factory ProtocolError.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(
      bytes,
      requiredFields: {1, 2, 3},
      optionalFields: {4},
    );
    return ProtocolError(
      code: ProtocolErrorCode.fromId(readInt(map, 1)),
      message: readString(map, 2),
      retryable: readBool(map, 3),
      roomFailureCode: map.containsKey(4)
          ? readInt(map, 4, maximum: 0xffffffff)
          : null,
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: code.id,
    2: message,
    3: retryable,
    if (roomFailureCode case final value?) 4: value,
  };
}

abstract class _EmptyResponse extends WireMessage {
  const _EmptyResponse();
  @override
  Map<int, Object?> get cborFields => const {};
}

T _decodeEmpty<T extends WireMessage>(List<int> bytes, T Function() create) {
  decodeWireMap(bytes, requiredFields: const {});
  return create();
}

final class RespondToChallengeResponse() extends _EmptyResponse {
  factory RespondToChallengeResponse.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, RespondToChallengeResponse.new);
}

final class RequestNewDkgResponse() extends _EmptyResponse {
  factory RequestNewDkgResponse.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, RequestNewDkgResponse.new);
}

final class RejectDkgResponse() extends _EmptyResponse {
  factory RejectDkgResponse.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, RejectDkgResponse.new);
}

final class SubmitDkgCommitmentResponse() extends _EmptyResponse {
  factory SubmitDkgCommitmentResponse.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, SubmitDkgCommitmentResponse.new);
}

final class SubmitDkgRound2Response() extends _EmptyResponse {
  factory SubmitDkgRound2Response.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, SubmitDkgRound2Response.new);
}

final class SendDkgAcksResponse() extends _EmptyResponse {
  factory SendDkgAcksResponse.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, SendDkgAcksResponse.new);
}

final class RequestSignaturesResponse() extends _EmptyResponse {
  factory RequestSignaturesResponse.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, RequestSignaturesResponse.new);
}

final class RejectSignaturesRequestResponse() extends _EmptyResponse {
  factory RejectSignaturesRequestResponse.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, RejectSignaturesRequestResponse.new);
}

final class AckKeyConstructedResponse() extends _EmptyResponse {
  factory AckKeyConstructedResponse.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, AckKeyConstructedResponse.new);
}

final class LoginResponse({this.challenge = const []}) extends WireMessage {
  final List<int> challenge;
  factory LoginResponse.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1});
    return LoginResponse(challenge: readBytes(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: challenge};
}

final class ExtendSessionResponse({this.expiry = const []})
    extends WireMessage {
  final List<int> expiry;
  factory ExtendSessionResponse.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1});
    return ExtendSessionResponse(expiry: readBytes(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: expiry};
}

final class RequestDkgAcksResponse({this.acks = const []}) extends WireMessage {
  final List<List<int>> acks;
  factory RequestDkgAcksResponse.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1});
    return RequestDkgAcksResponse(acks: readBytesList(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: acks};
}

sealed class SignatureReplyOutcome extends WireMessage {
  const SignatureReplyOutcome();
  int get variantId;
}

final class NoSignatureUpdate() extends SignatureReplyOutcome {
  factory NoSignatureUpdate.fromCbor(Object? value) {
    readWireMap(value, requiredFields: const {});
    return NoSignatureUpdate();
  }
  @override
  int get variantId => 1;
  @override
  Map<int, Object?> get cborFields => const {};
}

final class NewSignatureRound({this.data = const []})
    extends SignatureReplyOutcome {
  final List<int> data;
  factory NewSignatureRound.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1});
    return NewSignatureRound(data: readBytes(map, 1));
  }
  @override
  int get variantId => 2;
  @override
  Map<int, Object?> get cborFields => {1: data};
}

final class CompletedSignatures({this.data = const []})
    extends SignatureReplyOutcome {
  final List<int> data;
  factory CompletedSignatures.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1});
    return CompletedSignatures(data: readBytes(map, 1));
  }
  @override
  int get variantId => 3;
  @override
  Map<int, Object?> get cborFields => {1: data};
}

final class SubmitSignatureRepliesResponse({required this.outcome})
    extends WireMessage {
  final SignatureReplyOutcome outcome;
  factory SubmitSignatureRepliesResponse.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    final variant = readInt(map, 1);
    final outcome = switch (variant) {
      1 => NoSignatureUpdate.fromCbor(map[2]),
      2 => NewSignatureRound.fromCbor(map[2]),
      3 => CompletedSignatures.fromCbor(map[2]),
      _ => throw FormatException('Unknown signature reply outcome $variant'),
    };
    return SubmitSignatureRepliesResponse(outcome: outcome);
  }
  @override
  Map<int, Object?> get cborFields => {1: outcome.variantId, 2: outcome};
}

final class ShareSecretShareResponse({this.constructedKeyEvents = const []})
    extends WireMessage {
  final List<ConstructedKeyEvent> constructedKeyEvents;
  factory ShareSecretShareResponse.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1});
    return ShareSecretShareResponse(
      constructedKeyEvents: readListOf(map, 1, ConstructedKeyEvent.fromCbor),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: constructedKeyEvents};
}

final class BeginEnrollmentRequest({
  this.invite = const [],
  this.participantPublicKey = const [],
}) extends WireMessage {
  final List<int> invite;
  final List<int> participantPublicKey;
  factory BeginEnrollmentRequest.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return BeginEnrollmentRequest(
      invite: readBytes(map, 1),
      participantPublicKey: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: invite, 2: participantPublicKey};
}

final class BeginEnrollmentResponse({this.challenge = const []})
    extends WireMessage {
  final List<int> challenge;
  factory BeginEnrollmentResponse.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1});
    return BeginEnrollmentResponse(challenge: readBytes(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: challenge};
}

final class RedeemRoomInviteRequest({
  this.transcript = const [],
  this.signature = const [],
}) extends WireMessage {
  final List<int> transcript;
  final List<int> signature;
  factory RedeemRoomInviteRequest.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return RedeemRoomInviteRequest(
      transcript: readBytes(map, 1),
      signature: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: transcript, 2: signature};
}

final class RedeemRoomInviteResponse({this.snapshot = const []})
    extends WireMessage {
  final List<int> snapshot;
  factory RedeemRoomInviteResponse.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1});
    return RedeemRoomInviteResponse(snapshot: readBytes(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: snapshot};
}

final class StartSession() extends WireMessage {
  factory StartSession.fromBuffer(List<int> bytes) =>
      _decodeEmpty(bytes, StartSession.new);
  @override
  Map<int, Object?> get cborFields => const {};
}

final class SessionStarted({
  this.sessionId = const [],
  this.snapshot = const [],
}) extends WireMessage {
  final List<int> sessionId;
  final List<int> snapshot;
  factory SessionStarted.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return SessionStarted(
      sessionId: readBytes(map, 1),
      snapshot: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: sessionId, 2: snapshot};
}

sealed class EventPayload extends WireMessage {
  const EventPayload();
}

final class SignaturesCancelledEvent({
  this.requestId = const [],
  this.expiresAt = const [],
}) extends EventPayload {
  final List<int> requestId;
  final List<int> expiresAt;
  factory SignaturesCancelledEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return SignaturesCancelledEvent(
      requestId: readBytes(map, 1),
      expiresAt: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: requestId, 2: expiresAt};
}

final class ParticipantStatusEvent({
  this.participantId = const [],
  this.loggedIn = false,
}) extends EventPayload {
  final List<int> participantId;
  final bool loggedIn;
  factory ParticipantStatusEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return ParticipantStatusEvent(
      participantId: readBytes(map, 1),
      loggedIn: readBool(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: participantId, 2: loggedIn};
}

final class DkgEventCommitment({
  this.participantId = const [],
  this.commitment = const [],
}) extends WireMessage {
  final List<int> participantId;
  final List<int> commitment;
  factory DkgEventCommitment.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return DkgEventCommitment(
      participantId: readBytes(map, 1),
      commitment: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: participantId, 2: commitment};
}

final class NewDkgEvent({
  this.signedDetails = const [],
  this.creatorId = const [],
  this.commitments = const [],
}) extends EventPayload {
  final List<int> signedDetails;
  final List<int> creatorId;
  final List<DkgEventCommitment> commitments;
  factory NewDkgEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2, 3});
    return NewDkgEvent(
      signedDetails: readBytes(map, 1),
      creatorId: readBytes(map, 2),
      commitments: readListOf(map, 3, DkgEventCommitment.fromCbor),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: signedDetails,
    2: creatorId,
    3: commitments,
  };
}

final class DkgCommitmentEvent({
  this.name = '',
  this.participantId = const [],
  this.commitment = const [],
  this.ceremonyId = const [],
}) extends EventPayload {
  final String name;
  final List<int> participantId;
  final List<int> commitment;
  final List<int> ceremonyId;
  factory DkgCommitmentEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2, 3, 4});
    return DkgCommitmentEvent(
      name: readString(map, 1),
      participantId: readBytes(map, 2),
      commitment: readBytes(map, 3),
      ceremonyId: readBytes(map, 4),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: name,
    2: participantId,
    3: commitment,
    4: ceremonyId,
  };
}

final class DkgRejectEvent({
  this.name = '',
  this.participantId = const [],
  this.ceremonyId = const [],
}) extends EventPayload {
  final String name;
  final List<int> participantId;
  final List<int> ceremonyId;
  factory DkgRejectEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2, 3});
    return DkgRejectEvent(
      name: readString(map, 1),
      participantId: readBytes(map, 2),
      ceremonyId: readBytes(map, 3),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: name,
    2: participantId,
    3: ceremonyId,
  };
}

final class DkgRound2ShareEvent({
  this.name = '',
  this.commitmentSetSignature = const [],
  this.senderId = const [],
  this.encryptedSecret = const [],
  this.ceremonyId = const [],
}) extends EventPayload {
  final String name;
  final List<int> commitmentSetSignature;
  final List<int> senderId;
  final List<int> encryptedSecret;
  final List<int> ceremonyId;
  factory DkgRound2ShareEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2, 3, 4, 5});
    return DkgRound2ShareEvent(
      name: readString(map, 1),
      commitmentSetSignature: readBytes(map, 2),
      senderId: readBytes(map, 3),
      encryptedSecret: readBytes(map, 4),
      ceremonyId: readBytes(map, 5),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: name,
    2: commitmentSetSignature,
    3: senderId,
    4: encryptedSecret,
    5: ceremonyId,
  };
}

final class DkgAckEvent({this.acks = const []}) extends EventPayload {
  final List<List<int>> acks;
  factory DkgAckEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1});
    return DkgAckEvent(acks: readBytesList(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: acks};
}

final class DkgAckRequestEvent({this.requests = const []})
    extends EventPayload {
  final List<List<int>> requests;
  factory DkgAckRequestEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1});
    return DkgAckRequestEvent(requests: readBytesList(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: requests};
}

final class SignaturesProgress({
  this.threshold = 0,
  this.contributingParticipantIds = const [],
  required this.stage,
}) extends WireMessage {
  final int threshold;
  final List<List<int>> contributingParticipantIds;
  final SignaturesProgressStage stage;
  factory SignaturesProgress.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2, 3});
    return SignaturesProgress(
      threshold: readInt(map, 1, maximum: 0xffffffff),
      contributingParticipantIds: readBytesList(map, 2),
      stage: SignaturesProgressStage.fromId(readInt(map, 3)),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: threshold,
    2: contributingParticipantIds,
    3: stage.id,
  };
}

final class SignaturesRequestEvent({
  this.signedDetails = const [],
  this.creatorId = const [],
  required this.progress,
}) extends EventPayload {
  final List<int> signedDetails;
  final List<int> creatorId;
  final SignaturesProgress progress;
  factory SignaturesRequestEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2, 3});
    return SignaturesRequestEvent(
      signedDetails: readBytes(map, 1),
      creatorId: readBytes(map, 2),
      progress: SignaturesProgress.fromCbor(map[3]),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: signedDetails,
    2: creatorId,
    3: progress,
  };
}

final class SignatureRoundStart({
  this.signatureIndex = 0,
  this.commitmentSet = const [],
}) extends WireMessage {
  final int signatureIndex;
  final List<int> commitmentSet;
  factory SignatureRoundStart.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return SignatureRoundStart(
      signatureIndex: readInt(map, 1, maximum: 0xffffffff),
      commitmentSet: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: signatureIndex, 2: commitmentSet};
}

final class SignatureNewRoundsEvent({
  this.requestId = const [],
  this.rounds = const [],
}) extends EventPayload {
  final List<int> requestId;
  final List<SignatureRoundStart> rounds;
  factory SignatureNewRoundsEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return SignatureNewRoundsEvent(
      requestId: readBytes(map, 1),
      rounds: readListOf(map, 2, SignatureRoundStart.fromCbor),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: requestId, 2: rounds};
}

final class SignaturesCompleteEvent({
  this.requestId = const [],
  this.signatures = const [],
}) extends EventPayload {
  final List<int> requestId;
  final List<List<int>> signatures;
  factory SignaturesCompleteEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return SignaturesCompleteEvent(
      requestId: readBytes(map, 1),
      signatures: readBytesList(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: requestId, 2: signatures};
}

final class SignaturesFailureEvent({this.requestId = const []})
    extends EventPayload {
  final List<int> requestId;
  factory SignaturesFailureEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1});
    return SignaturesFailureEvent(requestId: readBytes(map, 1));
  }
  @override
  Map<int, Object?> get cborFields => {1: requestId};
}

final class KeepaliveEvent() extends EventPayload {
  factory KeepaliveEvent.fromCbor(Object? value) {
    readWireMap(value, requiredFields: const {});
    return KeepaliveEvent();
  }
  @override
  Map<int, Object?> get cborFields => const {};
}

final class SecretShareEvent({
  this.senderId = const [],
  this.groupKey = const [],
  this.encryptedKeyShare = const [],
}) extends EventPayload {
  final List<int> senderId;
  final List<int> groupKey;
  final List<int> encryptedKeyShare;
  factory SecretShareEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2, 3});
    return SecretShareEvent(
      senderId: readBytes(map, 1),
      groupKey: readBytes(map, 2),
      encryptedKeyShare: readBytes(map, 3),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: senderId,
    2: groupKey,
    3: encryptedKeyShare,
  };
}

final class ConstructedKeyEvent({
  this.participantId = const [],
  this.signedConstructedKey = const [],
}) extends EventPayload {
  final List<int> participantId;
  final List<int> signedConstructedKey;
  factory ConstructedKeyEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return ConstructedKeyEvent(
      participantId: readBytes(map, 1),
      signedConstructedKey: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: participantId,
    2: signedConstructedKey,
  };
}

final class SignaturesProgressEvent({
  this.requestId = const [],
  required this.progress,
}) extends EventPayload {
  final List<int> requestId;
  final SignaturesProgress progress;
  factory SignaturesProgressEvent.fromCbor(Object? value) {
    final map = readWireMap(value, requiredFields: {1, 2});
    return SignaturesProgressEvent(
      requestId: readBytes(map, 1),
      progress: SignaturesProgress.fromCbor(map[2]),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: requestId, 2: progress};
}

final class EventMessage({required this.event}) extends WireMessage {
  final EventPayload event;

  factory EventMessage.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    final payload = map[2];
    final event = switch (readInt(map, 1, minimum: 1, maximum: 16)) {
      1 => ParticipantStatusEvent.fromCbor(payload),
      2 => NewDkgEvent.fromCbor(payload),
      3 => DkgCommitmentEvent.fromCbor(payload),
      4 => DkgRejectEvent.fromCbor(payload),
      5 => DkgRound2ShareEvent.fromCbor(payload),
      6 => DkgAckEvent.fromCbor(payload),
      7 => DkgAckRequestEvent.fromCbor(payload),
      8 => SignaturesRequestEvent.fromCbor(payload),
      9 => SignatureNewRoundsEvent.fromCbor(payload),
      10 => SignaturesCompleteEvent.fromCbor(payload),
      11 => SignaturesFailureEvent.fromCbor(payload),
      12 => KeepaliveEvent.fromCbor(payload),
      13 => SecretShareEvent.fromCbor(payload),
      14 => ConstructedKeyEvent.fromCbor(payload),
      15 => SignaturesProgressEvent.fromCbor(payload),
      16 => SignaturesCancelledEvent.fromCbor(payload),
      _ => throw StateError('unreachable'),
    };
    return EventMessage(event: event);
  }

  @override
  Map<int, Object?> get cborFields => {
    1: switch (event) {
      ParticipantStatusEvent() => 1,
      NewDkgEvent() => 2,
      DkgCommitmentEvent() => 3,
      DkgRejectEvent() => 4,
      DkgRound2ShareEvent() => 5,
      DkgAckEvent() => 6,
      DkgAckRequestEvent() => 7,
      SignaturesRequestEvent() => 8,
      SignatureNewRoundsEvent() => 9,
      SignaturesCompleteEvent() => 10,
      SignaturesFailureEvent() => 11,
      KeepaliveEvent() => 12,
      SecretShareEvent() => 13,
      ConstructedKeyEvent() => 14,
      SignaturesProgressEvent() => 15,
      SignaturesCancelledEvent() => 16,
    },
    2: event,
  };
}

final class GetPublicFeedRequest({
  this.feedId = const [],
  this.afterCursor = 0,
  this.limit = 0,
}) extends WireMessage {
  final List<int> feedId;
  final int afterCursor;
  final int limit;
  factory GetPublicFeedRequest.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2, 3});
    return GetPublicFeedRequest(
      feedId: readBytes(map, 1),
      afterCursor: readInt(map, 2),
      limit: readInt(map, 3, maximum: 0xffffffff),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: feedId, 2: afterCursor, 3: limit};
}

final class PublicFeedEntry({
  this.cursor = 0,
  this.eventId = const [],
  this.category = 0,
  this.state = 0,
  this.observedAtMs = 0,
  this.expiresAtMs,
}) extends WireMessage {
  final int cursor;
  final List<int> eventId;
  final int category;
  final int state;
  final int observedAtMs;
  final int? expiresAtMs;
  factory PublicFeedEntry.fromCbor(Object? value) {
    final map = readWireMap(
      value,
      requiredFields: {1, 2, 3, 4, 5},
      optionalFields: {6},
    );
    return PublicFeedEntry(
      cursor: readInt(map, 1),
      eventId: readBytes(map, 2),
      category: readInt(map, 3, maximum: 1),
      state: readInt(map, 4, maximum: 6),
      observedAtMs: readInt(map, 5, minimum: -0x8000000000000000),
      expiresAtMs: map.containsKey(6)
          ? readInt(map, 6, minimum: -0x8000000000000000)
          : null,
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: cursor,
    2: eventId,
    3: category,
    4: state,
    5: observedAtMs,
    if (expiresAtMs case final value?) 6: value,
  };
}

final class PublicFeedPage({
  this.schemaVersion = 0,
  this.feedId = const [],
  this.entries = const [],
  this.oldestAvailableCursor = 0,
  this.latestCursor = 0,
  this.nextCursor = 0,
  this.hasMore = false,
  this.historyGap = false,
  this.generatedAtMs = 0,
  this.afterCursor = 0,
}) extends WireMessage {
  final int schemaVersion;
  final List<int> feedId;
  final List<PublicFeedEntry> entries;
  final int oldestAvailableCursor;
  final int latestCursor;
  final int nextCursor;
  final bool hasMore;
  final bool historyGap;
  final int generatedAtMs;
  final int afterCursor;
  factory PublicFeedPage.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(
      bytes,
      requiredFields: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
    );
    return PublicFeedPage(
      schemaVersion: readInt(map, 1, maximum: 0xffffffff),
      feedId: readBytes(map, 2),
      entries: readListOf(map, 3, PublicFeedEntry.fromCbor),
      oldestAvailableCursor: readInt(map, 4),
      latestCursor: readInt(map, 5),
      nextCursor: readInt(map, 6),
      hasMore: readBool(map, 7),
      historyGap: readBool(map, 8),
      generatedAtMs: readInt(map, 9, minimum: -0x8000000000000000),
      afterCursor: readInt(map, 10),
    );
  }
  @override
  Map<int, Object?> get cborFields => {
    1: schemaVersion,
    2: feedId,
    3: entries,
    4: oldestAvailableCursor,
    5: latestCursor,
    6: nextCursor,
    7: hasMore,
    8: historyGap,
    9: generatedAtMs,
    10: afterCursor,
  };
}

final class SignedPublicFeedPage({
  this.page = const [],
  this.signature = const [],
}) extends WireMessage {
  final List<int> page;
  final List<int> signature;
  factory SignedPublicFeedPage.fromBuffer(List<int> bytes) {
    final map = decodeWireMap(bytes, requiredFields: {1, 2});
    return SignedPublicFeedPage(
      page: readBytes(map, 1),
      signature: readBytes(map, 2),
    );
  }
  @override
  Map<int, Object?> get cborFields => {1: page, 2: signature};
}

/// Operation identifiers sent as the first QUIC varint on a ROAST stream.
enum RoastOperation {
  login(1),
  respondToChallenge(2),
  extendSession(3),
  requestNewDkg(4),
  rejectDkg(5),
  submitDkgCommitment(6),
  submitDkgRound2(7),
  sendDkgAcks(8),
  requestDkgAcks(9),
  requestSignatures(10),
  rejectSignaturesRequest(11),
  submitSignatureReplies(12),
  shareSecretShare(13),
  ackKeyConstructed(14),
  startSession(15);

  const RoastOperation(this.id);
  final int id;

  static RoastOperation? fromId(int id) {
    for (final operation in values) {
      if (operation.id == id) return operation;
    }
    return null;
  }
}

/// Operation identifiers sent on the enrollment ALPN.
enum EnrollmentOperation {
  beginEnrollment(1),
  redeemRoomInvite(2);

  const EnrollmentOperation(this.id);
  final int id;

  static EnrollmentOperation? fromId(int id) {
    for (final operation in values) {
      if (operation.id == id) return operation;
    }
    return null;
  }
}

/// Response discriminators sent before a response protobuf.
abstract final class RpcResponseStatus {
  static const int success = 0;
  static const int error = 1;
}

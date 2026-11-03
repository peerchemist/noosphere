import 'package:noosphere_protocol/domain.dart';

import '../../config/server.dart';

/// Conservative encoded sizes for a single participant's SessionStarted body.
/// Reserve maximum growth at admission, then derive usage from retained state.
/// Nine bytes cover any domain vector/count prefix; native commitment bounds
/// below are enforced on input so their sizes cannot exceed the reservation.
abstract final class SnapshotReservations {
  // Session ID, expiry, start time, online roster, six vector prefixes, and
  // the outer deterministic-CBOR SessionStarted envelope (including its SID).
  static int header(int participants) => 128 + 32 * participants;

  // Frosty commitments contain 33-byte polynomial coefficients and a proof.
  // The allowance covers the pinned format's header, count and proof overhead.
  static int dkgCommitmentLimit(int threshold) => 128 + 33 * threshold;
  static const signingCommitmentLimit = 128;

  static int dkg(Signed<NewDkgDetails> details, int participants) =>
      9 +
      details.toBytes().length +
      32 +
      2 +
      participants * (32 + 9 + dkgCommitmentLimit(details.obj.threshold));

  static int signing(
    Signed<SignaturesRequestDetails> details,
    int participants,
  ) {
    final count = details.obj.requiredSigs.length;
    // Proposal, creator and maximum progress roster, plus at most one pending
    // round per signature for this recipient. Use the whole group as a bound
    // on every threshold. Completion and cancellation are smaller than this.
    return 9 +
        details.toBytes().length +
        32 +
        5 +
        32 * participants +
        9 +
        16 +
        9 +
        count * (9 + 2 + 2 + participants * (32 + 9 + signingCommitmentLimit));
  }

  // Reserve all other senders for any recipient when a recovery key is first
  // admitted. Pending shares may grow without further snapshot admission.
  static int recoveryKey(int participants) =>
      (participants - 1) *
      (9 + 32 + ServerConfig.maxEncryptedRecoveryShareBytes + 33);
}

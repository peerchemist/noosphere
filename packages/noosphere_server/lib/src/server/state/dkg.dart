import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/domain.dart';

abstract class DkgRoundState {}

/// Round 1 collects commitments from all the participants after they've
/// received the signed DKG details
class DkgRound1State extends DkgRoundState {
  final DkgCommitmentList commitments;
  DkgRound1State(this.commitments);
}

/// Round 2 collects signatures to verify the common dkg hash from all
/// participants and the encrypted secrets to share with particular
/// participants.
class DkgRound2State extends DkgRoundState {
  final Uint8List expectedHash;
  final DkgCommitmentList commitments;
  final int participantCount;
  final Map<Identifier, DkgRound2Contribution> contributions = {};

  DkgRound2State({
    required Uint8List expectedHash,
    DkgCommitmentList commitments = const [],
    int? participantCount,
  }) : expectedHash = Uint8List.fromList(expectedHash),
       commitments = List.unmodifiable(commitments),
       participantCount = participantCount ?? commitments.length;

  bool get allSharesSubmitted => contributions.length == participantCount;
}

/// The exact accepted round-two payload from one participant.
///
/// The coordinator retains this mailbox data until every participant has
/// durably acknowledged construction of the same group key. Ciphertexts are
/// only exposed to their addressed recipient.
class DkgRound2Contribution {
  final cl.SchnorrSignature commitmentSetSignature;
  final Map<Identifier, DkgEncryptedSecret> secrets;

  DkgRound2Contribution({
    required this.commitmentSetSignature,
    required Map<Identifier, DkgEncryptedSecret> secrets,
  }) : secrets = Map.unmodifiable(secrets);

  DkgRound2ShareEvent shareFor(
    String name,
    Uint8List ceremonyId,
    Identifier sender,
    Identifier id,
  ) => DkgRound2ShareEvent(
    name: name,
    ceremonyId: ceremonyId,
    commitmentSetSignature: commitmentSetSignature,
    sender: sender,
    secret: secrets[id]!,
  );
}

class DkgState implements Expirable {
  // Saved across the state so that details are available if round 1 needs to
  // be done again.
  final Signed<NewDkgDetails> details;
  final Identifier creator;

  /// The current round information
  DkgRoundState round;

  /// Participants that have durably stored their final key share.
  final Map<Identifier, Signed<DkgAck>> completionAcks = {};

  DkgState({
    required this.details,
    required this.creator,
    required DkgCommitmentList commitments,
  }) : round = DkgRound1State(commitments);

  @override
  Expiry get expiry => details.obj.expiry;

  DkgRound1State get round1 => round as DkgRound1State;
  DkgRound2State get round2 => round as DkgRound2State;

  bool get awaitingCompletion => switch (round) {
    DkgRound2State(:final allSharesSubmitted) => allSharesSubmitted,
    _ => false,
  };

  bool get completed =>
      awaitingCompletion && completionAcks.length == commitments.length;

  cl.ECCompressedPublicKey? get completedGroupKey =>
      completionAcks.values.firstOrNull?.obj.groupKey;

  DkgCommitmentList get commitments => switch (round) {
    DkgRound1State(:final commitments) => commitments,
    DkgRound2State(:final commitments) => commitments,
    _ => throw StateError('Unknown DKG round'),
  };
}

enum DkgTerminalOutcome { rejected, expired, completed }

/// Compact replay-prevention record retained after delivery data is removed.
class TerminalDkg implements Expirable {
  TerminalDkg({
    required Uint8List ceremonyId,
    required this.name,
    required this.outcome,
    required this.expiry,
  }) : ceremonyId = Uint8List.fromList(ceremonyId).asUnmodifiableView() {
    if (ceremonyId.length != 32) throw ArgumentError.value(ceremonyId);
  }

  final Uint8List ceremonyId;
  final String name;
  final DkgTerminalOutcome outcome;
  @override
  final Expiry expiry;
}

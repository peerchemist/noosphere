import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';

/// The ROAST round state for a single signature
class SignatureRoundState {
  final SigningCommitmentSet commitments;
  final ShareList shares = [];
  SignatureRoundState(this.commitments);
}

/// State for a single signature
sealed class SingleSignatureState {}

/// ROAST state for a signature that is not finished
class SingleSignatureInProgressState extends SingleSignatureState {
  /// The master key info required for this signature
  final AggregateKeyInfo key;

  /// The collected commitments for the next round
  final SigningCommitmentMap nextCommitments = {};

  /// Maps the participant identifiers to the ROAST rounds.
  final Map<Identifier, SignatureRoundState> roundForId = {};

  SingleSignatureInProgressState(this.key);
}

/// A completed signature
class SingleSignatureFinishedState extends SingleSignatureState {
  final cl.SchnorrSignature signature;
  final Set<Identifier> contributors;
  SingleSignatureFinishedState(this.signature, this.contributors);
}

/// Handles the state for ROAST signature coordination for a set of requested
/// signatures.
class SignaturesCoordinationState implements Expirable {
  final Signed<SignaturesRequestDetails> details;
  final Identifier creator;
  final List<SingleSignatureState> sigs;

  /// Participants that are determined to be malicious
  final Set<Identifier> malicious = {};

  /// Participants that reject a request will be stored here unless they
  /// withdraw the rejection.
  final Set<Identifier> rejectors = {};

  SignaturesCoordinationState({
    required this.details,
    required this.creator,
    required Set<AggregateKeyInfo> keys,
  }) : sigs = details.obj.requiredSigs
           .map(
             (reqSig) => SingleSignatureInProgressState(
               keys.firstWhere((k) => k.groupKey == reqSig.groupKey),
             ) as SingleSignatureState,
           )
           .toList();

  @override
  Expiry get expiry => details.obj.expiry;

  /// A compact request-level view based on the highest-threshold unfinished
  /// signature. This keeps the count meaningful when one request contains
  /// keys with different thresholds.
  SignaturesProgress get progress {
    final unfinished = sigs.whereType<SingleSignatureInProgressState>().toList()
      ..sort((a, b) => b.key.group.threshold.compareTo(a.key.group.threshold));

    if (unfinished.isEmpty) {
      final finished = sigs.cast<SingleSignatureFinishedState>().toList()
        ..sort(
          (a, b) => b.contributors.length.compareTo(a.contributors.length),
        );
      final contributors = finished.first.contributors;
      return SignaturesProgress(
        threshold: contributors.length,
        contributingParticipants: contributors,
        stage: SignaturesProgressStage.completed,
      );
    }

    final signature = unfinished.first;
    final rounds = signature.roundForId.values.toSet();
    if (rounds.isNotEmpty) {
      final mostAdvanced = rounds.toList()
        ..sort((a, b) => b.shares.length.compareTo(a.shares.length));
      return SignaturesProgress(
        threshold: signature.key.group.threshold,
        contributingParticipants: mostAdvanced.first.shares.map(
          (share) => share.$1,
        ),
        stage: SignaturesProgressStage.signing,
      );
    }

    return SignaturesProgress(
      threshold: signature.key.group.threshold,
      contributingParticipants: signature.nextCommitments.keys,
      stage: SignaturesProgressStage.collecting,
    );
  }

  List<SignatureRoundStart> pendingRoundsForId(Identifier id) {
    final List<SignatureRoundStart> rounds = [];

    for (int i = 0; i < sigs.length; i++) {
      final sig = sigs[i];

      // Id must be in a round
      if (sig is! SingleSignatureInProgressState ||
          !sig.roundForId.containsKey(id)) {
        continue;
      }

      final round = sig.roundForId[id]!;

      // Cannot have already provided a share
      if (round.shares.any((share) => share.$1 == id)) continue;

      rounds.add(SignatureRoundStart(sigI: i, commitments: round.commitments));
    }

    return rounds;
  }
}

import 'package:noosphere_protocol/api/types/expiry.dart';
import 'package:noosphere_protocol/api/types/new_dkg_details.dart';
import 'package:frosty/frosty.dart';

enum DkgStage { round1, round2 }

class DkgInProgress {
  final NewDkgDetails details;

  /// The time the DKG will be expired by the client which may be different from
  /// the requested expiry in the DKG details.
  final Expiry expiry;
  final Identifier creator;
  final DkgStage stage;

  /// Whether this client still has the private intermediate state required to
  /// continue the ceremony. A non-resumable ceremony may still be rejected.
  final bool canResume;

  /// List of paraticipant identifiers that have completed the stage
  final Set<Identifier> completed;

  DkgInProgress({
    required this.details,
    required this.expiry,
    required this.creator,
    required this.stage,
    this.canResume = true,
    required Set<Identifier> completed,
  }) : completed = Set.unmodifiable(completed);
}

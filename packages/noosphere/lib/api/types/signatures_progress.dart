import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere/common/serial.dart';

/// Coordinator-observed phase of an in-progress signatures request.
enum SignaturesProgressStage { collecting, signing, completed, failed }

/// Public coordinator view of the participants advancing a signatures request.
///
/// During [SignaturesProgressStage.collecting], [contributingParticipants]
/// contains participants whose commitments are waiting for the representative
/// signature. During [SignaturesProgressStage.signing], it contains participants
/// whose valid shares are in the most advanced active round. For requests with
/// multiple signatures, the representative signature is the unfinished one
/// with the highest threshold.
final class SignaturesProgress with cl.Writable, NoosphereWritable {
  SignaturesProgress({
    required this.threshold,
    required Iterable<Identifier> contributingParticipants,
    required this.stage,
  }) : contributingParticipants = _validatedParticipants(
         contributingParticipants,
       ) {
    if (threshold < 1 || threshold > 0xffff) {
      throw ArgumentError.value(threshold, 'threshold');
    }
    if (this.contributingParticipants.length > 0xffff) {
      throw ArgumentError.value(
        this.contributingParticipants.length,
        'contributingParticipants.length',
      );
    }
    if (this.contributingParticipants.length > threshold) {
      throw ArgumentError.value(
        this.contributingParticipants.length,
        'contributingParticipants.length',
        'cannot exceed threshold',
      );
    }
  }

  final int threshold;
  final Set<Identifier> contributingParticipants;
  final SignaturesProgressStage stage;

  SignaturesProgress withStage(SignaturesProgressStage stage) =>
      SignaturesProgress(
        threshold: threshold,
        contributingParticipants: contributingParticipants,
        stage: stage,
      );

  factory SignaturesProgress.fromReader(cl.BytesReader reader) {
    final threshold = reader.readUInt16();
    final participants = reader.readIdentifierVector();
    final stageIndex = reader.readUInt8();
    if (stageIndex >= SignaturesProgressStage.values.length) {
      throw FormatException('Invalid signatures progress stage');
    }
    try {
      return SignaturesProgress(
        threshold: threshold,
        contributingParticipants: participants,
        stage: SignaturesProgressStage.values[stageIndex],
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid signatures progress: $error');
    }
  }

  factory SignaturesProgress.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, SignaturesProgress.fromReader);

  @override
  void write(cl.Writer writer) {
    writer.writeUInt16(threshold);
    writer.writeIdentifierVector(contributingParticipants);
    writer.writeUInt8(stage.index);
  }

  static Set<Identifier> _validatedParticipants(
    Iterable<Identifier> participants,
  ) {
    final list = participants.toList();
    final unique = list.toSet();
    if (unique.length != list.length) {
      throw ArgumentError.value(
        participants,
        'contributingParticipants',
        'contains duplicates',
      );
    }
    return Set.unmodifiable(unique);
  }
}

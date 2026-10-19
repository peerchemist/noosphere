import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere_protocol/src/common/serial.dart';

import '../events.dart';
import 'expirable.dart';
import 'expiry.dart';
import 'new_dkg_details.dart';
import 'signed.dart';

enum DkgCeremonyStage {
  collectingCommitments,
  collectingShares,
  awaitingCompletion,
  completed,
}

/// Authenticated, caller-scoped durable view of a DKG ceremony.
///
/// [shares] contains only ciphertexts addressed to the caller that requested
/// the snapshot. Intermediate participant secrets are never part of this
/// coordinator-owned record.
final class DkgCeremonySnapshot
    with cl.Writable, NoosphereWritable
    implements Expirable {
  DkgCeremonySnapshot({
    required this.details,
    required this.creator,
    required DkgCommitmentList commitments,
    required this.stage,
    required Set<Identifier> shareContributors,
    required List<DkgRound2ShareEvent> shares,
    required Set<Identifier> completedParticipants,
    this.groupPublicKey,
  }) : commitments = List.unmodifiable(
         commitments.toList()..sort((a, b) => a.$1.compareTo(b.$1)),
       ),
       shareContributors = Set.unmodifiable(shareContributors),
       shares = List.unmodifiable(
         shares.toList()..sort((a, b) => a.sender.compareTo(b.sender)),
       ),
       completedParticipants = Set.unmodifiable(completedParticipants);

  final Signed<NewDkgDetails> details;
  final Identifier creator;
  final DkgCommitmentList commitments;
  final DkgCeremonyStage stage;
  final Set<Identifier> shareContributors;
  final List<DkgRound2ShareEvent> shares;
  final Set<Identifier> completedParticipants;
  final cl.ECCompressedPublicKey? groupPublicKey;

  Uint8List get ceremonyId => details.obj.ceremonyId;

  @override
  Expiry get expiry => details.obj.expiry;

  DkgCeremonySnapshot.fromReader(cl.BytesReader reader)
    : this(
        details: Signed.fromReader(
          reader,
          () => NewDkgDetails.fromReader(reader),
        ),
        creator: reader.readIdentifier(),
        commitments: List.generate(
          reader.readUInt16(),
          (_) => (
            reader.readIdentifier(),
            DkgPublicCommitment.fromBytes(reader.readVarSlice()),
          ),
        ),
        stage: DkgCeremonyStage.values[reader.readUInt8()],
        shareContributors: reader.readIdentifierVector().toSet(),
        shares: reader.readWritableVector(DkgRound2ShareEvent.fromBytes),
        completedParticipants: reader.readIdentifierVector().toSet(),
        groupPublicKey: reader.readBool() ? reader.readPubKey() : null,
      );

  factory DkgCeremonySnapshot.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, DkgCeremonySnapshot.fromReader);

  @override
  void write(cl.Writer writer) {
    details.write(writer);
    writer.writeIdentifier(creator);
    writer.writeUInt16(commitments.length);
    for (final commitment in commitments) {
      writer.writeIdentifier(commitment.$1);
      writer.writeVarSlice(commitment.$2.toBytes());
    }
    writer.writeUInt8(stage.index);
    writer.writeIdentifierVector(shareContributors.toList()..sort());
    writer.writeWritableVector(shares);
    writer.writeIdentifierVector(completedParticipants.toList()..sort());
    writer.writeBool(groupPublicKey != null);
    if (groupPublicKey != null) writer.writePubKey(groupPublicKey!);
  }
}

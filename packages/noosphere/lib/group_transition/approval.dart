import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/common/serial.dart';

import 'proposal.dart';

const String noosphereGroupTransitionApprovalDomain =
    'noosphere/group-transition-approval/1';

/// A participant identity-key approval of one exact transition proposal.
final class GroupTransitionApproval with cl.Writable, Signable {
  GroupTransitionApproval({
    required Uint8List proposalHash,
    required this.participantPublicKey,
    required this.approvedAt,
  }) : _proposalHash = _copy32(proposalHash, 'proposalHash');

  factory GroupTransitionApproval.forProposal({
    required GroupTransitionProposal proposal,
    required cl.ECCompressedPublicKey participantPublicKey,
    required DateTime approvedAt,
  }) {
    if (!proposal.recognizesParticipant(participantPublicKey)) {
      throw ArgumentError.value(
        participantPublicKey,
        'participantPublicKey',
        'is not in the source or successor group',
      );
    }
    if (approvedAt.isBefore(proposal.createdAt) ||
        proposal.isExpiredAt(approvedAt)) {
      throw ArgumentError.value(
        approvedAt,
        'approvedAt',
        'must be within the proposal validity window',
      );
    }
    return GroupTransitionApproval(
      proposalHash: proposal.proposalHash,
      participantPublicKey: participantPublicKey,
      approvedAt: approvedAt,
    );
  }

  factory GroupTransitionApproval.fromReader(cl.BytesReader reader) {
    if (reader.readString() != noosphereGroupTransitionApprovalDomain) {
      throw const FormatException('invalid group transition approval domain');
    }
    return GroupTransitionApproval(
      proposalHash: reader.readSlice(32),
      participantPublicKey: reader.readPubKey(),
      approvedAt: reader.readTime(),
    );
  }

  factory GroupTransitionApproval.fromBytes(Uint8List bytes) {
    final reader = cl.BytesReader(bytes);
    final approval = GroupTransitionApproval.fromReader(reader);
    if (!reader.atEnd) {
      throw const FormatException('trailing group transition approval data');
    }
    return approval;
  }

  final Uint8List _proposalHash;
  final cl.ECCompressedPublicKey participantPublicKey;
  final DateTime approvedAt;

  Uint8List get proposalHash => Uint8List.fromList(_proposalHash);

  bool matchesProposal(GroupTransitionProposal proposal) =>
      cl.bytesEqual(_proposalHash, proposal.proposalHash) &&
      proposal.recognizesParticipant(participantPublicKey) &&
      !approvedAt.isBefore(proposal.createdAt) &&
      !proposal.isExpiredAt(approvedAt);

  Signed<GroupTransitionApproval> sign(cl.ECPrivateKey privateKey) {
    final actual = cl.ECCompressedPublicKey.fromPubkey(privateKey.pubkey);
    if (actual != participantPublicKey) {
      throw ArgumentError.value(
        privateKey,
        'privateKey',
        'does not match the approving participant',
      );
    }
    return Signed.sign(obj: this, key: privateKey);
  }

  @override
  Uint8List get uncachedSigHash => cl.sha256Hash(toBytes());

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString(noosphereGroupTransitionApprovalDomain)
      ..writeSlice(_proposalHash)
      ..writePubKey(participantPublicKey)
      ..writeTime(approvedAt);
  }
}

Uint8List _copy32(Uint8List bytes, String name) {
  if (bytes.length != 32) {
    throw ArgumentError.value(bytes.length, name, 'must contain 32 bytes');
  }
  return Uint8List.fromList(bytes);
}

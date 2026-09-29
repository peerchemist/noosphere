import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:noosphere/config.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(loadFrosty);

  test('proposal has canonical ordering and round-trips', () {
    final fixture = _Fixture();
    final proposal = fixture.proposal(
      successorParticipants: [fixture.newParticipant, fixture.retained],
      keyPlans: [fixture.secondPlan, fixture.firstPlan],
    );
    final sameProposal = fixture.proposal(
      successorParticipants: [fixture.retained, fixture.newParticipant],
      keyPlans: [fixture.firstPlan, fixture.secondPlan],
    );

    expect(proposal.toBytes(), sameProposal.toBytes());
    expect(
      GroupTransitionProposal.fromBytes(proposal.toBytes()).toBytes(),
      proposal.toBytes(),
    );
    expect(proposal.proposalHash, cl.sha256Hash(proposal.toBytes()));
    expect(proposal.retainedParticipants, [fixture.retained]);
    expect(proposal.addedParticipants, [fixture.newParticipant]);
    expect(proposal.removedParticipants, [fixture.removed]);
  });

  test('proposal binds policy, DKG plan and source group', () {
    final fixture = _Fixture();
    final original = fixture.proposal();
    final changedPolicy = fixture.proposal(
      policy: GroupTransitionMigrationPolicy(
        kind: 'test-wallet',
        version: 1,
        payload: Uint8List.fromList([1, 2, 4]),
      ),
    );
    final changedDkg = fixture.proposal(
      keyPlans: [
        GroupTransitionKeyPlan(
          keyId: 'primary',
          sourceGroupKey: fixture.sourceGroupKey,
          sourceThreshold: 2,
          targetThreshold: 2,
          dkgDetailsHash: Uint8List.fromList(List.filled(32, 99)),
        ),
      ],
    );

    expect(changedPolicy.proposalHash, isNot(original.proposalHash));
    expect(changedDkg.proposalHash, isNot(original.proposalHash));

    final copiedFingerprint = original.sourceGroupFingerprint;
    copiedFingerprint[0] ^= 0xff;
    expect(original.sourceGroupFingerprint, isNot(copiedFingerprint));
  });

  test('participant approval is scoped and signed by its identity key', () {
    final fixture = _Fixture();
    final proposal = fixture.proposal();
    final approval = GroupTransitionApproval.forProposal(
      proposal: proposal,
      participantPublicKey: fixture.retained,
      approvedAt: fixture.createdAt.add(const Duration(minutes: 1)),
    );
    final signed = approval.sign(fixture.retainedPrivateKey);
    final decoded = GroupTransitionApproval.fromBytes(approval.toBytes());

    expect(decoded.matchesProposal(proposal), isTrue);
    expect(signed.verify(fixture.retained), isTrue);
    expect(signed.verify(fixture.newParticipant), isFalse);
    expect(
      () => approval.sign(fixture.newParticipantPrivateKey),
      throwsArgumentError,
    );
  });

  test('rejects ambiguous or out-of-bounds proposals and approvals', () {
    final fixture = _Fixture();
    expect(
      () => fixture.proposal(
        successorParticipants: [fixture.retained, fixture.retained],
      ),
      throwsArgumentError,
    );
    expect(
      () => fixture.proposal(
        keyPlans: [
          GroupTransitionKeyPlan(
            keyId: 'primary',
            sourceGroupKey: fixture.sourceGroupKey,
            sourceThreshold: 2,
            targetThreshold: 3,
            dkgDetailsHash: Uint8List(32),
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => GroupTransitionApproval.forProposal(
        proposal: fixture.proposal(),
        participantPublicKey: _publicKey(cl.ECPrivateKey.generate()),
        approvedAt: fixture.createdAt.add(const Duration(minutes: 1)),
      ),
      throwsArgumentError,
    );
    expect(
      () => GroupTransitionApproval.forProposal(
        proposal: fixture.proposal(),
        participantPublicKey: fixture.retained,
        approvedAt: fixture.expiresAt,
      ),
      throwsArgumentError,
    );
  });
}

final class _Fixture {
  _Fixture()
    : retainedPrivateKey = cl.ECPrivateKey.generate(),
      removedPrivateKey = cl.ECPrivateKey.generate(),
      newParticipantPrivateKey = cl.ECPrivateKey.generate(),
      sourceGroupKeyPrivateKey = cl.ECPrivateKey.generate() {
    retained = _publicKey(retainedPrivateKey);
    removed = _publicKey(removedPrivateKey);
    newParticipant = _publicKey(newParticipantPrivateKey);
    sourceGroupKey = _publicKey(sourceGroupKeyPrivateKey);
    sourceGroup = GroupConfig(
      id: 'source-group',
      participants: {
        Identifier.fromUint16(1): retained,
        Identifier.fromUint16(2): removed,
      },
    );
    firstPlan = GroupTransitionKeyPlan(
      keyId: 'primary',
      sourceGroupKey: sourceGroupKey,
      sourceThreshold: 2,
      targetThreshold: 2,
      dkgDetailsHash: Uint8List.fromList(List.filled(32, 7)),
    );
    secondPlan = GroupTransitionKeyPlan(
      keyId: 'recovery',
      sourceGroupKey: _publicKey(cl.ECPrivateKey.generate()),
      sourceThreshold: 2,
      targetThreshold: 2,
      dkgDetailsHash: Uint8List.fromList(List.filled(32, 8)),
    );
  }

  final cl.ECPrivateKey retainedPrivateKey;
  final cl.ECPrivateKey removedPrivateKey;
  final cl.ECPrivateKey newParticipantPrivateKey;
  final cl.ECPrivateKey sourceGroupKeyPrivateKey;
  late final cl.ECCompressedPublicKey retained;
  late final cl.ECCompressedPublicKey removed;
  late final cl.ECCompressedPublicKey newParticipant;
  late final cl.ECCompressedPublicKey sourceGroupKey;
  late final GroupConfig sourceGroup;
  late final GroupTransitionKeyPlan firstPlan;
  late final GroupTransitionKeyPlan secondPlan;
  final createdAt = DateTime.utc(2030, 1, 1);
  final expiresAt = DateTime.utc(2030, 1, 2);

  GroupTransitionProposal proposal({
    Iterable<cl.ECCompressedPublicKey>? successorParticipants,
    Iterable<GroupTransitionKeyPlan>? keyPlans,
    GroupTransitionMigrationPolicy? policy,
  }) => GroupTransitionProposal(
    transitionId: 'transition-1',
    sourceGroup: sourceGroup,
    successorRoomId: 'successor-room',
    coordinatorEndpointId: Uint8List.fromList(List.filled(32, 4)),
    successorParticipants: successorParticipants ?? [retained, newParticipant],
    keyPlans: keyPlans ?? [firstPlan],
    migrationPolicy:
        policy ??
        GroupTransitionMigrationPolicy(
          kind: 'test-wallet',
          version: 1,
          payload: Uint8List.fromList([1, 2, 3]),
        ),
    createdAt: createdAt,
    expiresAt: expiresAt,
  );
}

cl.ECCompressedPublicKey _publicKey(cl.ECPrivateKey privateKey) =>
    cl.ECCompressedPublicKey.fromPubkey(privateKey.pubkey);

import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:noosphere/wire.dart' as wire;
import 'package:test/test.dart';

void main() {
  setUpAll(loadFrosty);

  test('all domain event variants round-trip through typed protobuf', () {
    final firstKey = cl.ECPrivateKey(Uint8List(32)..last = 1);
    final secondKey = cl.ECPrivateKey(Uint8List(32)..last = 2);
    final firstId = Identifier.fromUint16(1);
    final secondId = Identifier.fromUint16(2);
    final groupKey = cl.ECCompressedPublicKey.fromPubkey(firstKey.pubkey);
    final expiry = Expiry(const Duration(days: 1));
    final dkgDetails = NewDkgDetails(
      name: 'key',
      description: 'test key',
      threshold: 2,
      expiry: expiry,
    );
    final signedDkgDetails = Signed.sign(obj: dkgDetails, key: firstKey);
    final dkgCommitment = DkgPart1(
      identifier: firstId,
      threshold: 2,
      n: 2,
    ).public;
    final ciphertext = ECCiphertext.encrypt(
      plaintext: Uint8List.fromList([1]),
      recipientKey: secondKey.pubkey,
      senderKey: firstKey,
    );
    final ack = SignedDkgAck(
      signer: firstId,
      signed: Signed.sign(
        obj: DkgAck(groupKey: groupKey, accepted: true),
        key: firstKey,
      ),
    );
    final ackRequest = DkgAckRequest(
      ids: {firstId, secondId},
      groupPublicKey: groupKey,
    );
    final signaturesDetails = SignaturesRequestDetails(
      requiredSigs: [
        SingleSignatureDetails(
          signDetails: SignDetails.keySpend(message: Uint8List(32)),
          groupKey: groupKey,
          hdDerivation: const [],
        ),
      ],
      expiry: expiry,
    );
    final signedSignaturesDetails = Signed.sign(
      obj: signaturesDetails,
      key: firstKey,
    );
    final progress = SignaturesProgress(
      threshold: 2,
      contributingParticipants: {firstId},
      stage: SignaturesProgressStage.signing,
    );
    final requestId = signaturesDetails.id;
    final signature = cl.SchnorrSignature.sign(firstKey, Uint8List(32));
    final constructedKey = Signed.sign(
      obj: KeyWasConstructed(groupKey),
      key: firstKey,
    );

    final events = <Event>[
      ParticipantStatusEvent(id: firstId, loggedIn: true),
      NewDkgEvent(
        details: signedDkgDetails,
        creator: firstId,
        commitments: [(firstId, dkgCommitment)],
      ),
      DkgCommitmentEvent(
        name: dkgDetails.name,
        participant: firstId,
        commitment: dkgCommitment,
      ),
      DkgRejectEvent(name: dkgDetails.name, participant: secondId),
      DkgRound2ShareEvent(
        name: dkgDetails.name,
        commitmentSetSignature: signature,
        sender: firstId,
        secret: DkgEncryptedSecret(ciphertext),
      ),
      DkgAckEvent({ack}),
      DkgAckRequestEvent({ackRequest}),
      SignaturesRequestEvent(
        details: signedSignaturesDetails,
        creator: firstId,
        progress: progress,
      ),
      SignatureNewRoundsEvent(
        reqId: requestId,
        rounds: [
          SignatureRoundStart(
            sigI: 0,
            commitments: SigningCommitmentSet(const {}),
          ),
        ],
      ),
      SignaturesCompleteEvent(reqId: requestId, signatures: [signature]),
      SignaturesFailureEvent(requestId),
      KeepaliveEvent(),
      SecretShareEvent(
        sender: firstId,
        keyShare: EncryptedKeyShare(ciphertext),
        groupKey: groupKey,
      ),
      ConstructedKeyEvent(participant: firstId, constructedKey: constructedKey),
      SignaturesProgressEvent(reqId: requestId, progress: progress),
    ];

    final variants = <wire.EventMessage_Event>{};
    for (final original in events) {
      final protobuf = wire.encodeEvent(original);
      variants.add(protobuf.whichEvent());
      final parsed = wire.EventMessage.fromBuffer(protobuf.writeToBuffer());
      final decoded = wire.decodeEvent(parsed);
      expect(decoded.runtimeType, original.runtimeType);
      expect(decoded.toBytes(), original.toBytes());
    }

    expect(
      variants,
      wire.EventMessage_Event.values
          .where((variant) => variant != wire.EventMessage_Event.notSet)
          .toSet(),
    );
  });

  test('rejects an event without a protobuf variant', () {
    expect(
      () => wire.decodeEvent(wire.EventMessage()),
      throwsA(isA<FormatException>()),
    );
  });

  test('preserves every signatures progress stage including zero', () {
    final requestId = SignaturesRequestId.fromBytes(Uint8List(16));
    for (final stage in SignaturesProgressStage.values) {
      final original = SignaturesProgressEvent(
        reqId: requestId,
        progress: SignaturesProgress(
          threshold: 1,
          contributingParticipants: const {},
          stage: stage,
        ),
      );
      final protobuf = wire.encodeEvent(original);
      final parsed = wire.EventMessage.fromBuffer(protobuf.writeToBuffer());
      expect(parsed.signaturesProgress.progress.hasStage(), isTrue);
      final decoded = wire.decodeEvent(parsed) as SignaturesProgressEvent;
      expect(decoded.progress.stage, stage);
    }
  });

  test('rejects signatures progress without an explicit stage', () {
    final event = wire.EventMessage(
      signaturesProgress: wire.SignaturesProgressEvent(
        requestId: List<int>.filled(16, 0),
        progress: wire.SignaturesProgress(threshold: 1),
      ),
    );
    expect(() => wire.decodeEvent(event), throwsA(isA<FormatException>()));
  });
}

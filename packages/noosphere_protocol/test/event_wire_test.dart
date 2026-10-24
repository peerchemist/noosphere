import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/domain.dart';
import 'package:noosphere_protocol/wire.dart' as wire;
import 'package:test/test.dart';

void main() {
  setUpAll(loadFrosty);

  test('all domain event variants round-trip through typed CBOR', () {
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
      groupFingerprint: Uint8List(32),
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
        obj: DkgAck(
          groupKey: groupKey,
          accepted: true,
          ceremonyId: dkgDetails.ceremonyId,
          transcriptHash: Uint8List(32),
        ),
        key: firstKey,
      ),
    );
    final ackRequest = DkgAckRequest(
      ids: {firstId, secondId},
      groupPublicKey: groupKey,
      ceremonyId: dkgDetails.ceremonyId,
      transcriptHash: Uint8List(32),
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
        ceremonyId: dkgDetails.ceremonyId,
        participant: firstId,
        commitment: dkgCommitment,
      ),
      DkgRejectEvent(
        name: dkgDetails.name,
        ceremonyId: dkgDetails.ceremonyId,
        participant: secondId,
      ),
      DkgRound2ShareEvent(
        name: dkgDetails.name,
        ceremonyId: dkgDetails.ceremonyId,
        commitmentSetSignature: signature,
        sender: firstId,
        secret: DkgEncryptedSecret(
          ciphertext: ciphertext,
          envelopeSignature: signature,
        ),
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
      SignaturesCancelledEvent(requestId: requestId, expiresAt: expiry),
      KeepaliveEvent(),
      SecretShareEvent(
        sender: firstId,
        keyShare: EncryptedKeyShare(ciphertext),
        groupKey: groupKey,
      ),
      ConstructedKeyEvent(participant: firstId, constructedKey: constructedKey),
      SignaturesProgressEvent(reqId: requestId, progress: progress),
    ];

    final variants = <Type>{};
    for (final original in events) {
      final encoded = wire.encodeEvent(original);
      variants.add(encoded.event.runtimeType);
      final parsed = wire.EventMessage.fromBuffer(encoded.writeToBuffer());
      final decoded = wire.decodeEvent(parsed);
      expect(decoded.runtimeType, original.runtimeType);
      expect(decoded.toBytes(), original.toBytes());
    }

    expect(variants, hasLength(events.length));
  });

  test('rejects an event missing its discriminator and payload', () {
    expect(
      () => wire.EventMessage.fromBuffer([0xa0]),
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
      final encoded = wire.encodeEvent(original);
      final parsed = wire.EventMessage.fromBuffer(encoded.writeToBuffer());
      final decoded = wire.decodeEvent(parsed) as SignaturesProgressEvent;
      expect(decoded.progress.stage, stage);
    }
  });

  test('rejects signatures progress without an explicit stage', () {
    expect(
      // SignaturesProgressEvent with progress {1: 1, 2: []}, missing stage 3.
      () => wire.EventMessage.fromBuffer([
        0xa2,
        0x01,
        0x0f,
        0x02,
        0xa2,
        0x01,
        0x40,
        0x02,
        0xa2,
        0x01,
        0x01,
        0x02,
        0x80,
      ]),
      throwsA(isA<FormatException>()),
    );
  });
}

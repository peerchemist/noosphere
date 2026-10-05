/// Protobuf conversion for streamed protocol events.
library;

import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere/common/serial.dart';
import 'package:noosphere/domain.dart' as domain;
import 'package:noosphere/src/generated/noosphere.pb.dart' as wire;

/// Converts a domain event to its typed protobuf representation.
wire.Events encodeEvent(domain.Event event) => switch (event) {
  domain.ParticipantStatusEvent() => wire.Events(
    participantStatus: wire.ParticipantStatusEvent(
      participantId: event.id.toBytes(),
      loggedIn: event.loggedIn,
    ),
  ),
  domain.NewDkgEvent() => wire.Events(
    newDkg: wire.NewDkgEvent(
      signedDetails: event.details.toBytes(),
      creatorId: event.creator.toBytes(),
      commitments: event.commitments.map(
        (commitment) => wire.DkgEventCommitment(
          participantId: commitment.$1.toBytes(),
          commitment: commitment.$2.toBytes(),
        ),
      ),
    ),
  ),
  domain.DkgCommitmentEvent() => wire.Events(
    dkgCommitment: wire.DkgCommitmentEvent(
      name: event.name,
      participantId: event.participant.toBytes(),
      commitment: event.commitment.toBytes(),
    ),
  ),
  domain.DkgRejectEvent() => wire.Events(
    dkgReject: wire.DkgRejectEvent(
      name: event.name,
      participantId: event.participant.toBytes(),
    ),
  ),
  domain.DkgRound2ShareEvent() => wire.Events(
    dkgRound2Share: wire.DkgRound2ShareEvent(
      name: event.name,
      commitmentSetSignature: event.commitmentSetSignature.data,
      senderId: event.sender.toBytes(),
      encryptedSecret: event.secret.ciphertext.toBytes(),
    ),
  ),
  domain.DkgAckEvent() => wire.Events(
    dkgAck: wire.DkgAckEvent(acks: event.acks.map((ack) => ack.toBytes())),
  ),
  domain.DkgAckRequestEvent() => wire.Events(
    dkgAckRequest: wire.DkgAckRequestEvent(
      requests: event.requests.map((request) => request.toBytes()),
    ),
  ),
  domain.SignaturesRequestEvent() => wire.Events(
    signaturesRequest: wire.SignaturesRequestEvent(
      signedDetails: event.details.toBytes(),
      creatorId: event.creator.toBytes(),
      progress: _encodeProgress(event.progress),
    ),
  ),
  domain.SignatureNewRoundsEvent() => wire.Events(
    signatureNewRounds: wire.SignatureNewRoundsEvent(
      requestId: event.reqId.toBytes(),
      rounds: event.rounds.map(
        (round) => wire.SignatureRoundStart(
          signatureIndex: round.sigI,
          commitmentSet: round.commitments.toBytes(),
        ),
      ),
    ),
  ),
  domain.SignaturesCompleteEvent() => wire.Events(
    signaturesComplete: wire.SignaturesCompleteEvent(
      requestId: event.reqId.toBytes(),
      signatures: event.signatures.map((signature) => signature.data),
    ),
  ),
  domain.SignaturesFailureEvent() => wire.Events(
    signaturesFailure: wire.SignaturesFailureEvent(
      requestId: event.reqId.toBytes(),
    ),
  ),
  domain.KeepaliveEvent() => wire.Events(keepalive: wire.KeepaliveEvent()),
  domain.SecretShareEvent() => wire.Events(
    secretShare: wire.SecretShareEvent(
      senderId: event.sender.toBytes(),
      groupKey: event.groupKey.data,
      encryptedKeyShare: event.keyShare.ciphertext.toBytes(),
    ),
  ),
  domain.ConstructedKeyEvent() => wire.Events(
    constructedKey: encodeConstructedKeyEvent(event),
  ),
  domain.SignaturesProgressEvent() => wire.Events(
    signaturesProgress: wire.SignaturesProgressEvent(
      requestId: event.reqId.toBytes(),
      progress: _encodeProgress(event.progress),
    ),
  ),
};

/// Converts a typed protobuf event to its domain representation.
domain.Event decodeEvent(wire.Events event) => switch (event.whichEvent()) {
  wire.Events_Event.participantStatus => domain.ParticipantStatusEvent(
    id: _identifier(event.participantStatus.participantId),
    loggedIn: event.participantStatus.loggedIn,
  ),
  wire.Events_Event.newDkg => domain.NewDkgEvent(
    details: domain.Signed<domain.NewDkgDetails>.fromBytes(
      _bytes(event.newDkg.signedDetails),
      domain.NewDkgDetails.fromReader,
    ),
    creator: _identifier(event.newDkg.creatorId),
    commitments: event.newDkg.commitments
        .map(
          (commitment) => (
            _identifier(commitment.participantId),
            DkgPublicCommitment.fromBytes(_bytes(commitment.commitment)),
          ),
        )
        .toList(),
  ),
  wire.Events_Event.dkgCommitment => domain.DkgCommitmentEvent(
    name: event.dkgCommitment.name,
    participant: _identifier(event.dkgCommitment.participantId),
    commitment: DkgPublicCommitment.fromBytes(
      _bytes(event.dkgCommitment.commitment),
    ),
  ),
  wire.Events_Event.dkgReject => domain.DkgRejectEvent(
    name: event.dkgReject.name,
    participant: _identifier(event.dkgReject.participantId),
  ),
  wire.Events_Event.dkgRound2Share => domain.DkgRound2ShareEvent(
    name: event.dkgRound2Share.name,
    commitmentSetSignature: cl.SchnorrSignature(
      _bytes(event.dkgRound2Share.commitmentSetSignature),
    ),
    sender: _identifier(event.dkgRound2Share.senderId),
    secret: domain.DkgEncryptedSecret(
      ECCiphertext.fromBytes(_bytes(event.dkgRound2Share.encryptedSecret)),
    ),
  ),
  wire.Events_Event.dkgAck => domain.DkgAckEvent(
    event.dkgAck.acks
        .map((ack) => domain.SignedDkgAck.fromBytes(_bytes(ack)))
        .toSet(),
  ),
  wire.Events_Event.dkgAckRequest => domain.DkgAckRequestEvent(
    event.dkgAckRequest.requests
        .map((request) => domain.DkgAckRequest.fromBytes(_bytes(request)))
        .toSet(),
  ),
  wire.Events_Event.signaturesRequest => _decodeSignaturesRequest(
    event.signaturesRequest,
  ),
  wire.Events_Event.signatureNewRounds => domain.SignatureNewRoundsEvent(
    reqId: domain.SignaturesRequestId.fromBytes(
      _bytes(event.signatureNewRounds.requestId),
    ),
    rounds: event.signatureNewRounds.rounds
        .map(
          (round) => domain.SignatureRoundStart(
            sigI: round.signatureIndex,
            commitments: readNoosphere(
              _bytes(round.commitmentSet),
              SigningCommitmentSet.fromReader,
            ),
          ),
        )
        .toList(),
  ),
  wire.Events_Event.signaturesComplete => domain.SignaturesCompleteEvent(
    reqId: domain.SignaturesRequestId.fromBytes(
      _bytes(event.signaturesComplete.requestId),
    ),
    signatures: event.signaturesComplete.signatures
        .map((signature) => cl.SchnorrSignature(_bytes(signature)))
        .toList(),
  ),
  wire.Events_Event.signaturesFailure => domain.SignaturesFailureEvent(
    domain.SignaturesRequestId.fromBytes(
      _bytes(event.signaturesFailure.requestId),
    ),
  ),
  wire.Events_Event.keepalive => domain.KeepaliveEvent(),
  wire.Events_Event.secretShare => domain.SecretShareEvent(
    sender: _identifier(event.secretShare.senderId),
    groupKey: cl.ECCompressedPublicKey(_bytes(event.secretShare.groupKey)),
    keyShare: domain.EncryptedKeyShare(
      ECCiphertext.fromBytes(_bytes(event.secretShare.encryptedKeyShare)),
    ),
  ),
  wire.Events_Event.constructedKey => decodeConstructedKeyEvent(
    event.constructedKey,
  ),
  wire.Events_Event.signaturesProgress => _decodeSignaturesProgress(
    event.signaturesProgress,
  ),
  wire.Events_Event.notSet => throw const FormatException(
    'protobuf event has no event variant',
  ),
};

wire.ConstructedKeyEvent encodeConstructedKeyEvent(
  domain.ConstructedKeyEvent event,
) => wire.ConstructedKeyEvent(
  participantId: event.participant.toBytes(),
  signedConstructedKey: event.constructedKey.toBytes(),
);

domain.ConstructedKeyEvent decodeConstructedKeyEvent(
  wire.ConstructedKeyEvent event,
) => domain.ConstructedKeyEvent(
  participant: _identifier(event.participantId),
  constructedKey: domain.Signed<domain.KeyWasConstructed>.fromBytes(
    _bytes(event.signedConstructedKey),
    domain.KeyWasConstructed.fromReader,
  ),
);

wire.SignaturesProgress _encodeProgress(domain.SignaturesProgress progress) =>
    wire.SignaturesProgress(
      threshold: progress.threshold,
      contributingParticipantIds: progress.contributingParticipants.map(
        (participant) => participant.toBytes(),
      ),
      stage: switch (progress.stage) {
        domain.SignaturesProgressStage.collecting =>
          wire.SignaturesProgressStage.SIGNATURES_PROGRESS_COLLECTING,
        domain.SignaturesProgressStage.signing =>
          wire.SignaturesProgressStage.SIGNATURES_PROGRESS_SIGNING,
        domain.SignaturesProgressStage.completed =>
          wire.SignaturesProgressStage.SIGNATURES_PROGRESS_COMPLETED,
        domain.SignaturesProgressStage.failed =>
          wire.SignaturesProgressStage.SIGNATURES_PROGRESS_FAILED,
      },
    );

domain.SignaturesProgress _decodeProgress(wire.SignaturesProgress progress) {
  if (!progress.hasStage()) {
    throw const FormatException('signatures progress has no stage');
  }
  return domain.SignaturesProgress(
    threshold: progress.threshold,
    contributingParticipants: progress.contributingParticipantIds.map(
      _identifier,
    ),
    stage: switch (progress.stage) {
      wire.SignaturesProgressStage.SIGNATURES_PROGRESS_COLLECTING =>
        domain.SignaturesProgressStage.collecting,
      wire.SignaturesProgressStage.SIGNATURES_PROGRESS_SIGNING =>
        domain.SignaturesProgressStage.signing,
      wire.SignaturesProgressStage.SIGNATURES_PROGRESS_COMPLETED =>
        domain.SignaturesProgressStage.completed,
      wire.SignaturesProgressStage.SIGNATURES_PROGRESS_FAILED =>
        domain.SignaturesProgressStage.failed,
      _ => throw FormatException(
        'unknown signatures progress stage ${progress.stage}',
      ),
    },
  );
}

domain.SignaturesRequestEvent _decodeSignaturesRequest(
  wire.SignaturesRequestEvent event,
) {
  if (!event.hasProgress()) {
    throw const FormatException('signatures request event has no progress');
  }
  return domain.SignaturesRequestEvent(
    details: domain.Signed<domain.SignaturesRequestDetails>.fromBytes(
      _bytes(event.signedDetails),
      domain.SignaturesRequestDetails.fromReaderAllowNegativeExpiry,
    ),
    creator: _identifier(event.creatorId),
    progress: _decodeProgress(event.progress),
  );
}

domain.SignaturesProgressEvent _decodeSignaturesProgress(
  wire.SignaturesProgressEvent event,
) {
  if (!event.hasProgress()) {
    throw const FormatException('signatures progress event has no progress');
  }
  return domain.SignaturesProgressEvent(
    reqId: domain.SignaturesRequestId.fromBytes(_bytes(event.requestId)),
    progress: _decodeProgress(event.progress),
  );
}

domain.Identifier _identifier(List<int> bytes) =>
    domain.Identifier.fromBytes(_bytes(bytes));

Uint8List _bytes(List<int> bytes) => Uint8List.fromList(bytes);

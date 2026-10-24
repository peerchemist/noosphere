/// Deterministic-CBOR conversion for streamed protocol events.
library;

import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere_protocol/src/common/serial.dart';
import 'package:noosphere_protocol/domain.dart' as domain;
import 'package:noosphere_protocol/src/wire/messages.dart' as wire;

/// Converts a domain event to its typed CBOR representation.
wire.EventMessage encodeEvent(domain.Event event) => wire.EventMessage(
  event: switch (event) {
    domain.SignaturesCancelledEvent() => wire.SignaturesCancelledEvent(
      requestId: event.requestId.toBytes(),
      expiresAt: event.expiresAt.toBytes(),
    ),
    domain.ParticipantStatusEvent() => wire.ParticipantStatusEvent(
      participantId: event.id.toBytes(),
      loggedIn: event.loggedIn,
    ),
    domain.NewDkgEvent() => wire.NewDkgEvent(
      signedDetails: event.details.toBytes(),
      creatorId: event.creator.toBytes(),
      commitments: event.commitments
          .map(
            (commitment) => wire.DkgEventCommitment(
              participantId: commitment.$1.toBytes(),
              commitment: commitment.$2.toBytes(),
            ),
          )
          .toList(),
    ),
    domain.DkgCommitmentEvent() => wire.DkgCommitmentEvent(
      name: event.name,
      participantId: event.participant.toBytes(),
      commitment: event.commitment.toBytes(),
      ceremonyId: event.ceremonyId,
    ),
    domain.DkgRejectEvent() => wire.DkgRejectEvent(
      name: event.name,
      participantId: event.participant.toBytes(),
      ceremonyId: event.ceremonyId,
    ),
    domain.DkgRound2ShareEvent() => wire.DkgRound2ShareEvent(
      name: event.name,
      commitmentSetSignature: event.commitmentSetSignature.data,
      senderId: event.sender.toBytes(),
      encryptedSecret: event.secret.toBytes(),
      ceremonyId: event.ceremonyId,
    ),
    domain.DkgAckEvent() => wire.DkgAckEvent(
      acks: event.acks.map((ack) => ack.toBytes()).toList(),
    ),
    domain.DkgAckRequestEvent() => wire.DkgAckRequestEvent(
      requests: event.requests.map((request) => request.toBytes()).toList(),
    ),
    domain.SignaturesRequestEvent() => wire.SignaturesRequestEvent(
      signedDetails: event.details.toBytes(),
      creatorId: event.creator.toBytes(),
      progress: _encodeProgress(event.progress),
    ),
    domain.SignatureNewRoundsEvent() => wire.SignatureNewRoundsEvent(
      requestId: event.reqId.toBytes(),
      rounds: event.rounds
          .map(
            (round) => wire.SignatureRoundStart(
              signatureIndex: round.sigI,
              commitmentSet: round.commitments.toBytes(),
            ),
          )
          .toList(),
    ),
    domain.SignaturesCompleteEvent() => wire.SignaturesCompleteEvent(
      requestId: event.reqId.toBytes(),
      signatures: event.signatures.map((signature) => signature.data).toList(),
    ),
    domain.SignaturesFailureEvent() => wire.SignaturesFailureEvent(
      requestId: event.reqId.toBytes(),
    ),
    domain.KeepaliveEvent() => wire.KeepaliveEvent(),
    domain.SecretShareEvent() => wire.SecretShareEvent(
      senderId: event.sender.toBytes(),
      groupKey: event.groupKey.data,
      encryptedKeyShare: event.keyShare.ciphertext.toBytes(),
    ),
    domain.ConstructedKeyEvent() => encodeConstructedKeyEvent(event),
    domain.SignaturesProgressEvent() => wire.SignaturesProgressEvent(
      requestId: event.reqId.toBytes(),
      progress: _encodeProgress(event.progress),
    ),
  },
);

/// Converts a typed CBOR event to its domain representation.
domain.Event decodeEvent(wire.EventMessage message) => switch (message.event) {
  wire.SignaturesCancelledEvent event => domain.SignaturesCancelledEvent(
    requestId: domain.SignaturesRequestId.fromBytes(_bytes(event.requestId)),
    expiresAt: domain.Expiry.fromBytes(_bytes(event.expiresAt)),
  ),
  wire.ParticipantStatusEvent event => domain.ParticipantStatusEvent(
    id: _identifier(event.participantId),
    loggedIn: event.loggedIn,
  ),
  wire.NewDkgEvent event => domain.NewDkgEvent(
    details: domain.Signed<domain.NewDkgDetails>.fromBytes(
      _bytes(event.signedDetails),
      domain.NewDkgDetails.fromReader,
    ),
    creator: _identifier(event.creatorId),
    commitments: event.commitments
        .map(
          (commitment) => (
            _identifier(commitment.participantId),
            DkgPublicCommitment.fromBytes(_bytes(commitment.commitment)),
          ),
        )
        .toList(),
  ),
  wire.DkgCommitmentEvent event => domain.DkgCommitmentEvent(
    name: event.name,
    ceremonyId: _bytes(event.ceremonyId),
    participant: _identifier(event.participantId),
    commitment: DkgPublicCommitment.fromBytes(_bytes(event.commitment)),
  ),
  wire.DkgRejectEvent event => domain.DkgRejectEvent(
    name: event.name,
    ceremonyId: _bytes(event.ceremonyId),
    participant: _identifier(event.participantId),
  ),
  wire.DkgRound2ShareEvent event => domain.DkgRound2ShareEvent(
    name: event.name,
    ceremonyId: _bytes(event.ceremonyId),
    commitmentSetSignature: cl.SchnorrSignature(
      _bytes(event.commitmentSetSignature),
    ),
    sender: _identifier(event.senderId),
    secret: domain.DkgEncryptedSecret.fromBytes(_bytes(event.encryptedSecret)),
  ),
  wire.DkgAckEvent event => domain.DkgAckEvent(
    event.acks.map((ack) => domain.SignedDkgAck.fromBytes(_bytes(ack))).toSet(),
  ),
  wire.DkgAckRequestEvent event => domain.DkgAckRequestEvent(
    event.requests
        .map((request) => domain.DkgAckRequest.fromBytes(_bytes(request)))
        .toSet(),
  ),
  wire.SignaturesRequestEvent event => _decodeSignaturesRequest(event),
  wire.SignatureNewRoundsEvent event => domain.SignatureNewRoundsEvent(
    reqId: domain.SignaturesRequestId.fromBytes(_bytes(event.requestId)),
    rounds: event.rounds
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
  wire.SignaturesCompleteEvent event => domain.SignaturesCompleteEvent(
    reqId: domain.SignaturesRequestId.fromBytes(_bytes(event.requestId)),
    signatures: event.signatures
        .map((signature) => cl.SchnorrSignature(_bytes(signature)))
        .toList(),
  ),
  wire.SignaturesFailureEvent event => domain.SignaturesFailureEvent(
    domain.SignaturesRequestId.fromBytes(_bytes(event.requestId)),
  ),
  wire.KeepaliveEvent() => domain.KeepaliveEvent(),
  wire.SecretShareEvent event => domain.SecretShareEvent(
    sender: _identifier(event.senderId),
    groupKey: cl.ECCompressedPublicKey(_bytes(event.groupKey)),
    keyShare: domain.EncryptedKeyShare(
      ECCiphertext.fromBytes(_bytes(event.encryptedKeyShare)),
    ),
  ),
  wire.ConstructedKeyEvent event => decodeConstructedKeyEvent(event),
  wire.SignaturesProgressEvent event => _decodeSignaturesProgress(event),
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
      contributingParticipantIds: progress.contributingParticipants
          .map((participant) => participant.toBytes())
          .toList(),
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

domain.SignaturesProgress _decodeProgress(wire.SignaturesProgress progress) =>
    domain.SignaturesProgress(
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
      },
    );

domain.SignaturesRequestEvent _decodeSignaturesRequest(
  wire.SignaturesRequestEvent event,
) => domain.SignaturesRequestEvent(
  details: domain.Signed<domain.SignaturesRequestDetails>.fromBytes(
    _bytes(event.signedDetails),
    domain.SignaturesRequestDetails.fromReaderAllowNegativeExpiry,
  ),
  creator: _identifier(event.creatorId),
  progress: _decodeProgress(event.progress),
);

domain.SignaturesProgressEvent _decodeSignaturesProgress(
  wire.SignaturesProgressEvent event,
) => domain.SignaturesProgressEvent(
  reqId: domain.SignaturesRequestId.fromBytes(_bytes(event.requestId)),
  progress: _decodeProgress(event.progress),
);

domain.Identifier _identifier(List<int> bytes) =>
    domain.Identifier.fromBytes(_bytes(bytes));

Uint8List _bytes(List<int> bytes) => Uint8List.fromList(bytes);

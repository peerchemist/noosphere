import 'dart:typed_data';

import 'package:noosphere/noosphere.dart' as protocol;
import 'package:noosphere/domain.dart';

export 'package:noosphere/iroh.dart' show noosphereIrohWireVersion;

extension SessionStartedDomainValues on protocol.SessionStarted {
  SessionID get domainSessionId =>
      SessionID.fromBytes(Uint8List.fromList(sessionId));
}

protocol.Events encodeEvent(Event event) => protocol.Events(
  data: event.toBytes(),
  type: switch (event) {
    ParticipantStatusEvent() => protocol.EventType.PARTICIPANT_STATUS_EVENT,
    NewDkgEvent() => protocol.EventType.NEW_DKG_EVENT,
    DkgCommitmentEvent() => protocol.EventType.DKG_COMMITMENT_EVENT,
    DkgRejectEvent() => protocol.EventType.DKG_REJECT_EVENT,
    DkgRound2ShareEvent() => protocol.EventType.DKG_ROUND2_SHARE_EVENT,
    DkgAckEvent() => protocol.EventType.DKG_ACK_EVENT,
    DkgAckRequestEvent() => protocol.EventType.DKG_ACK_REQUEST_EVENT,
    SignaturesRequestEvent() => protocol.EventType.SIG_REQ_EVENT,
    SignatureNewRoundsEvent() => protocol.EventType.SIG_NEW_ROUNDS_EVENT,
    SignaturesCompleteEvent() => protocol.EventType.SIG_COMPLETE_EVENT,
    SignaturesFailureEvent() => protocol.EventType.SIG_FAILURE_EVENT,
    SignaturesProgressEvent() => protocol.EventType.SIG_PROGRESS_EVENT,
    SecretShareEvent() => protocol.EventType.SECRET_SHARE_EVENT,
    ConstructedKeyEvent() => protocol.EventType.CONSTRUCTED_KEY_EVENT,
    KeepaliveEvent() => protocol.EventType.KEEPALIVE_EVENT,
  },
);

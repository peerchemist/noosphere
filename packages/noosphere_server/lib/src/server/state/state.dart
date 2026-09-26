import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common.dart';
import 'package:noosphere/domain.dart';

import 'client_session.dart';
import 'dkg.dart';
import 'key_sharing.dart';
import 'signatures_coordination.dart';

class ChallengeDetails implements Expirable {
  final Identifier id;
  @override
  final Expiry expiry;
  ChallengeDetails({required this.id, required this.expiry});
}

/// Caches DKG acknowledgements to support sharing amongst participants. The
/// entirety of the cache will expire together. Participants should usually be
/// online immediately after the DKG is complete so that repopulation of the
/// cache is unlikely required.
class DkgAckCache implements Expirable {
  final Map<Identifier, Signed<DkgAck>> acks = {};
  @override
  final Expiry expiry;
  DkgAckCache(this.expiry);
}

class CompletedSignatures implements Expirable {
  final Signed<SignaturesRequestDetails> details;
  final List<cl.SchnorrSignature> signatures;
  final Identifier creator;

  /// This is not set, but in the future can contain acknowledgements from
  /// participants when they have received the signature so that they do not
  /// receive it again and so that signatures can be removed when enough
  /// participants have obtained it.
  final Set<Identifier> acks = {};
  @override
  final Expiry expiry;
  CompletedSignatures({
    required this.details,
    required this.signatures,
    required this.expiry,
    required this.creator,
  });
}

class ServerState {
  final challenges = ExpirableMap<AuthChallenge, ChallengeDetails>();
  late final ExpirableMap<SessionID, ClientSession> clientSessions;
  final participantToSession = ExpirableMap<Identifier, ClientSession>();
  final nameToDkg = ExpirableMap<String, DkgState>();
  final dkgAckCache = ExpirableMap<cl.ECPublicKey, DkgAckCache>();
  final sigRequests =
      ExpirableMap<SignaturesRequestId, SignaturesCoordinationState>();
  final completedSigs =
      ExpirableMap<SignaturesRequestId, CompletedSignatures>();

  /// Maps the encrypted secret shares to a FROST group key for sharing to
  /// participants
  final Map<cl.ECCompressedPublicKey, KeySharingState> secretShares = {};
  ServerState() {
    clientSessions = ExpirableMap(
      onExpired: (_, session) => endSession(session),
    );
  }

  /// Ends [session] exactly once and removes it only when it is still the
  /// current session for its participant.
  bool endSession(ClientSession session) {
    if (!session.end()) return false;

    clientSessions.remove(session.sessionID);
    final current = participantToSession[session.participantId];
    if (identical(current, session)) {
      participantToSession.remove(session.participantId);
    }

    // Reset DKGs to round 1 as all participants need to remain online to
    // complete them
    for (final dkg in nameToDkg.values) {
      if (dkg.round is! DkgRound1State) dkg.round = DkgRound1State([]);
    }

    // Remove public commitment from participant for any round 1 DKGs
    for (final dkg in round1Dkgs) {
      dkg.round1.commitments.removeWhere((c) => c.$1 == session.participantId);
    }

    // Send logout event to other participants
    sendEventToAll(
      ParticipantStatusEvent(id: session.participantId, loggedIn: false),
    );
    return true;
  }

  void onEndSession(ClientSession session) => endSession(session);

  Iterable<DkgState> get round1Dkgs =>
      nameToDkg.values.where((dkg) => dkg.round is DkgRound1State);

  void sendEventToAll(Event e, {List<SessionID> exclude = const []}) {
    for (final session in clientSessions.values) {
      if (!exclude.contains(session.sessionID)) session.sendEvent(e);
    }
  }

  void sendEventToOthers(Event e, SessionID sid) =>
      sendEventToAll(e, exclude: [sid]);

  KeySharingState secretSharesForKey(cl.ECCompressedPublicKey key) =>
      secretShares[key] ??= KeySharingState();
}

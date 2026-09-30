import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common.dart';
import 'package:noosphere/domain.dart';

import 'client_session.dart';
import 'dkg.dart';
import 'key_sharing.dart';
import 'signatures_coordination.dart';
import '../persistence.dart';

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

/// Ephemeral process state. None of these values survive a restart.
class ServerRuntimeState {
  final challenges = ExpirableMap<AuthChallenge, ChallengeDetails>();
  final clientSessions = ExpirableMap<SessionID, ClientSession>(
    expireOnRead: false,
  );
  final participantToSession = ExpirableMap<Identifier, ClientSession>(
    expireOnRead: false,
  );
}

/// Protocol state represented in the host-owned durable snapshot.
class ServerPersistentState {
  final nameToDkg = ExpirableMap<String, DkgState>(expireOnRead: false);
  final dkgAckCache = ExpirableMap<cl.ECPublicKey, DkgAckCache>();
  final sigRequests =
      ExpirableMap<SignaturesRequestId, SignaturesCoordinationState>(
        expireOnRead: false,
      );
  final completedSigs = ExpirableMap<SignaturesRequestId, CompletedSignatures>(
    expireOnRead: false,
  );
  final Map<cl.ECCompressedPublicKey, KeySharingState> secretShares = {};

  /// Attempts found during restoration. DKG attempts are aborted; signing
  /// attempts remain blocked until their signed request expires.
  final Map<String, NewDkgEvent> interruptedDkgs = {};
  final Map<SignaturesRequestId, SignaturesRequestEvent> blockedSignatures = {};
}

class ServerState {
  final runtime = ServerRuntimeState();
  final persistent = ServerPersistentState();

  ExpirableMap<AuthChallenge, ChallengeDetails> get challenges =>
      runtime.challenges;
  ExpirableMap<SessionID, ClientSession> get clientSessions =>
      runtime.clientSessions;
  ExpirableMap<Identifier, ClientSession> get participantToSession =>
      runtime.participantToSession;
  ExpirableMap<String, DkgState> get nameToDkg => persistent.nameToDkg;
  ExpirableMap<cl.ECPublicKey, DkgAckCache> get dkgAckCache =>
      persistent.dkgAckCache;
  ExpirableMap<SignaturesRequestId, SignaturesCoordinationState>
  get sigRequests => persistent.sigRequests;
  ExpirableMap<SignaturesRequestId, CompletedSignatures> get completedSigs =>
      persistent.completedSigs;
  Map<cl.ECCompressedPublicKey, KeySharingState> get secretShares =>
      persistent.secretShares;

  /// Ends [session] exactly once and removes it only when it is still the
  /// current session for its participant.
  bool endSession(ClientSession session, {bool publish = true}) {
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

    if (publish) publishSessionEnded(session);
    return true;
  }

  void publishSessionEnded(ClientSession session) => sendEventToAll(
    ParticipantStatusEvent(id: session.participantId, loggedIn: false),
  );

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

  ServerStateSnapshot snapshot() {
    String bytes(Uint8List value) => base64Encode(value);
    String id(Identifier value) => bytes(value.toBytes());

    final dkg = <Map<String, Object?>>[
      for (final value in nameToDkg.values)
        {
          'status': 'active',
          'event': bytes(
            NewDkgEvent(
              details: value.details,
              creator: value.creator,
              commitments: value.round is DkgRound1State
                  ? value.round1.commitments
                  : const [],
            ).toBytes(),
          ),
        },
      for (final value in persistent.interruptedDkgs.values)
        if (!value.expiry.isExpired)
          {'status': 'interrupted', 'event': bytes(value.toBytes())},
    ];
    final signing = <Map<String, Object?>>[
      for (final value in sigRequests.values)
        {
          'status': 'active',
          'event': bytes(
            SignaturesRequestEvent(
              details: value.details,
              creator: value.creator,
              progress: value.progress,
            ).toBytes(),
          ),
        },
      for (final value in persistent.blockedSignatures.values)
        if (!value.expiry.isExpired)
          {'status': 'blocked', 'event': bytes(value.toBytes())},
    ];
    final completed = <Map<String, Object?>>[
      for (final value in completedSigs.values)
        {
          'result': bytes(
            CompletedSignaturesRequest(
              details: value.details,
              signatures: value.signatures,
              creator: value.creator,
            ).toBytes(),
          ),
          'expiry': value.expiry.time.microsecondsSinceEpoch,
          'acks': value.acks.map(id).toList(),
        },
    ];
    final shares = <Map<String, Object?>>[
      for (final entry in secretShares.entries)
        {
          'groupKey': bytes(entry.key.data),
          'receivers': [
            for (final receiver in entry.value.receiverShares.entries)
              if (receiver.value case final ParticipantDoneShareState done)
                {
                  'kind': 'done',
                  'id': id(receiver.key),
                  'event': bytes(done.constructedEvent.toBytes()),
                }
              else
                {
                  'kind': 'pending',
                  'id': id(receiver.key),
                  'events': [
                    for (final share in receiver.value.pendingShares)
                      bytes(
                        SecretShareEvent(
                          sender: share.sender,
                          keyShare: share.share,
                          groupKey: entry.key,
                        ).toBytes(),
                      ),
                  ],
                },
          ],
        },
    ];
    return ServerStateSnapshot.fromBytes(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': ServerStateSnapshot.currentVersion,
            'dkg': dkg,
            'signing': signing,
            'completed': completed,
            'shares': shares,
          }),
        ),
      ),
    );
  }

  /// Restores durable values. Returns true when active attempts were converted
  /// to their restart-safe interrupted/blocked representation and the upgraded
  /// snapshot must be written before requests are accepted.
  bool restore(ServerStateSnapshot snapshot) {
    Uint8List bytes(Object? value) => base64Decode(value! as String);
    Identifier id(Object? value) => Identifier.fromBytes(bytes(value));
    final root = jsonDecode(utf8.decode(snapshot.toBytes())) as Map;
    var changed = false;

    for (final raw in root['dkg']! as List) {
      final record = raw as Map;
      final event = NewDkgEvent.fromBytes(bytes(record['event']));
      if (event.expiry.isExpired) {
        changed = true;
        continue;
      }
      persistent.interruptedDkgs[event.details.obj.name] = event;
      if (record['status'] == 'active') changed = true;
    }
    for (final raw in root['signing']! as List) {
      final record = raw as Map;
      final event = SignaturesRequestEvent.fromBytes(bytes(record['event']));
      if (event.expiry.isExpired) {
        changed = true;
        continue;
      }
      persistent.blockedSignatures[event.details.obj.id] = event;
      if (record['status'] == 'active') changed = true;
    }
    for (final raw in root['completed']! as List) {
      final record = raw as Map;
      final expiry = Expiry.fromTime(
        DateTime.fromMicrosecondsSinceEpoch(record['expiry']! as int),
      );
      if (expiry.isExpired) {
        changed = true;
        continue;
      }
      final result = CompletedSignaturesRequest.fromBytes(
        bytes(record['result']),
      );
      final restored = CompletedSignatures(
        details: result.details,
        signatures: result.signatures,
        expiry: expiry,
        creator: result.creator,
      );
      restored.acks.addAll((record['acks']! as List).map(id));
      completedSigs[result.details.obj.id] = restored;
    }
    for (final raw in root['shares']! as List) {
      final record = raw as Map;
      final groupKey = cl.ECCompressedPublicKey(bytes(record['groupKey']));
      final sharing = secretSharesForKey(groupKey);
      for (final receiverRaw in record['receivers']! as List) {
        final receiver = receiverRaw as Map;
        final receiverId = id(receiver['id']);
        if (receiver['kind'] == 'done') {
          sharing.receiverShares[receiverId] = ParticipantDoneShareState(
            ConstructedKeyEvent.fromBytes(bytes(receiver['event'])),
          );
        } else {
          for (final encoded in receiver['events']! as List) {
            final event = SecretShareEvent.fromBytes(bytes(encoded));
            sharing.maybeAddShare(event.sender, receiverId, event.keyShare);
          }
        }
      }
    }
    return changed;
  }
}

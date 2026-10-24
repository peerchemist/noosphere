import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/common.dart';
import 'package:noosphere_protocol/domain.dart';
import 'package:noosphere_protocol/public_feed.dart';

import '../../config/public_feed.dart';
import '../../config/server.dart';
import '../persistence.dart';
import 'client_session.dart';
import 'dkg.dart';
import 'key_sharing.dart';
import 'public_feed.dart';
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

/// Ephemeral process state. None of these values survive a restart.
class ServerRuntimeState {
  final challenges = ExpirableMap<AuthChallenge, ChallengeDetails>();
  final clientSessions = ExpirableMap<SessionID, ClientSession>(
    expireOnRead: false,
  );
  final participantToSession = ExpirableMap<Identifier, ClientSession>(
    expireOnRead: false,
  );
  final Map<Identifier, List<DateTime>> dkgRequestTimes = {};
  final Map<Identifier, List<DateTime>> signingRequestTimes = {};
  final Map<Identifier, List<DateTime>> recoveryRequestTimes = {};
}

/// Protocol state represented in the host-owned durable snapshot.
class ServerPersistentState {
  PublicFeedJournal? publicFeed;
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

  final Map<String, FinalExpirable> terminalDkgs = {};
  final Map<SignaturesRequestId, SignaturesRequestEvent> blockedSignatures = {};
  final cancelledSignatures =
      ExpirableMap<SignaturesRequestId, CancelledSignaturesRequest>(
        expireOnRead: false,
      );

  /// Minimal records for failed/rejected requests; cancellation cannot rewrite them.
  final Map<SignaturesRequestId, FinalExpirable> terminalSignatures = {};
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

  int get dkgPayloadBytes =>
      nameToDkg.values.fold(0, (total, dkg) => total + dkg.persistedByteSize) +
      persistent.terminalDkgs.length * 40;

  int get retainedSigningCount =>
      sigRequests.values.length +
      completedSigs.values.length +
      persistent.blockedSignatures.length +
      persistent.cancelledSignatures.values.length +
      persistent.terminalSignatures.length;

  int get recoveryPayloadBytes => secretShares.entries.fold(
    0,
    (total, entry) => total + 33 + entry.value.payloadBytes(entry.key),
  );

  /// Ends [session] exactly once and removes it only when it is still the
  /// current session for its participant.
  bool endSession(ClientSession session, {bool publish = true}) {
    if (!session.end()) return false;

    clientSessions.remove(session.sessionID);
    final current = participantToSession[session.participantId];
    if (identical(current, session)) {
      participantToSession.remove(session.participantId);
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
          'status': 'resumable',
          'details': bytes(value.details.toBytes()),
          'creator': id(value.creator),
          'round': value.round is DkgRound1State ? 1 : 2,
          'commitments': [
            for (final commitment in value.commitments)
              {
                'participant': id(commitment.$1),
                'commitment': bytes(commitment.$2.toBytes()),
              },
          ],
          if (value.round case final DkgRound2State round2) ...{
            'expectedHash': bytes(round2.expectedHash),
            'participantCount': round2.participantCount,
            'contributions': [
              for (final entry in round2.contributions.entries)
                {
                  'sender': id(entry.key),
                  'signature': bytes(entry.value.commitmentSetSignature.data),
                  'secrets': [
                    for (final secret in entry.value.secrets.entries)
                      {
                        'recipient': id(secret.key),
                        'ciphertext': bytes(secret.value.toBytes()),
                      },
                  ],
                },
            ],
          },
          'completionAcks': [
            for (final entry in value.completionAcks.entries)
              bytes(
                SignedDkgAck(signer: entry.key, signed: entry.value).toBytes(),
              ),
          ],
        },
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
            'format': ServerStateSnapshot.currentFormat,
            'dkg': dkg,
            'signing': signing,
            'completed': completed,
            'shares': shares,
            'cancelled': [
              for (final value in persistent.cancelledSignatures.values)
                bytes(value.toBytes()),
            ],
            'terminalSigning': [
              for (final entry in persistent.terminalSignatures.entries)
                if (!entry.value.expiry.isExpired)
                  {
                    'id': bytes(entry.key.toBytes()),
                    'expiry': entry.value.expiry.time.microsecondsSinceEpoch,
                  },
            ],
            'terminalDkg': [
              for (final entry in persistent.terminalDkgs.entries)
                if (!entry.value.expiry.isExpired)
                  {
                    'ceremonyId': bytes(cl.hexToBytes(entry.key)),
                    'expiry': entry.value.expiry.time.microsecondsSinceEpoch,
                  },
            ],
            if (persistent.publicFeed case final feed?)
              'publicFeed': feed.toJson(),
          }),
        ),
      ),
    );
  }

  /// Restores durable values. Returns true when expiry or restart recovery
  /// changed current-version state and it must be rewritten before requests are
  /// accepted.
  bool restore(ServerStateSnapshot snapshot, {required ServerConfig config}) {
    Uint8List bytes(Object? value) => base64Decode(value! as String);
    Identifier id(Object? value) => Identifier.fromBytes(bytes(value));
    void require(bool valid) {
      if (!valid) throw const FormatException('Invalid server state snapshot.');
    }

    final root = jsonDecode(utf8.decode(snapshot.toBytes())) as Map;
    require((root['shares'] as List).length <= ServerConfig.maxRecoveryKeys);
    require(
      ['signing', 'completed', 'cancelled', 'terminalSigning'].fold<int>(
            0,
            (total, name) => total + (root[name] as List).length,
          ) <=
          ServerConfig.maxRetainedSignaturesRequests,
    );
    var changed = false;
    if (root['publicFeed'] case final Map<Object?, Object?> raw) {
      persistent.publicFeed = PublicFeedJournal.fromJson(raw);
    }
    changed = configurePublicFeed(config.publicFeed) || changed;

    for (final raw in root['cancelled']! as List) {
      final tombstone = CancelledSignaturesRequest.fromBytes(bytes(raw));
      if (tombstone.expiry.isExpired) {
        changed = true;
        continue;
      }
      persistent.cancelledSignatures[tombstone.requestId] = tombstone;
    }
    for (final raw in root['terminalSigning']! as List) {
      final record = raw as Map;
      final expiry = Expiry.fromTime(
        DateTime.fromMicrosecondsSinceEpoch(record['expiry']! as int),
      );
      if (expiry.isExpired) {
        changed = true;
        continue;
      }
      persistent.terminalSignatures[SignaturesRequestId.fromBytes(
        bytes(record['id']),
      )] = FinalExpirable(
        expiry,
      );
    }

    for (final raw in root['terminalDkg']! as List) {
      final record = raw as Map;
      final ceremonyId = bytes(record['ceremonyId']);
      final expiry = Expiry.fromTime(
        DateTime.fromMicrosecondsSinceEpoch(record['expiry']! as int),
      );
      if (expiry.isExpired) {
        changed = true;
        continue;
      }
      final key = cl.bytesToHex(ceremonyId);
      require(
        ceremonyId.length == 32 &&
            expiry.ttl <= config.maxDkgRequestTTL &&
            !persistent.terminalDkgs.containsKey(key),
      );
      persistent.terminalDkgs[key] = FinalExpirable(expiry);
    }
    require(dkgPayloadBytes <= ServerConfig.maxDkgStateBytes);

    for (final raw in root['dkg']! as List) {
      final record = raw as Map;
      require(record['status'] == 'resumable');
      final signedDetails = Signed<NewDkgDetails>.fromBytes(
        bytes(record['details']),
        NewDkgDetails.fromReaderAllowExpired,
      );
      final details = signedDetails.obj;
      final creator = id(record['creator']);
      final creatorKey = config.group.participants[creator];
      require(
        creatorKey != null &&
            signedDetails.verify(creatorKey) &&
            details.protocolVersion == noosphereProtocolVersion &&
            cl.bytesEqual(details.groupFingerprint, config.group.fingerprint) &&
            details.threshold <= config.group.participants.length &&
            details.expiry.ttl <= config.maxDkgRequestTTL &&
            !nameToDkg.containsKey(details.name) &&
            !persistent.terminalDkgs.containsKey(
              cl.bytesToHex(details.ceremonyId),
            ),
      );
      if (signedDetails.obj.expiry.isExpired) {
        persistent.publicFeed?.finish(
          'dkg:${signedDetails.obj.name}',
          PublicFeedLifecycle.expired,
        );
        changed = true;
        continue;
      }
      final commitments = <(Identifier, DkgPublicCommitment)>[];
      final commitmentIds = <Identifier>{};
      for (final commitmentRaw in record['commitments']! as List) {
        final commitment = commitmentRaw as Map;
        final participant = id(commitment['participant']);
        require(
          config.group.participants.containsKey(participant) &&
              commitmentIds.add(participant),
        );
        commitments.add((
          participant,
          DkgPublicCommitment.fromBytes(bytes(commitment['commitment'])),
        ));
      }
      final roundNumber = record['round'];
      require(
        commitments.isNotEmpty &&
            commitmentIds.contains(creator) &&
            commitments.length <= config.group.participants.length &&
            (roundNumber == 1
                ? commitments.length < config.group.participants.length
                : roundNumber == 2 &&
                      commitments.length == config.group.participants.length),
      );
      final restored = DkgState(
        details: signedDetails,
        creator: creator,
        commitments: commitments,
      );
      if (roundNumber == 2) {
        final expectedHash = bytes(record['expectedHash']);
        final recomputedHash = details.hashWithCommitments(
          DkgCommitmentSet(commitments),
        );
        require(
          cl.bytesEqual(expectedHash, recomputedHash) &&
              record['participantCount'] == config.group.participants.length,
        );
        final round2 = DkgRound2State(
          expectedHash: expectedHash,
          commitments: commitments,
          participantCount: record['participantCount'] as int,
        );
        for (final contributionRaw in record['contributions']! as List) {
          final contribution = contributionRaw as Map;
          final sender = id(contribution['sender']);
          final senderKey = config.group.participants[sender];
          require(
            senderKey != null && !round2.contributions.containsKey(sender),
          );
          final signature = cl.SchnorrSignature(
            bytes(contribution['signature']),
          );
          require(signature.verify(senderKey!, expectedHash));
          final expectedRecipients = config.group.participants.keys.toSet()
            ..remove(sender);
          final secrets = <Identifier, DkgEncryptedSecret>{};
          for (final secretRaw in contribution['secrets']! as List) {
            final secretRecord = secretRaw as Map;
            final recipient = id(secretRecord['recipient']);
            final secretBytes = bytes(secretRecord['ciphertext']);
            require(
              secretBytes.length <= ServerConfig.maxEncryptedDkgShareBytes,
            );
            final secret = DkgEncryptedSecret.fromBytes(secretBytes);
            require(
              expectedRecipients.contains(recipient) &&
                  !secrets.containsKey(recipient) &&
                  secret.verify(
                    protocolVersion: details.protocolVersion,
                    ceremonyId: details.ceremonyId,
                    transcriptHash: expectedHash,
                    sender: sender,
                    recipient: recipient,
                    senderKey: senderKey,
                  ),
            );
            secrets[recipient] = secret;
          }
          require(secrets.length == expectedRecipients.length);
          round2.contributions[sender] = DkgRound2Contribution(
            commitmentSetSignature: signature,
            secrets: secrets,
          );
        }
        restored.round = round2;
      }
      cl.ECCompressedPublicKey? completedKey;
      for (final encoded in record['completionAcks']! as List) {
        final ack = SignedDkgAck.fromBytes(bytes(encoded));
        final ackKey = config.group.participants[ack.signer];
        final round2 = restored.round is DkgRound2State
            ? restored.round2
            : null;
        require(
          ackKey != null &&
              round2 != null &&
              round2.allSharesSubmitted &&
              round2.contributions.containsKey(ack.signer) &&
              !restored.completionAcks.containsKey(ack.signer) &&
              ack.signed.verify(ackKey) &&
              ack.signed.obj.accepted &&
              cl.bytesEqual(ack.signed.obj.ceremonyId, details.ceremonyId) &&
              cl.bytesEqual(
                ack.signed.obj.transcriptHash,
                round2.expectedHash,
              ) &&
              (completedKey == null || completedKey == ack.signed.obj.groupKey),
        );
        completedKey ??= ack.signed.obj.groupKey;
        restored.completionAcks[ack.signer] = ack.signed;
      }
      nameToDkg[signedDetails.obj.name] = restored;
      require(
        nameToDkg.values.length <= ServerConfig.maxActiveDkgs &&
            dkgPayloadBytes <= ServerConfig.maxDkgStateBytes,
      );
    }
    for (final raw in root['signing']! as List) {
      final record = raw as Map;
      final event = SignaturesRequestEvent.fromBytes(bytes(record['event']));
      require(
        event.details.obj.requiredSigs.length <=
                ServerConfig.maxSignaturesPerRequest &&
            event.details.toBytes().length <=
                ServerConfig.maxSigningRequestBytes,
      );
      if (persistent.cancelledSignatures.containsKey(event.details.obj.id)) {
        changed = true;
        continue;
      }
      if (event.expiry.isExpired) {
        persistent.publicFeed?.finish(
          'signing:${event.details.obj.id}',
          PublicFeedLifecycle.expired,
        );
        changed = true;
        continue;
      }
      persistent.blockedSignatures[event.details.obj.id] = event;
      if (record['status'] == 'active') {
        persistent.publicFeed?.finish(
          'signing:${event.details.obj.id}',
          PublicFeedLifecycle.failed,
        );
        changed = true;
      }
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
      require(
        result.details.obj.requiredSigs.length <=
                ServerConfig.maxSignaturesPerRequest &&
            result.details.toBytes().length <=
                ServerConfig.maxSigningRequestBytes &&
            result.signatures.length == result.details.obj.requiredSigs.length,
      );
      if (persistent.cancelledSignatures.containsKey(result.details.obj.id)) {
        throw StateError('Completed signatures conflict with cancellation');
      }
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
      require(!secretShares.containsKey(groupKey));
      require(
        (record['receivers'] as List).length <=
            config.group.participants.length,
      );
      final sharing = secretSharesForKey(groupKey);
      for (final receiverRaw in record['receivers']! as List) {
        final receiver = receiverRaw as Map;
        final receiverId = id(receiver['id']);
        require(
          config.group.participants.containsKey(receiverId) &&
              !sharing.receiverShares.containsKey(receiverId),
        );
        if (receiver['kind'] == 'done') {
          final event = ConstructedKeyEvent.fromBytes(bytes(receiver['event']));
          require(
            event.participant == receiverId &&
                event.constructedKey.obj.publicKey == groupKey &&
                event.constructedKey.verify(
                  config.group.participants[receiverId]!,
                ),
          );
          sharing.receiverShares[receiverId] = ParticipantDoneShareState(event);
        } else {
          require(
            receiver['kind'] == 'pending' &&
                (receiver['events'] as List).length <
                    config.group.participants.length,
          );
          for (final encoded in receiver['events']! as List) {
            final event = SecretShareEvent.fromBytes(bytes(encoded));
            require(
              event.groupKey == groupKey &&
                  event.sender != receiverId &&
                  config.group.participants.containsKey(event.sender) &&
                  event.keyShare.ciphertext.toBytes().length <=
                      ServerConfig.maxEncryptedRecoveryShareBytes,
            );
            require(
              sharing.maybeAddShare(event.sender, receiverId, event.keyShare),
            );
          }
        }
      }
    }
    require(recoveryPayloadBytes <= ServerConfig.maxRecoveryStateBytes);
    changed = (persistent.publicFeed?.expire() ?? false) || changed;
    return changed;
  }

  bool configurePublicFeed(PublicFeedConfig? config) {
    var feed = persistent.publicFeed;
    if (feed == null) {
      if (config == null) return false;
      persistent.publicFeed = PublicFeedJournal(config);
      return true;
    }
    if (config != null && feed.feedId != config.feedId) {
      throw StateError(
        'Public feed ID cannot change for a persisted coordinator',
      );
    }
    final enabled = config != null;
    var changed = feed.enabled != enabled;
    feed.enabled = enabled;
    if (config != null) {
      changed =
          changed ||
          feed.maxEntries != config.maxEntries ||
          feed.maxAge != config.maxAge;
      feed.maxEntries = config.maxEntries;
      feed.maxAge = config.maxAge;
    }
    return feed.prune() || changed;
  }
}

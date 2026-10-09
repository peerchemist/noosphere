import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere/config.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/room.dart';

import 'persistence.dart';

enum RoomFailureCode {
  unknownRoom,
  unknownInvite,
  roomMismatch,
  participantKeyMismatch,
  coordinatorMismatch,
  invalidSignature,
  expiredInvite,
  usedInvite,
  revokedInvite,
  expiredChallenge,
  replayedChallenge,
  malformedProof,
  unsupportedVersion,
  duplicateParticipant,
  roomFull,
  roomNotEnrolling,
  rosterIncomplete,
}

final class RoomException implements Exception {
  const RoomException(this.code);

  final RoomFailureCode code;
  String get message => switch (code) {
    RoomFailureCode.unknownRoom => 'unknown room',
    RoomFailureCode.unknownInvite => 'unknown invite or invalid token',
    RoomFailureCode.roomMismatch => 'invite belongs to another room',
    RoomFailureCode.participantKeyMismatch =>
      'invite is bound to another participant public key',
    RoomFailureCode.coordinatorMismatch =>
      'invite is pinned to another coordinator',
    RoomFailureCode.invalidSignature =>
      'invalid participant proof of possession',
    RoomFailureCode.expiredInvite => 'invite expired',
    RoomFailureCode.usedInvite => 'invite was already used',
    RoomFailureCode.revokedInvite => 'invite was revoked',
    RoomFailureCode.expiredChallenge => 'enrollment challenge expired',
    RoomFailureCode.replayedChallenge =>
      'challenge is unknown or was already consumed',
    RoomFailureCode.malformedProof =>
      'signed transcript differs from issued challenge',
    RoomFailureCode.unsupportedVersion => 'unsupported enrollment version',
    RoomFailureCode.duplicateParticipant => 'participant is already registered',
    RoomFailureCode.roomFull => 'room is full',
    RoomFailureCode.roomNotEnrolling => 'room is not accepting enrollment',
    RoomFailureCode.rosterIncomplete => 'room roster is not complete',
  };

  @override
  String toString() => 'RoomException(${code.name}): $message';
}

/// Sanitized diagnostic for a rejected enrollment attempt.
final class RoomEnrollmentRejected {
  const RoomEnrollmentRejected({
    required this.roomId,
    required this.inviteId,
    required this.participantFingerprint,
    required this.reason,
    required this.at,
  });

  final String? roomId;
  final String? inviteId;
  final String? participantFingerprint;
  final RoomFailureCode reason;
  final DateTime at;
}

/// Atomic state machine for pubkey-bound room enrollment.
final class RoomManager implements RoomEnrollmentApi {
  RoomManager._({
    required Uint8List coordinatorEndpointId,
    required this.persistence,
    required this.challengeTtl,
  }) : _coordinatorEndpointId = _copy32(
         coordinatorEndpointId,
         'coordinatorEndpointId',
       );

  static Future<RoomManager> open({
    required Uint8List coordinatorEndpointId,
    required RoomPersistence persistence,
    Duration challengeTtl = const Duration(seconds: 20),
  }) async {
    if (challengeTtl <= Duration.zero) {
      throw ArgumentError.value(challengeTtl, 'challengeTtl');
    }
    final manager = RoomManager._(
      coordinatorEndpointId: coordinatorEndpointId,
      persistence: persistence,
      challengeTtl: challengeTtl,
    );
    final records = await manager.persistence.loadAll();
    for (final entry in records.entries) {
      final room = RoomSnapshot.fromBytes(entry.value);
      if (room.roomId != entry.key) {
        throw StateError('persisted room key does not match its record');
      }
      if (!cl.bytesEqual(room.coordinatorEndpointId, coordinatorEndpointId)) {
        throw StateError(
          'persisted coordinator endpoint ID does not match active identity',
        );
      }
      manager._rooms[room.roomId] = room;
    }
    return manager;
  }

  final Uint8List _coordinatorEndpointId;
  Uint8List get coordinatorEndpointId =>
      Uint8List.fromList(_coordinatorEndpointId);
  final RoomPersistence persistence;
  final Duration challengeTtl;

  final Map<String, RoomSnapshot> _rooms = {};
  final Map<String, _PendingChallenge> _challenges = {};
  bool _writeOutcomeUnknown = false;
  final _SerialExecutor _serial = _SerialExecutor();
  final _snapshots = StreamController<RoomSnapshot>.broadcast();
  final _rejections = StreamController<RoomEnrollmentRejected>.broadcast();

  Stream<RoomSnapshot> get snapshots => _snapshots.stream;
  Stream<RoomEnrollmentRejected> get rejectedEnrollments => _rejections.stream;

  Future<RoomSnapshot> createRoom({
    String? roomId,
    required int expectedParticipants,
    required int threshold,
  }) => _serial.run(() async {
    _requireWritable();
    if (expectedParticipants < 2 || expectedParticipants > 0xffff) {
      throw RangeError.range(
        expectedParticipants,
        2,
        0xffff,
        'expectedParticipants',
      );
    }
    if (threshold < 1 || threshold > expectedParticipants) {
      throw RangeError.range(threshold, 1, expectedParticipants, 'threshold');
    }
    final id = roomId ?? cl.bytesToHex(cl.generateRandomBytes(16));
    if (id.isEmpty || id.length > 255) {
      throw ArgumentError.value(id, 'roomId', 'must be 1..255 characters');
    }
    if (_rooms.containsKey(id)) throw StateError('room already exists');
    final room = RoomSnapshot(
      roomId: id,
      lifecycle: RoomLifecycle.enrolling,
      expectedParticipants: expectedParticipants,
      threshold: threshold,
      coordinatorEndpointId: coordinatorEndpointId,
      invites: const [],
      participants: const [],
      groupConfig: null,
    );
    await _commit(room);
    return _emit(room);
  });

  Future<RoomSnapshot> getRoom(String roomId) => _serial.run(() async {
    return _snapshot(_requireRoom(roomId));
  });

  Future<List<RoomSnapshot>> getRooms() => _serial.run(() async {
    final ids = _rooms.keys.toList()..sort();
    return [for (final id in ids) _snapshot(_rooms[id]!)];
  });

  Future<RoomInvite> issueRoomInvite({
    required String roomId,
    required cl.ECCompressedPublicKey expectedParticipantPublicKey,
    required DateTime expiresAt,
    DateTime? now,
  }) => _serial.run(() async {
    _requireWritable();
    final time = now ?? DateTime.now();
    final current = _requireEnrolling(_requireRoom(roomId));
    if (!expiresAt.isAfter(time)) {
      throw const RoomException(RoomFailureCode.expiredInvite);
    }
    if (_hasParticipant(current, expectedParticipantPublicKey) ||
        current.invites.any(
          (invite) =>
              invite.isPendingAt(time) &&
              invite.expectedParticipantPublicKey ==
                  expectedParticipantPublicKey,
        )) {
      throw const RoomException(RoomFailureCode.duplicateParticipant);
    }
    final activeInvites = current.invites
        .where((invite) => invite.isPendingAt(time))
        .length;
    if (current.participants.length + activeInvites >=
        current.expectedParticipants) {
      throw const RoomException(RoomFailureCode.roomFull);
    }
    final token = cl.generateRandomBytes(32);
    final invite = RoomInvite(
      roomId: roomId,
      inviteId: cl.bytesToHex(cl.generateRandomBytes(16)),
      token: token,
      expectedParticipantPublicKey: expectedParticipantPublicKey,
      coordinatorEndpointId: coordinatorEndpointId,
      expiresAt: expiresAt,
    );
    final updated = current.copyWith(
      invites: [
        ...current.invites,
        RoomInviteSnapshot(
          inviteId: invite.inviteId,
          tokenHash: invite.tokenHash,
          expectedParticipantPublicKey: expectedParticipantPublicKey,
          issuedAt: time,
          expiresAt: expiresAt,
          usedAt: null,
          revokedAt: null,
          status: RoomInviteStatus.pending,
        ),
      ],
    );
    await _commit(updated);
    return invite;
  });

  Future<RoomSnapshot> revokeRoomInvite({
    required String roomId,
    required String inviteId,
    DateTime? now,
  }) => _serial.run(() async {
    _requireWritable();
    final time = now ?? DateTime.now();
    final current = _requireEnrolling(_requireRoom(roomId));
    final index = current.invites.indexWhere(
      (invite) => invite.inviteId == inviteId,
    );
    if (index < 0) throw _unknownInvite();
    final invite = current.invites[index];
    _requirePendingInvite(invite, time);
    final invites = current.invites.toList();
    invites[index] = invite.copyWith(revokedAt: time);
    final updated = current.copyWith(invites: invites);
    await _commit(updated);
    return _emit(updated);
  });

  @override
  Future<EnrollmentChallenge> beginEnrollment({
    required RoomInvite invite,
    required cl.ECCompressedPublicKey participantPublicKey,
    DateTime? now,
  }) => _serial.run(() async {
    _requireWritable();
    final time = now ?? DateTime.now();
    try {
      if (invite.version != noosphereEnrollmentProtocolVersion) {
        throw const RoomException(RoomFailureCode.unsupportedVersion);
      }
      if (!cl.bytesEqual(invite.coordinatorEndpointId, coordinatorEndpointId)) {
        throw const RoomException(RoomFailureCode.coordinatorMismatch);
      }
      final room = _requireEnrolling(_requireRoom(invite.roomId));
      final record = _findInvite(room, invite.inviteId);
      _requirePendingInvite(record, time);
      if (!_constantTimeEqual(record.tokenHash, invite.tokenHash)) {
        throw _unknownInvite();
      }
      if (record.expectedParticipantPublicKey != participantPublicKey ||
          invite.expectedParticipantPublicKey != participantPublicKey) {
        throw const RoomException(RoomFailureCode.participantKeyMismatch);
      }
      if (_hasParticipant(room, participantPublicKey)) {
        throw const RoomException(RoomFailureCode.duplicateParticipant);
      }
      if (room.participants.length >= room.expectedParticipants) {
        throw const RoomException(RoomFailureCode.roomFull);
      }
      final nonce = cl.generateRandomBytes(32);
      final transcript = EnrollmentTranscript.forInvite(invite, nonce);
      final expiresAt = time.add(challengeTtl);
      final challenge = EnrollmentChallenge(
        transcript: transcript,
        expiresAt: expiresAt,
      );
      _challenges[cl.bytesToHex(nonce)] = _PendingChallenge(
        transcript: transcript,
        expiresAt: expiresAt,
      );
      return challenge;
    } on RoomException catch (error) {
      _reject(
        invite.roomId,
        invite.inviteId,
        participantPublicKey,
        error.code,
        time,
      );
      rethrow;
    }
  });

  @override
  Future<RoomSnapshot> redeemRoomInvite(
    Signed<EnrollmentTranscript> proof, {
    DateTime? now,
  }) => _serial.run(() async {
    _requireWritable();
    final time = now ?? DateTime.now();
    final transcript = proof.obj;
    final challengeKey = cl.bytesToHex(transcript.serverNonce);
    final pending = _challenges.remove(challengeKey);
    cl.ECCompressedPublicKey? diagnosticKey;
    try {
      if (pending == null) {
        throw const RoomException(RoomFailureCode.replayedChallenge);
      }
      if (!pending.expiresAt.isAfter(time)) {
        throw const RoomException(RoomFailureCode.expiredChallenge);
      }
      if (!_sameTranscript(pending.transcript, transcript)) {
        throw const RoomException(RoomFailureCode.malformedProof);
      }
      final room = _requireEnrolling(_requireRoom(transcript.roomId));
      final invite = _findInvite(room, transcript.inviteId);
      diagnosticKey = invite.expectedParticipantPublicKey;
      _requirePendingInvite(invite, time);
      if (!_constantTimeEqual(invite.tokenHash, transcript.inviteTokenHash)) {
        throw _unknownInvite();
      }
      if (invite.expectedParticipantPublicKey !=
          transcript.expectedParticipantPublicKey) {
        throw const RoomException(RoomFailureCode.participantKeyMismatch);
      }
      if (!cl.bytesEqual(
        transcript.coordinatorEndpointId,
        coordinatorEndpointId,
      )) {
        throw const RoomException(RoomFailureCode.coordinatorMismatch);
      }
      if (!proof.verify(invite.expectedParticipantPublicKey)) {
        throw const RoomException(RoomFailureCode.invalidSignature);
      }
      if (_hasParticipant(room, invite.expectedParticipantPublicKey)) {
        throw const RoomException(RoomFailureCode.duplicateParticipant);
      }
      if (room.participants.length >= room.expectedParticipants) {
        throw const RoomException(RoomFailureCode.roomFull);
      }
      final inviteIndex = room.invites.indexOf(invite);
      final invites = room.invites.toList();
      invites[inviteIndex] = invite.copyWith(usedAt: time);
      final updated = room.copyWith(
        invites: invites,
        participants: [
          ...room.participants,
          RoomParticipantSnapshot(
            publicKey: invite.expectedParticipantPublicKey,
            enrolledAt: time,
            identifier: null,
          ),
        ],
      );
      // The single serial lane plus durable write-before-publish makes invite
      // consumption and participant insertion one atomic state transition.
      await _commit(updated);
      return _emit(updated);
    } on RoomException catch (error) {
      _reject(
        transcript.roomId,
        transcript.inviteId,
        diagnosticKey ?? transcript.expectedParticipantPublicKey,
        error.code,
        time,
      );
      rethrow;
    }
  });

  Future<RoomSnapshot> freezeRoom(String roomId) => _serial.run(() async {
    _requireWritable();
    final current = _requireEnrolling(_requireRoom(roomId));
    if (current.participants.length != current.expectedParticipants) {
      throw const RoomException(RoomFailureCode.rosterIncomplete);
    }
    final ordered = current.participants.toList()
      ..sort((a, b) => _compareBytes(a.publicKey.data, b.publicKey.data));
    final participants = <RoomParticipantSnapshot>[];
    final configParticipants = <Identifier, cl.ECCompressedPublicKey>{};
    for (var index = 0; index < ordered.length; index++) {
      final identifier = Identifier.fromUint16(index + 1);
      final participant = ordered[index].copyWith(identifier: identifier);
      participants.add(participant);
      configParticipants[identifier] = participant.publicKey;
    }
    final group = GroupConfig(
      id: current.roomId,
      participants: configParticipants,
    );
    final updated = current.copyWith(
      lifecycle: RoomLifecycle.frozen,
      participants: participants,
      groupConfig: group,
    );
    await _commit(updated);
    return _emit(updated);
  });

  Future<RoomSnapshot> closeRoom(String roomId) => _serial.run(() async {
    _requireWritable();
    final current = _requireRoom(roomId);
    if (current.lifecycle == RoomLifecycle.closed) return _snapshot(current);
    final updated = current.copyWith(lifecycle: RoomLifecycle.closed);
    await _commit(updated);
    return _emit(updated);
  });

  Future<void> close() async {
    await _serial.run(() async {});
    await _snapshots.close();
    await _rejections.close();
  }

  Future<void> _commit(RoomSnapshot room) async {
    final bytes = room.toBytes();
    try {
      await persistence.write(room.roomId, bytes);
    } catch (_) {
      // A failed Future cannot tell us whether the host committed before its
      // reply was lost. Retrying from this stale snapshot could overwrite a
      // newer durable record, so only reopening (and reloading) may clear the
      // latch.
      _writeOutcomeUnknown = true;
      rethrow;
    }
    _rooms[room.roomId] = room;
  }

  void _requireWritable() {
    if (_writeOutcomeUnknown) {
      throw StateError(
        'Room storage outcome is unknown; reopen RoomManager before mutating.',
      );
    }
  }

  RoomSnapshot _requireRoom(String roomId) {
    final room = _rooms[roomId];
    if (room == null) {
      throw const RoomException(RoomFailureCode.unknownRoom);
    }
    return room;
  }

  RoomSnapshot _requireEnrolling(RoomSnapshot room) {
    if (room.lifecycle != RoomLifecycle.enrolling) {
      throw const RoomException(RoomFailureCode.roomNotEnrolling);
    }
    return room;
  }

  RoomInviteSnapshot _findInvite(RoomSnapshot room, String inviteId) {
    for (final invite in room.invites) {
      if (invite.inviteId == inviteId) return invite;
    }
    throw _unknownInvite();
  }

  void _requirePendingInvite(RoomInviteSnapshot invite, DateTime now) {
    if (invite.usedAt != null) {
      throw const RoomException(RoomFailureCode.usedInvite);
    }
    if (invite.revokedAt != null) {
      throw const RoomException(RoomFailureCode.revokedInvite);
    }
    if (!invite.expiresAt.isAfter(now)) {
      throw const RoomException(RoomFailureCode.expiredInvite);
    }
  }

  RoomSnapshot _emit(RoomSnapshot room) {
    final snapshot = _snapshot(room);
    _snapshots.add(snapshot);
    return snapshot;
  }

  RoomSnapshot _snapshot(RoomSnapshot room) => room.at(DateTime.now());

  void _reject(
    String roomId,
    String inviteId,
    cl.ECCompressedPublicKey publicKey,
    RoomFailureCode reason,
    DateTime at,
  ) => _rejections.add(
    RoomEnrollmentRejected(
      roomId: roomId,
      inviteId: inviteId,
      participantFingerprint: _fingerprint(publicKey),
      reason: reason,
      at: at,
    ),
  );
}

RoomException _unknownInvite() =>
    const RoomException(RoomFailureCode.unknownInvite);

bool _hasParticipant(RoomSnapshot room, cl.ECCompressedPublicKey publicKey) =>
    room.participants.any((participant) => participant.publicKey == publicKey);

String _fingerprint(cl.ECCompressedPublicKey key) =>
    cl.bytesToHex(cl.sha256Hash(key.data).sublist(0, 8));

bool _sameTranscript(EnrollmentTranscript a, EnrollmentTranscript b) =>
    cl.bytesEqual(a.toBytes(), b.toBytes());

bool _constantTimeEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var index = 0; index < a.length; index++) {
    difference |= a[index] ^ b[index];
  }
  return difference == 0;
}

int _compareBytes(Uint8List a, Uint8List b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final comparison = a[i].compareTo(b[i]);
    if (comparison != 0) return comparison;
  }
  return a.length.compareTo(b.length);
}

Uint8List _copy32(Uint8List bytes, String name) {
  if (bytes.length != 32) {
    throw ArgumentError.value(bytes.length, name, 'must contain 32 bytes');
  }
  return Uint8List.fromList(bytes);
}

final class _PendingChallenge {
  const _PendingChallenge({required this.transcript, required this.expiresAt});

  final EnrollmentTranscript transcript;
  final DateTime expiresAt;
}

final class _SerialExecutor {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

extension on RoomSnapshot {
  RoomSnapshot copyWith({
    RoomLifecycle? lifecycle,
    Iterable<RoomInviteSnapshot>? invites,
    Iterable<RoomParticipantSnapshot>? participants,
    GroupConfig? groupConfig,
  }) => RoomSnapshot(
    roomId: roomId,
    lifecycle: lifecycle ?? this.lifecycle,
    expectedParticipants: expectedParticipants,
    threshold: threshold,
    coordinatorEndpointId: coordinatorEndpointId,
    invites: invites ?? this.invites,
    participants: participants ?? this.participants,
    groupConfig: groupConfig ?? this.groupConfig,
  );

  RoomSnapshot at(DateTime time) =>
      copyWith(invites: [for (final invite in invites) invite.at(time)]);
}

extension on RoomInviteSnapshot {
  bool isPendingAt(DateTime time) =>
      usedAt == null && revokedAt == null && expiresAt.isAfter(time);

  RoomInviteStatus statusAt(DateTime time) {
    if (usedAt != null) return RoomInviteStatus.used;
    if (revokedAt != null) return RoomInviteStatus.revoked;
    return expiresAt.isAfter(time)
        ? RoomInviteStatus.pending
        : RoomInviteStatus.expired;
  }

  RoomInviteSnapshot at(DateTime time) => copyWith(status: statusAt(time));

  RoomInviteSnapshot copyWith({
    DateTime? usedAt,
    DateTime? revokedAt,
    RoomInviteStatus? status,
  }) => RoomInviteSnapshot(
    inviteId: inviteId,
    expectedParticipantPublicKey: expectedParticipantPublicKey,
    tokenHash: tokenHash,
    issuedAt: issuedAt,
    expiresAt: expiresAt,
    usedAt: usedAt ?? this.usedAt,
    revokedAt: revokedAt ?? this.revokedAt,
    status: status ?? this.status,
  );
}

extension on RoomParticipantSnapshot {
  RoomParticipantSnapshot copyWith({Identifier? identifier}) =>
      RoomParticipantSnapshot(
        publicKey: publicKey,
        enrolledAt: enrolledAt,
        identifier: identifier ?? this.identifier,
      );
}

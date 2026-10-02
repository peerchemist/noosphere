import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/api/types/new_dkg_details.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/common/serial.dart';
import 'package:noosphere/config/group.dart';

const String noosphereGroupTransitionProposalDomain =
    'noosphere/group-transition-proposal/1';
const int noosphereGroupTransitionProposalVersion = 1;

final class UnsupportedGroupTransitionVersion implements FormatException {
  const UnsupportedGroupTransitionVersion(this.version);

  final int version;

  @override
  String get message => 'unsupported group transition version: $version';

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'UnsupportedGroupTransitionVersion($version)';
}

/// A single old-to-new FROST key migration authorized by a transition.
///
/// [dkgDetailsHash] is the `NewDkgDetails.sigHash` that the successor group is
/// allowed to execute. The resulting successor key is deliberately absent: it
/// does not exist until that exact DKG completes.
final class GroupTransitionKeyPlan with cl.Writable, NoosphereWritable {
  GroupTransitionKeyPlan({
    required this.keyId,
    required this.sourceGroupKey,
    required this.sourceThreshold,
    required this.targetThreshold,
    required Uint8List dkgDetailsHash,
  }) : _dkgDetailsHash = _copy32(dkgDetailsHash, 'dkgDetailsHash') {
    _checkId(keyId, 'keyId');
    RangeError.checkValueInInterval(sourceThreshold, 2, 0xffff);
    RangeError.checkValueInInterval(targetThreshold, 2, 0xffff);
  }

  factory GroupTransitionKeyPlan.fromReader(cl.BytesReader reader) =>
      GroupTransitionKeyPlan(
        keyId: reader.readString(),
        sourceGroupKey: reader.readPubKey(),
        sourceThreshold: reader.readUInt16(),
        targetThreshold: reader.readUInt16(),
        dkgDetailsHash: reader.readSlice(32),
      );

  final String keyId;
  final cl.ECCompressedPublicKey sourceGroupKey;
  final int sourceThreshold;
  final int targetThreshold;
  final Uint8List _dkgDetailsHash;

  Uint8List get dkgDetailsHash => Uint8List.fromList(_dkgDetailsHash);

  /// Whether [details] is the exact DKG attempt authorized by this plan.
  bool matchesDkgDetails(NewDkgDetails details) =>
      cl.bytesEqual(_dkgDetailsHash, details.sigHash);

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString(keyId)
      ..writePubKey(sourceGroupKey)
      ..writeUInt16(sourceThreshold)
      ..writeUInt16(targetThreshold)
      ..writeSlice(_dkgDetailsHash);
  }
}

/// Opaque, canonical host policy included directly in participant consent.
///
/// Noosphere interprets neither [kind] nor [payload]. A host-specific policy
/// codec defines accounts, assets, destinations, fee limits and retry bounds.
/// Including the bytes rather than only their hash prevents the signed object
/// from becoming detached from the policy participants reviewed.
final class GroupTransitionMigrationPolicy with cl.Writable, NoosphereWritable {
  GroupTransitionMigrationPolicy({
    required this.kind,
    required this.version,
    required Uint8List payload,
  }) : _payload = Uint8List.fromList(payload) {
    _checkId(kind, 'kind');
    RangeError.checkValueInInterval(version, 1, 0xffff);
    if (_payload.isEmpty || _payload.length > 0xffff) {
      throw ArgumentError.value(
        _payload.length,
        'payload',
        'must contain 1..65535 bytes',
      );
    }
  }

  factory GroupTransitionMigrationPolicy.fromReader(cl.BytesReader reader) =>
      GroupTransitionMigrationPolicy(
        kind: reader.readString(),
        version: reader.readUInt16(),
        payload: reader.readVarSlice(),
      );

  final String kind;
  final int version;
  final Uint8List _payload;

  Uint8List get payload => Uint8List.fromList(_payload);
  Uint8List get hash => cl.sha256Hash(toBytes());

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString(kind)
      ..writeUInt16(version)
      ..writeVarSlice(_payload);
  }
}

/// The complete bounded consent payload for creating a successor group.
///
/// Participant keys and key plans are serialized in a canonical order. The
/// source [GroupConfig] is embedded so retained identities are matched by
/// public key rather than by FROST identifier.
final class GroupTransitionProposal
    with cl.Writable, NoosphereWritable, Signable {
  GroupTransitionProposal({
    this.version = noosphereGroupTransitionProposalVersion,
    required this.transitionId,
    required GroupConfig sourceGroup,
    required this.successorRoomId,
    required Uint8List coordinatorEndpointId,
    required Iterable<cl.ECCompressedPublicKey> successorParticipants,
    required Iterable<GroupTransitionKeyPlan> keyPlans,
    required this.migrationPolicy,
    required this.createdAt,
    required this.expiresAt,
  }) : _sourceGroup = Uint8List.fromList(sourceGroup.toBytes()),
       _coordinatorEndpointId = _copy32(
         coordinatorEndpointId,
         'coordinatorEndpointId',
       ),
       successorParticipants = List.unmodifiable(
         successorParticipants.map(_copyPublicKey).toList()
           ..sort((a, b) => _compareBytes(a.data, b.data)),
       ),
       keyPlans = List.unmodifiable(
         keyPlans.toList()..sort(
           (a, b) => _compareBytes(utf8.encode(a.keyId), utf8.encode(b.keyId)),
         ),
       ) {
    _checkVersion(version);
    _checkId(transitionId, 'transitionId');
    _checkId(successorRoomId, 'successorRoomId');
    if (successorRoomId == sourceGroup.id) {
      throw ArgumentError.value(
        successorRoomId,
        'successorRoomId',
        'must differ from the source group ID',
      );
    }
    if (!createdAt.isBefore(expiresAt)) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'must follow createdAt',
      );
    }
    if (this.successorParticipants.length < 2 ||
        this.successorParticipants.length > 0xffff) {
      throw ArgumentError.value(
        this.successorParticipants.length,
        'successorParticipants',
        'must contain 2..65535 participants',
      );
    }
    _requireUniquePublicKeys(
      this.successorParticipants,
      'successorParticipants',
    );
    if (this.keyPlans.isEmpty || this.keyPlans.length > 0xffff) {
      throw ArgumentError.value(
        this.keyPlans.length,
        'keyPlans',
        'must contain 1..65535 plans',
      );
    }
    final keyIds = <String>{};
    final sourceKeys = <String>{};
    for (final plan in this.keyPlans) {
      if (!keyIds.add(plan.keyId)) {
        throw ArgumentError.value(plan.keyId, 'keyPlans', 'duplicate key ID');
      }
      if (!sourceKeys.add(plan.sourceGroupKey.hex)) {
        throw ArgumentError.value(
          plan.sourceGroupKey.hex,
          'keyPlans',
          'duplicate source group key',
        );
      }
      if (plan.sourceThreshold > sourceGroup.participants.length) {
        throw ArgumentError.value(
          plan.sourceThreshold,
          'sourceThreshold',
          'exceeds source participant count',
        );
      }
      if (plan.targetThreshold > this.successorParticipants.length) {
        throw ArgumentError.value(
          plan.targetThreshold,
          'targetThreshold',
          'exceeds successor participant count',
        );
      }
    }
  }

  factory GroupTransitionProposal.fromBytes(Uint8List bytes) {
    final reader = NoosphereBytesReader(bytes);
    if (reader.readString() != noosphereGroupTransitionProposalDomain) {
      throw const FormatException('invalid group transition proposal domain');
    }
    final version = reader.readUInt16();
    _checkVersion(version);
    final proposal = GroupTransitionProposal(
      version: version,
      transitionId: reader.readString(),
      sourceGroup: GroupConfig.fromBytes(reader.readVarSlice()),
      successorRoomId: reader.readString(),
      coordinatorEndpointId: reader.readSlice(32),
      successorParticipants: List.generate(
        reader.readUInt16(),
        (_) => reader.readPubKey(),
      ),
      keyPlans: List.generate(
        reader.readUInt16(),
        (_) => GroupTransitionKeyPlan.fromReader(reader),
      ),
      migrationPolicy: GroupTransitionMigrationPolicy.fromReader(reader),
      createdAt: reader.readTime(),
      expiresAt: reader.readTime(),
    );
    if (!reader.atEnd) {
      throw const FormatException('trailing group transition proposal data');
    }
    if (!cl.bytesEqual(bytes, proposal.toBytes())) {
      throw const FormatException('non-canonical group transition proposal');
    }
    return proposal;
  }

  final int version;
  final String transitionId;
  final Uint8List _sourceGroup;
  final String successorRoomId;
  final Uint8List _coordinatorEndpointId;
  final List<cl.ECCompressedPublicKey> successorParticipants;
  final List<GroupTransitionKeyPlan> keyPlans;
  final GroupTransitionMigrationPolicy migrationPolicy;
  final DateTime createdAt;
  final DateTime expiresAt;

  GroupConfig get sourceGroup => GroupConfig.fromBytes(_sourceGroup);
  Uint8List get sourceGroupFingerprint => cl.sha256Hash(_sourceGroup);
  Uint8List get coordinatorEndpointId =>
      Uint8List.fromList(_coordinatorEndpointId);
  Uint8List get proposalHash => Uint8List.fromList(sigHash);

  List<cl.ECCompressedPublicKey> get retainedParticipants {
    final oldKeys = {
      for (final key in sourceGroup.participants.values) key.hex,
    };
    return List.unmodifiable(
      successorParticipants.where((key) => oldKeys.contains(key.hex)),
    );
  }

  List<cl.ECCompressedPublicKey> get addedParticipants {
    final oldKeys = {
      for (final key in sourceGroup.participants.values) key.hex,
    };
    return List.unmodifiable(
      successorParticipants.where((key) => !oldKeys.contains(key.hex)),
    );
  }

  List<cl.ECCompressedPublicKey> get removedParticipants {
    final newKeys = {for (final key in successorParticipants) key.hex};
    return List.unmodifiable(
      sourceGroup.participants.values.where(
        (key) => !newKeys.contains(key.hex),
      ),
    );
  }

  bool recognizesParticipant(cl.ECCompressedPublicKey key) =>
      sourceGroup.participants.values.any((candidate) => candidate == key) ||
      successorParticipants.any((candidate) => candidate == key);

  bool isExpiredAt(DateTime time) => !expiresAt.isAfter(time);

  @override
  Uint8List get uncachedSigHash => cl.sha256Hash(toBytes());

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString(noosphereGroupTransitionProposalDomain)
      ..writeUInt16(version)
      ..writeString(transitionId)
      ..writeVarSlice(_sourceGroup)
      ..writeString(successorRoomId)
      ..writeSlice(_coordinatorEndpointId)
      ..writeUInt16(successorParticipants.length);
    for (final participant in successorParticipants) {
      writer.writePubKey(participant);
    }
    writer.writeUInt16(keyPlans.length);
    for (final plan in keyPlans) {
      plan.write(writer);
    }
    migrationPolicy.write(writer);
    writer
      ..writeTime(createdAt)
      ..writeTime(expiresAt);
  }
}

void _checkVersion(int version) {
  if (version != noosphereGroupTransitionProposalVersion) {
    throw UnsupportedGroupTransitionVersion(version);
  }
}

void _checkId(String value, String name) {
  final length = utf8.encode(value).length;
  if (length < 1 || length > 255) {
    throw ArgumentError.value(value, name, 'must be 1..255 UTF-8 bytes');
  }
}

Uint8List _copy32(Uint8List bytes, String name) {
  if (bytes.length != 32) {
    throw ArgumentError.value(bytes.length, name, 'must contain 32 bytes');
  }
  return Uint8List.fromList(bytes);
}

cl.ECCompressedPublicKey _copyPublicKey(cl.ECCompressedPublicKey key) =>
    cl.ECCompressedPublicKey(Uint8List.fromList(key.data));

void _requireUniquePublicKeys(
  List<cl.ECCompressedPublicKey> keys,
  String name,
) {
  final seen = <String>{};
  for (final key in keys) {
    if (!seen.add(key.hex)) {
      throw ArgumentError.value(key.hex, name, 'contains a duplicate key');
    }
  }
}

int _compareBytes(Uint8List a, Uint8List b) {
  for (var index = 0; index < a.length && index < b.length; index++) {
    final result = a[index].compareTo(b[index]);
    if (result != 0) return result;
  }
  return a.length.compareTo(b.length);
}

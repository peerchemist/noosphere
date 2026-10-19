import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/api/types/signed_dkg_ack.dart';
import 'package:noosphere_protocol/common/serial.dart';
import 'package:frosty/frosty.dart';

import 'key_construction.dart';

class FrostKeyWithDetails with cl.Writable {
  static final _formatPrefix = Uint8List.fromList([0, 0x4e, 0x53, 0x4b, 1]);

  final ParticipantKeyInfo keyInfo;
  final String name;
  final String description;
  final Set<SignedDkgAck> acks;

  /// Public transcript context of the ceremony that created this key.
  final Uint8List ceremonyId;
  final Uint8List transcriptHash;

  /// A map of participant identifiers that are having the secret shared to.
  /// This maps to the last time the secret was shared. If a participant's
  /// identifier is not in this map, then the secret is not being shared with
  /// them.
  final Map<Identifier, DateTime> secretShareTimes;

  /// Identifiers of participants that have claimed to have constructed the
  /// underlying private key
  final Set<Identifier> claimedToHave;

  /// Information for constructing the underlying private key from shared
  /// secrets.
  final KeyConstruction keyConstruction;

  FrostKeyWithDetails._({
    required this.keyInfo,
    required this.name,
    required this.description,
    required Set<SignedDkgAck> acks,
    required Uint8List ceremonyId,
    required Uint8List transcriptHash,
    required Map<Identifier, DateTime> secretShareTimes,
    required Set<Identifier> claimedToHave,
    required this.keyConstruction,
  }) : acks = Set.unmodifiable(acks),
       ceremonyId = Uint8List.fromList(ceremonyId).asUnmodifiableView(),
       transcriptHash = Uint8List.fromList(transcriptHash).asUnmodifiableView(),
       secretShareTimes = Map.unmodifiable(secretShareTimes),
       claimedToHave = Set.unmodifiable(claimedToHave) {
    if (ceremonyId.length != 32 || transcriptHash.length != 32) {
      throw ArgumentError('ceremony context must contain 32-byte values');
    }
  }

  FrostKeyWithDetails({
    required ParticipantKeyInfo keyInfo,
    required String name,
    required String description,
    required Uint8List ceremonyId,
    required Uint8List transcriptHash,
  }) : this._(
         keyInfo: keyInfo,
         name: name,
         description: description,
         acks: {},
         ceremonyId: ceremonyId,
         transcriptHash: transcriptHash,
         secretShareTimes: {},
         claimedToHave: {},
         keyConstruction: KeyConstructionProgress(),
       );

  factory FrostKeyWithDetails.fromReader(cl.BytesReader reader) {
    // Historical records began directly with the compressed group public key.
    // Its 02/03 prefix cannot collide with the versioned format's 00 prefix.
    final first = reader.bytes.getUint8(reader.offset);
    final legacy = first == 2 || first == 3;
    if (!legacy &&
        !cl.bytesEqual(reader.readSlice(_formatPrefix.length), _formatPrefix)) {
      throw const FormatException('Malformed FrostKeyWithDetails');
    }
    final keyInfo = ParticipantKeyInfo.fromReader(reader);
    final name = reader.readString();
    final description = reader.readString();
    final Set<SignedDkgAck> acks;
    if (legacy) {
      // The compact historical encoding omitted signed ceremony context.
      // Never attach invented context to those signatures. Discard only this
      // reconstructible ACK cache; login re-attests possession with a new ACK.
      final count = reader.readUInt16();
      for (var i = 0; i < count; i++) {
        reader.readIdentifier();
        reader.readBool();
        reader.readSignature();
      }
      acks = {};
    } else {
      acks = reader.readWritableVector(SignedDkgAck.fromBytes).toSet();
    }
    final ceremonyId = legacy
        ? _legacyCeremonyId(keyInfo.groupKey)
        : reader.readSlice(32);
    final transcriptHash = legacy
        ? _legacyTranscriptHash(keyInfo.groupKey)
        : reader.readSlice(32);
    if (legacy && reader.atEnd) {
      return FrostKeyWithDetails(
        keyInfo: keyInfo,
        name: name,
        description: description,
        ceremonyId: ceremonyId,
        transcriptHash: transcriptHash,
      );
    }
    return FrostKeyWithDetails._(
      keyInfo: keyInfo,
      name: name,
      description: description,
      acks: acks,
      ceremonyId: ceremonyId,
      transcriptHash: transcriptHash,
      secretShareTimes: reader.readMap(
        () => reader.readIdentifier(),
        () => reader.readTime(),
      ),
      claimedToHave: reader.readIdentifierVector().toSet(),
      keyConstruction: reader.readBool()
          ? KeyConstructionProgress.fromReader(reader)
          : KeyConstructionComplete.fromReader(reader),
    );
  }

  // Legacy keys have no recoverable DKG transcript. These domain-separated,
  // key-bound values support possession exchange without identifying a new DKG.
  static Uint8List _legacyCeremonyId(cl.ECCompressedPublicKey key) =>
      cl.getTaggedHasher('NoosphereLegacyKeyPossession')(key.data);
  static Uint8List _legacyTranscriptHash(cl.ECCompressedPublicKey key) =>
      cl.getTaggedHasher('NoosphereLegacyKeyTranscript')(key.data);

  /// Whether this key predates stored ceremony metadata and uses a context
  /// for possession exchange only, never for resuming a new DKG.
  bool get hasLegacyDkgContext =>
      cl.bytesEqual(ceremonyId, _legacyCeremonyId(groupKey)) &&
      cl.bytesEqual(transcriptHash, _legacyTranscriptHash(groupKey));

  /// Convenience constructor to construct from serialised [bytes].
  factory FrostKeyWithDetails.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, FrostKeyWithDetails.fromReader);

  /// Convenience constructor to construct from encoded [hex].
  factory FrostKeyWithDetails.fromHex(String hex) =>
      FrostKeyWithDetails.fromBytes(cl.hexToBytes(hex));

  @override
  /// Equality applies to the group key only.
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FrostKeyWithDetails && groupKey == other.groupKey);

  @override
  int get hashCode => keyInfo.groupKey.hashCode;

  cl.ECCompressedPublicKey get groupKey => keyInfo.groupKey;

  @override
  void write(cl.Writer writer) {
    writer.writeSlice(_formatPrefix);
    keyInfo.write(writer);
    writer.writeString(name);
    writer.writeString(description);

    // Preserve the exact signed payload.
    writer.writeWritableVector(acks);

    writer
      ..writeSlice(ceremonyId)
      ..writeSlice(transcriptHash);

    writer.writeMap(
      secretShareTimes,
      (id) => writer.writeIdentifier(id),
      (time) => writer.writeTime(time),
    );

    writer.writeIdentifierVector(claimedToHave);

    writer.writeBool(keyConstruction is KeyConstructionProgress);
    keyConstruction.write(writer);
  }

  FrostKeyWithDetails _mutate({
    Set<SignedDkgAck>? acks,
    Map<Identifier, DateTime>? secretShareTimes,
    Set<Identifier>? claimedToHave,
    KeyConstruction? keyConstruction,
  }) => FrostKeyWithDetails._(
    keyInfo: keyInfo,
    name: name,
    description: description,
    acks: acks ?? this.acks,
    ceremonyId: ceremonyId,
    transcriptHash: transcriptHash,
    secretShareTimes: secretShareTimes ?? this.secretShareTimes,
    claimedToHave: claimedToHave ?? this.claimedToHave,
    keyConstruction: keyConstruction ?? this.keyConstruction,
  );

  FrostKeyWithDetails addOrReplaceAck(SignedDkgAck ack) => _mutate(
    acks: {
      ...acks.where(
        (other) =>
            other.signer != ack.signer ||
            other.signed.obj.groupKey != ack.signed.obj.groupKey ||
            !cl.bytesEqual(
              other.signed.obj.ceremonyId,
              ack.signed.obj.ceremonyId,
            ) ||
            !cl.bytesEqual(
              other.signed.obj.transcriptHash,
              ack.signed.obj.transcriptHash,
            ),
      ),
      ack,
    },
  );

  FrostKeyWithDetails addOrReplaceSecretShareTimes(
    Set<Identifier> participants,
    DateTime time,
  ) => _mutate(
    secretShareTimes: {
      ...secretShareTimes,
      for (final id in participants) id: time,
    },
  );

  FrostKeyWithDetails addClaimedToHave(Identifier participant) =>
      _mutate(claimedToHave: {...claimedToHave, participant});

  /// Will return null if the secret share is invalid
  FrostKeyWithDetails? addSecretShare(
    Identifier participant,
    cl.ECPrivateKey secret,
  ) {
    final construction = keyConstruction.addSecret(
      participant,
      secret,
      keyInfo,
    );
    return construction == null ? null : _mutate(keyConstruction: construction);
  }

  int get acceptedAcks => acks.where((ack) => ack.signed.obj.accepted).length;
}

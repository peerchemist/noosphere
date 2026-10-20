import 'dart:math';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/src/common/serial.dart';
import 'package:frosty/frosty.dart';

import 'expiry.dart';
import 'signed.dart';

/// Details of DKG requested by a participant. This is signed by the participant
/// and sent to the other participants.
class NewDkgDetails with cl.Writable, NoosphereWritable, Signable {
  static const int currentProtocolVersion = 4;
  static const int minNameLength = 3;
  static const int maxNameLength = 40;
  static const int maxDescLength = 1000;

  /// A unique name for the DKG between 3-40 characters
  final String name;

  /// A more in-depth description of the DKG up-to 1000 characters
  final String description;

  /// The threshold for the desired key
  final int threshold;

  /// The requested expiry of the DKG
  final Expiry expiry;

  /// Protocol context authenticated by the creator.
  final int protocolVersion;

  /// Fingerprint of the exact intended group roster and identity keys.
  final Uint8List groupFingerprint;

  /// Unique identity for this attempt, even when display fields are reused.
  final Uint8List attemptId;

  NewDkgDetails._({
    required this.name,
    required this.description,
    required this.threshold,
    required this.expiry,
    required this.protocolVersion,
    required Uint8List groupFingerprint,
    required Uint8List attemptId,
    bool allowNegativeExpiry = false,
  }) : groupFingerprint = Uint8List.fromList(groupFingerprint)
           .asUnmodifiableView(),
       attemptId = Uint8List.fromList(attemptId).asUnmodifiableView() {
    if (name.length < minNameLength || name.length > maxNameLength) {
      throw ArgumentError.value(name, "name");
    }
    if (description.length > maxDescLength) {
      throw ArgumentError.value(description, "description");
    }
    if (threshold < 2 || threshold > 0xffff) {
      throw ArgumentError.value(threshold, "threshold");
    }
    if (protocolVersion != currentProtocolVersion) {
      throw ArgumentError.value(
        protocolVersion,
        'protocolVersion',
        'unsupported DKG protocol version',
      );
    }
    if (groupFingerprint.length != 32) {
      throw ArgumentError.value(groupFingerprint, 'groupFingerprint');
    }
    if (attemptId.length != 32) {
      throw ArgumentError.value(attemptId, 'attemptId');
    }
    if (!allowNegativeExpiry) {
      expiry.requireNotExpired();
    }
  }

  /// The [name] must be unique and the [description] should explain what the
  /// key is to be used for. The name must be within 40 characters and the
  /// description must be within 1,000 characters.
  ///
  /// The [threshold] must not exceed the group participant count.
  ///
  /// The [expiry] is the maximum time after which the request will expire.
  /// The DKG must be completed by this time.
  NewDkgDetails({
    required String name,
    required String description,
    required int threshold,
    required Expiry expiry,
    required Uint8List groupFingerprint,
    Uint8List? attemptId,
    int protocolVersion = currentProtocolVersion,
  }) : this._(
         name: name,
         description: description,
         threshold: threshold,
         expiry: expiry,
         protocolVersion: protocolVersion,
         groupFingerprint: groupFingerprint,
         attemptId: attemptId ?? _newAttemptId(),
       );

  /// Should only be used in tests
  NewDkgDetails.allowNegativeExpiry({
    required String name,
    required String description,
    required int threshold,
    required Expiry expiry,
    required Uint8List groupFingerprint,
    Uint8List? attemptId,
    int protocolVersion = currentProtocolVersion,
  }) : this._(
         name: name,
         description: description,
         threshold: threshold,
         expiry: expiry,
         protocolVersion: protocolVersion,
         groupFingerprint: groupFingerprint,
         attemptId: attemptId ?? _newAttemptId(),
         allowNegativeExpiry: true,
       );

  NewDkgDetails.fromReader(cl.BytesReader reader)
    : this(
        protocolVersion: reader.readUInt16(),
        groupFingerprint: reader.readSlice(32),
        attemptId: reader.readSlice(32),
        name: reader.readString(),
        description: reader.readString(),
        threshold: reader.readUInt16(),
        expiry: Expiry.fromReader(reader),
      );

  /// Convenience constructor to construct from serialised [bytes].
  factory NewDkgDetails.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, NewDkgDetails.fromReader);

  /// Decodes current-format persisted details without requiring a live expiry.
  ///
  /// Callers must still reject expired details before starting or approving a
  /// DKG. This constructor is intended for audit records and recovery state.
  factory NewDkgDetails.fromBytesAllowExpired(Uint8List bytes) =>
      readNoosphere(bytes, NewDkgDetails.fromReaderAllowExpired);

  NewDkgDetails.fromReaderAllowExpired(cl.BytesReader reader)
    : this._fromReader(reader, allowNegativeExpiry: true);

  NewDkgDetails._fromReader(
    cl.BytesReader reader, {
    required bool allowNegativeExpiry,
  }) : this._(
         protocolVersion: reader.readUInt16(),
         groupFingerprint: reader.readSlice(32),
         attemptId: reader.readSlice(32),
         name: reader.readString(),
         description: reader.readString(),
         threshold: reader.readUInt16(),
         expiry: Expiry.fromReader(reader),
         allowNegativeExpiry: allowNegativeExpiry,
       );

  static final _hasher = cl.getTaggedHasher("NoosphereNewDkgDetailsV4");
  static final _transcriptHasher = cl.getTaggedHasher(
    "NoosphereDkgTranscriptV4",
  );

  @override
  Uint8List get uncachedSigHash => _hasher(toBytes());

  /// Stable identifier for this exact signed proposal payload.
  ///
  /// A changed name, threshold, description, or deadline produces a different
  /// ceremony. The creator signature authenticates these bytes.
  Uint8List get ceremonyId => sigHash;

  @override
  void write(cl.Writer writer) {
    writer.writeUInt16(protocolVersion);
    writer.writeSlice(groupFingerprint);
    writer.writeSlice(attemptId);
    writer.writeString(name);
    writer.writeString(description);
    writer.writeUInt16(threshold);
    expiry.write(writer);
  }

  /// Hash of DKG details and commiments that participants verify is equal for
  /// every other participant for round 2.
  ///
  Uint8List hashWithCommitments(DkgCommitmentSet commitments) =>
      _transcriptHasher(
        Uint8List.fromList([...ceremonyId, ...commitments.hash]),
      );
}

Uint8List _newAttemptId() {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
}

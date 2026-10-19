import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/src/common/errors.dart';
import 'package:noosphere_protocol/src/common/serial.dart';
import 'package:frosty/frosty.dart';

/// Request for ACKs for all participant [ids] for a single key given by the
/// [groupPublicKey] and ceremony transcript context.
class DkgAckRequest with cl.Writable, NoosphereWritable {
  final Set<Identifier> ids;
  final cl.ECCompressedPublicKey groupPublicKey;
  final Uint8List ceremonyId;
  final Uint8List transcriptHash;

  DkgAckRequest({
    required Set<Identifier> ids,
    required this.groupPublicKey,
    required Uint8List ceremonyId,
    required Uint8List transcriptHash,
  }) : ids = Set.unmodifiable(ids),
       ceremonyId = Uint8List.fromList(ceremonyId).asUnmodifiableView(),
       transcriptHash = Uint8List.fromList(transcriptHash)
           .asUnmodifiableView() {
    checkNotEmpty(ids, "ids");
    if (ceremonyId.length != 32) {
      throw ArgumentError.value(ceremonyId, 'ceremonyId', 'not 32 bytes');
    }
    if (transcriptHash.length != 32) {
      throw ArgumentError.value(
        transcriptHash,
        'transcriptHash',
        'not 32 bytes',
      );
    }
  }
  DkgAckRequest.fromReader(cl.BytesReader reader)
    : this(
        ids: reader.readIdentifierVector().toSet(),
        groupPublicKey: reader.readPubKey(),
        ceremonyId: reader.readSlice(32),
        transcriptHash: reader.readSlice(32),
      );
  factory DkgAckRequest.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, DkgAckRequest.fromReader);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DkgAckRequest &&
          groupPublicKey == other.groupPublicKey &&
          cl.bytesEqual(ceremonyId, other.ceremonyId) &&
          cl.bytesEqual(transcriptHash, other.transcriptHash));

  @override
  int get hashCode => Object.hash(
    groupPublicKey,
    Object.hashAll(ceremonyId),
    Object.hashAll(transcriptHash),
  );

  @override
  void write(cl.Writer writer) {
    writer.writeIdentifierVector(ids);
    writer.writePubKey(groupPublicKey);
    writer.writeSlice(ceremonyId);
    writer.writeSlice(transcriptHash);
  }
}

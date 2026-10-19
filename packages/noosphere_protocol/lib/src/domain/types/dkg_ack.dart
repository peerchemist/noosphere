import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/src/common/serial.dart';

import 'signed.dart';

/// A participant acknowledges that they have details for the [groupKey] if
/// [accepted] is true.
///
/// If [accepted] is false, they claim to not have the key and the receiver
/// should no longer ask for an acknowledgement. However, a participant and
/// server can lie, so the receiver should keep key data in case the key is used
/// by other participants.
///
/// A participant should not initiate use of a key until it has received
/// unanimous accepted acknowledgements. They can provide signature shares as
/// appropriate if other participants have used the key.
class DkgAck with cl.Writable, NoosphereWritable, Signable {
  static final _hasher = cl.getTaggedHasher("DkgAck");
  final cl.ECCompressedPublicKey groupKey;
  final bool accepted;
  final Uint8List? ceremonyId;
  final Uint8List? transcriptHash;
  final bool _legacyEncoding;

  DkgAck({
    required this.groupKey,
    required this.accepted,
    Uint8List? ceremonyId,
    Uint8List? transcriptHash,
    this._legacyEncoding = false,
  }) : ceremonyId = ceremonyId == null
           ? null
           : Uint8List.fromList(ceremonyId).asUnmodifiableView(),
       transcriptHash = transcriptHash == null
           ? null
           : Uint8List.fromList(transcriptHash).asUnmodifiableView() {
    if ((ceremonyId == null) != (transcriptHash == null)) {
      throw ArgumentError(
        'ceremonyId and transcriptHash must either both be present or absent',
      );
    }
    for (final (name, value) in [
      ('ceremonyId', ceremonyId),
      ('transcriptHash', transcriptHash),
    ]) {
      if (value != null && value.length != 32) {
        throw ArgumentError.value(value, name, 'not 32 bytes');
      }
    }
  }
  factory DkgAck.fromReader(cl.BytesReader reader) {
    final groupKey = reader.readPubKey();
    final accepted = reader.readBool();
    // Legacy acknowledgements are embedded in Signed<DkgAck>, so exactly the
    // 64-byte signature remains after the historical two fields.
    if (reader.bytes.lengthInBytes - reader.offset == 64) {
      return DkgAck(
        groupKey: groupKey,
        accepted: accepted,
        legacyEncoding: true,
      );
    }
    final hasContext = reader.readBool();
    return DkgAck(
      groupKey: groupKey,
      accepted: accepted,
      ceremonyId: hasContext ? reader.readSlice(32) : null,
      transcriptHash: hasContext ? reader.readSlice(32) : null,
    );
  }

  @override
  Uint8List get uncachedSigHash => _hasher(toBytes());

  @override
  void write(cl.Writer writer) {
    writer.writePubKey(groupKey);
    writer.writeBool(accepted);
    if (_legacyEncoding) return;
    writer.writeBool(ceremonyId != null);
    if (ceremonyId != null) {
      writer
        ..writeSlice(ceremonyId!)
        ..writeSlice(transcriptHash!);
    }
  }
}

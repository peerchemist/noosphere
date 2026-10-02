import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:collection/collection.dart';
import 'package:noosphere/common/serial.dart';

import 'signed_message_payload.dart';
import 'signatures_request_details.dart';
import 'single_signature_details.dart';

part 'metadata/empty.dart';
part 'metadata/message.dart';
part 'metadata/taproot.dart';
part 'metadata/unknown.dart';

/// Thrown when the metadata is invalid. Other specific exceptions may be thrown
/// for invalid metadata.
class InvalidMetaData implements Exception {
  final String message;
  InvalidMetaData(this.message);
  @override
  String toString() => "InvalidMetaData: $message";
}

// One registry defines every supported embedded codec. Unknown data is only
// accepted by the explicitly bounded standalone decoder below.
final _metadataReaders = <int, SignatureMetadata Function(cl.BytesReader)>{
  0: (_) => EmptySignatureMetadata(),
  1: TaprootTransactionSignatureMetadata._fromReader,
  2: MessageSignatureMetadata.fromReader,
};

abstract interface class SignatureMetadata with cl.Writable, NoosphereWritable {
  int get type;

  /// May throw an exception other than [cl.OutOfData] if the data is invalid
  static SignatureMetadata fromReader(cl.BytesReader reader) {
    final decode = _metadataReaders[reader.readUInt8()];
    if (decode == null) {
      throw const FormatException('unsupported embedded signature metadata');
    }
    return decode(reader);
  }

  /// Convenience constructor to construct from serialised [bytes].
  /// May throw an exception other than [cl.OutOfData] if the data is invalid
  static SignatureMetadata fromBytes(Uint8List bytes) {
    final reader = NoosphereBytesReader(bytes);
    final type = reader.readUInt8();
    if (!_metadataReaders.containsKey(type)) {
      return UnknownSignatureMetadata(
        type,
        reader.readSlice(reader.bytes.lengthInBytes - reader.offset),
      );
    }
    return readNoosphere(bytes, SignatureMetadata.fromReader);
  }

  /// Convenience constructor to construct from encoded [hex].
  /// May throw an exception other than [cl.OutOfData] if the data is invalid
  static SignatureMetadata fromHex(String hex) =>
      SignatureMetadata.fromBytes(cl.hexToBytes(hex));

  bool verifyRequiredSigs(List<SingleSignatureDetails> requiredSigs);
}

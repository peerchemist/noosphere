import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;

/// The canonical, versioned text payload used for Noosphere message signing.
class SignedMessagePayload with cl.Writable {
  static const int currentVersion = 1;
  static const int maxTextBytes = 16 * 1024;
  static const String version1Tag = 'Noosphere/SignedMessage/v1';

  static final _version1Hasher = cl.getTaggedHasher(version1Tag);

  final int version;
  final String text;
  final Uint8List _textBytes;
  final Uint8List _digest;

  SignedMessagePayload._({
    required this.version,
    required this.text,
    required Uint8List textBytes,
  }) : _textBytes = Uint8List.fromList(textBytes),
       _digest = _digestFor(version, textBytes);

  factory SignedMessagePayload({
    required String text,
    int version = currentVersion,
  }) {
    _requireSupportedVersion(version);
    final textBytes = _encodeText(text);
    return SignedMessagePayload._(
      version: version,
      text: text,
      textBytes: textBytes,
    );
  }

  factory SignedMessagePayload.fromReader(cl.BytesReader reader) {
    final version = reader.readUInt8();
    if (version != currentVersion) {
      throw FormatException('unsupported signed-message version: $version');
    }

    final declaredLength = reader.readVarInt();
    if (declaredLength > BigInt.from(maxTextBytes)) {
      throw FormatException('signed message exceeds $maxTextBytes UTF-8 bytes');
    }

    final textBytes = reader.readSlice(declaredLength.toInt());
    final text = utf8.decode(textBytes, allowMalformed: false);
    return SignedMessagePayload._(
      version: version,
      text: text,
      textBytes: textBytes,
    );
  }

  factory SignedMessagePayload.fromBytes(Uint8List bytes) {
    final reader = cl.BytesReader(bytes);
    final payload = SignedMessagePayload.fromReader(reader);
    if (!reader.atEnd) {
      throw const FormatException('trailing signed-message payload bytes');
    }
    return payload;
  }

  factory SignedMessagePayload.fromHex(String hex) =>
      SignedMessagePayload.fromBytes(cl.hexToBytes(hex));

  /// Alias that makes the distinction from the ROAST version explicit.
  int get formatVersion => version;

  /// BIP-340 input digest. A copy is returned to preserve immutability.
  Uint8List get digest => Uint8List.fromList(_digest);

  @override
  Uint8List toBytes() => Uint8List.fromList(super.toBytes());

  @override
  void write(cl.Writer writer) {
    writer.writeUInt8(version);
    writer.writeVarSlice(_textBytes);
  }

  static Uint8List _digestFor(int version, Uint8List textBytes) =>
      switch (version) {
        currentVersion => _version1Hasher(textBytes),
        _ => throw ArgumentError.value(
          version,
          'version',
          'unsupported signed-message version',
        ),
      };

  static void _requireSupportedVersion(int version) {
    if (version != currentVersion) {
      throw ArgumentError.value(
        version,
        'version',
        'unsupported signed-message version',
      );
    }
  }

  static Uint8List _encodeText(String text) {
    // Dart's UTF-8 encoder replaces unpaired surrogates. Reject them first so
    // the signed text always has one exact, portable UTF-8 representation.
    final codeUnits = text.codeUnits;
    for (var i = 0; i < codeUnits.length; i++) {
      final unit = codeUnits[i];
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++i >= codeUnits.length ||
            codeUnits[i] < 0xdc00 ||
            codeUnits[i] > 0xdfff) {
          throw const FormatException('text contains malformed Unicode');
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        throw const FormatException('text contains malformed Unicode');
      }
    }

    final bytes = Uint8List.fromList(utf8.encode(text));
    if (bytes.length > maxTextBytes) {
      throw ArgumentError.value(
        text,
        'text',
        'exceeds $maxTextBytes UTF-8 bytes',
      );
    }
    return bytes;
  }
}

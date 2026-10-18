import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';

/// Prevents callers from modifying coinlib's cached serialization.
mixin NoosphereWritable on cl.Writable {
  int? _noosphereSize;

  @override
  int get size {
    if (_noosphereSize case final size?) return size;
    final writer = _NoosphereMeasureWriter();
    write(writer);
    return _noosphereSize = writer.size;
  }

  @override
  Uint8List toBytes() => super.toBytes().asUnmodifiableView();
}

int _varIntSize(BigInt value) => value < BigInt.from(0xfd)
    ? 1
    : value <= BigInt.from(0xffff)
    ? 3
    : value <= BigInt.from(0xffffffff)
    ? 5
    : 9;

// coinlib 6.0.1 overestimates the encodings of 0xffff and 0xffffffff.
final class _NoosphereMeasureWriter extends cl.MeasureWriter {
  @override
  void writeVarInt(BigInt value) => size += _varIntSize(value);
}

/// Owns the exact input slice and rejects non-canonical or unbounded lengths.
/// coinlib 6.0.1's reader otherwise uses the entire backing buffer of a view.
class NoosphereBytesReader extends cl.BytesReader {
  NoosphereBytesReader(Uint8List bytes) : super(Uint8List.fromList(bytes));

  @override
  BigInt readVarInt() {
    final start = offset;
    final value = super.readVarInt();
    if (offset - start != _varIntSize(value)) {
      throw const FormatException('non-canonical variable-length integer');
    }
    return value;
  }

  @override
  Uint8List readVarSlice() {
    final length = readVarInt();
    if (length > BigInt.from(bytes.lengthInBytes - offset)) {
      throw const FormatException('byte string exceeds remaining input');
    }
    return readSlice(length.toInt());
  }

  @override
  List<Uint8List> readVector() {
    final count = readVarInt();
    // Each element needs at least one byte for its length, even when empty.
    if (count > BigInt.from(bytes.lengthInBytes - offset)) {
      throw const FormatException('vector exceeds remaining input');
    }
    return List.generate(count.toInt(), (_) => readVarSlice());
  }
}

/// Decodes a complete domain value; embedded values use their fromReader API.
T readNoosphere<T>(Uint8List bytes, T Function(cl.BytesReader) read) {
  final reader = NoosphereBytesReader(bytes);
  final value = read(reader);
  if (!reader.atEnd) throw const FormatException('trailing domain data');
  return value;
}

extension NoosphereWriter on cl.Writer {
  void _writeFuncVector<T>(Iterable<T> obj, void Function(T) writeFunc) {
    final li = obj.toList();
    writeUInt16(li.length);
    for (final el in li) {
      writeFunc(el);
    }
  }

  void writeString(String str) => writeVarSlice(utf8.encoder.convert(str));
  void writeBool(bool b) => writeUInt8(b ? 1 : 0);
  void writeDuration(Duration duration) =>
      writeUInt64(BigInt.from(duration.inMicroseconds));
  void writeIdentifier(Identifier id) => writeSlice(id.toBytes());
  void writeIdentifierVector(Iterable<Identifier> ids) =>
      _writeFuncVector(ids, (id) => writeIdentifier(id));
  void writeSignature(cl.SchnorrSignature sig) => writeSlice(sig.data);
  void writeSignatureVector(Iterable<cl.SchnorrSignature> sigs) =>
      _writeFuncVector(sigs, (sig) => writeSignature(sig));
  void writeWritableVector(Iterable<cl.Writable> li) =>
      writeVector(li.map((el) => el.toBytes()).toList());
  void writePubKey(cl.ECCompressedPublicKey key) => writeSlice(key.data);
  void writePrivKey(cl.ECPrivateKey key) => writeSlice(key.data);
  void writeTime(DateTime time) =>
      writeUInt64(BigInt.from(time.millisecondsSinceEpoch));

  void writeMap<K, V>(
    Map<K, V> map,
    void Function(K) writeKey,
    void Function(V) writeValue,
  ) {
    writeUInt16(map.length);
    for (final entry in map.entries) {
      writeKey(entry.key);
      writeValue(entry.value);
    }
  }
}

extension NoosphereReader on cl.BytesReader {
  String readString() => utf8.decoder.convert(readVarSlice());
  bool readBool() => switch (readUInt8()) {
    0 => false,
    1 => true,
    _ => throw const FormatException('invalid boolean'),
  };
  Duration readDuration() => Duration(microseconds: readUInt64().toInt());
  Identifier readIdentifier() => Identifier.fromBytes(readSlice(32));
  List<Identifier> readIdentifierVector() =>
      List.generate(readUInt16(), (_) => readIdentifier());
  cl.SchnorrSignature readSignature() => cl.SchnorrSignature(readSlice(64));
  List<cl.SchnorrSignature> readSignatureVector() =>
      List.generate(readUInt16(), (_) => readSignature());
  List<T> readWritableVector<T>(T Function(Uint8List) read) =>
      readVector().map(read).toList();
  cl.ECCompressedPublicKey readPubKey() =>
      cl.ECCompressedPublicKey(readSlice(33));
  cl.ECPrivateKey readPrivKey() => cl.ECPrivateKey(readSlice(32));
  DateTime readTime() =>
      DateTime.fromMillisecondsSinceEpoch(readUInt64().toInt());

  Map<K, V> readMap<K, V>(K Function() readKey, V Function() readValue) {
    final count = readUInt16();
    final result = <K, V>{};
    for (var i = 0; i < count; i++) {
      final key = readKey();
      if (result.containsKey(key)) {
        throw const FormatException('duplicate map key');
      }
      result[key] = readValue();
    }
    return result;
  }
}

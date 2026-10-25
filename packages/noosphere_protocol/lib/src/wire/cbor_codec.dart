import 'dart:collection';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';

const int _maximumNestingDepth = 16;
const int _maximumCollectionLength = 4096;
const int _maximumValueLength = 16 * 1024 * 1024;

/// Base type for every concrete Noosphere CBOR wire message.
abstract class WireMessage {
  const WireMessage();

  Map<int, Object?> get cborFields;

  Uint8List writeToBuffer() => encodeWireMap(cborFields);
}

Uint8List encodeWireMap(Map<int, Object?> fields) =>
    Uint8List.fromList(cborEncode(_toCborValue(fields)));

Map<int, Object?> decodeWireMap(
  List<int> bytes, {
  required Set<int> requiredFields,
  Set<int> optionalFields = const {},
}) {
  _DeterministicCborValidator(bytes).validate();
  // Retain CBOR types until each field is checked: toObject() represents both
  // byte strings and arrays as Dart lists.
  return readWireMap(
    cborDecode(bytes),
    requiredFields: requiredFields,
    optionalFields: optionalFields,
  );
}

Map<int, Object?> readWireMap(
  Object? value, {
  required Set<int> requiredFields,
  Set<int> optionalFields = const {},
}) {
  if (value is! CborMap) {
    throw const FormatException('CBOR message must be a map');
  }
  final allowed = {...requiredFields, ...optionalFields};
  final result = <int, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key.toObject();
    if (key is! int || key < 0) {
      throw const FormatException(
        'CBOR field keys must be nonnegative integers',
      );
    }
    if (!allowed.contains(key)) {
      throw FormatException('Unknown CBOR field $key');
    }
    result[key] = entry.value;
  }
  final missing = requiredFields.difference(result.keys.toSet());
  if (missing.isNotEmpty) {
    throw FormatException(
      'Missing required CBOR fields: ${missing.join(', ')}',
    );
  }
  return result;
}

List<int> readBytes(Map<int, Object?> map, int key) {
  final value = _readField<CborBytes>(map, key, 'a byte string');
  return List<int>.unmodifiable(value.bytes);
}

String readString(Map<int, Object?> map, int key) =>
    _readField<CborString>(map, key, 'text').toString();

int readInt(
  Map<int, Object?> map,
  int key, {
  int minimum = 0,
  int maximum = 0x7fffffffffffffff,
}) {
  final value = map[key];
  final integer = switch (value) {
    CborSmallInt() => value.value,
    CborInt() when value.toBigInt().isValidInt => value.toInt(),
    _ => null,
  };
  if (integer == null || integer < minimum || integer > maximum) {
    throw FormatException('CBOR field $key is outside its integer range');
  }
  return integer;
}

bool readBool(Map<int, Object?> map, int key) =>
    _readField<CborBool>(map, key, 'boolean').value;

List<Object?> readList(Map<int, Object?> map, int key) =>
    _readField<CborList>(map, key, 'an array');

T _readField<T>(Map<int, Object?> map, int key, String expected) =>
    switch (map[key]) {
      final T value => value,
      _ => throw FormatException('CBOR field $key must be $expected'),
    };

List<T> readListOf<T>(
  Map<int, Object?> map,
  int key,
  T Function(Object?) decode,
) => List.unmodifiable(readList(map, key).map(decode));

List<List<int>> readBytesList(Map<int, Object?> map, int key) =>
    List.unmodifiable(
      readList(map, key).map((value) {
        if (value is! CborBytes) {
          throw FormatException('CBOR field $key must contain byte strings');
        }
        return List<int>.unmodifiable(value.bytes);
      }),
    );

CborValue _toCborValue(Object? value) => switch (value) {
  int() => CborInt(BigInt.from(value)),
  bool() => CborBool(value),
  String() => CborString(value),
  Uint8List() => CborBytes(value),
  List<int>() => CborBytes(value),
  WireMessage() => _toCborValue(value.cborFields),
  Map<int, Object?>() => CborMap.fromEntries(
    (SplayTreeMap<int, Object?>()..addAll(value)).entries.map(
      (entry) => MapEntry(CborSmallInt(entry.key), _toCborValue(entry.value)),
    ),
    type: CborLengthType.definite,
  ),
  List<Object?>() => CborList(
    value.map(_toCborValue).toList(growable: false),
    type: CborLengthType.definite,
  ),
  _ => throw ArgumentError.value(value, 'value', 'unsupported CBOR value'),
};

/// Validates the restricted deterministic profile before the package decoder
/// can normalize maps. This catches duplicate/out-of-order keys, nonminimal
/// lengths and integers, indefinite items, tags, floats, null, and trailing
/// bytes while bounding nesting and collection sizes.
final class _DeterministicCborValidator(final List<int> _bytes) {
  int _offset = 0;

  void validate() {
    _readItem(0);
    if (_offset != _bytes.length) {
      throw const FormatException('Trailing bytes after CBOR message');
    }
  }

  void _readItem(int depth) {
    if (depth > _maximumNestingDepth) {
      throw const FormatException('CBOR nesting limit exceeded');
    }
    final initial = _readByte();
    final major = initial >> 5;
    final additional = initial & 0x1f;
    if (additional >= 28) {
      throw const FormatException('Indefinite or reserved CBOR item');
    }
    final argument = _readArgument(additional);
    switch (major) {
      case 0:
      case 1:
        break;
      case 2:
      case 3:
        final length = _bounded(argument, _maximumValueLength, 'value length');
        _take(length);
      case 4:
        final length = _bounded(
          argument,
          _maximumCollectionLength,
          'collection',
        );
        for (var i = 0; i < length; i++) {
          _readItem(depth + 1);
        }
      case 5:
        final length = _bounded(
          argument,
          _maximumCollectionLength,
          'collection',
        );
        BigInt? previous;
        for (var i = 0; i < length; i++) {
          final key = _readMapKey(depth + 1);
          if (previous != null && key <= previous) {
            throw const FormatException(
              'Duplicate or incorrectly ordered CBOR map key',
            );
          }
          previous = key;
          _readItem(depth + 1);
        }
      case 6:
        throw const FormatException('CBOR tags are not supported');
      case 7:
        if (additional != 20 && additional != 21) {
          throw const FormatException(
            'Unsupported CBOR simple or floating-point value',
          );
        }
      default:
        throw const FormatException('Unsupported CBOR major type');
    }
  }

  BigInt _readMapKey(int depth) {
    if (depth > _maximumNestingDepth) {
      throw const FormatException('CBOR nesting limit exceeded');
    }
    final initial = _readByte();
    if (initial >> 5 != 0) {
      throw const FormatException('CBOR field keys must be unsigned integers');
    }
    final additional = initial & 0x1f;
    if (additional >= 28) {
      throw const FormatException('Indefinite or reserved CBOR item');
    }
    return _readArgument(additional);
  }

  BigInt _readArgument(int additional) {
    if (additional < 24) return BigInt.from(additional);
    final count = switch (additional) {
      24 => 1,
      25 => 2,
      26 => 4,
      27 => 8,
      _ => 0,
    };
    var value = BigInt.zero;
    for (var i = 0; i < count; i++) {
      value = (value << 8) | BigInt.from(_readByte());
    }
    final minimum = switch (additional) {
      24 => BigInt.from(24),
      25 => BigInt.from(0x100),
      26 => BigInt.from(0x10000),
      27 => BigInt.from(0x100000000),
      _ => BigInt.zero,
    };
    if (value < minimum) {
      throw const FormatException('Nonminimal CBOR integer or length');
    }
    return value;
  }

  int _bounded(BigInt value, int maximum, String kind) {
    if (value > BigInt.from(maximum)) {
      throw FormatException('CBOR $kind limit exceeded');
    }
    return value.toInt();
  }

  int _readByte() {
    if (_offset >= _bytes.length) throw const FormatException('Truncated CBOR');
    return _bytes[_offset++];
  }

  void _take(int count) {
    if (_offset + count > _bytes.length) {
      throw const FormatException('Truncated CBOR');
    }
    _offset += count;
  }
}

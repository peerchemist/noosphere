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
  final value = cborDecode(bytes)
      .toObject(parseDateTime: false, decodeBase64: false, parseUri: false);
  return readWireMap(
    value,
    requiredFields: requiredFields,
    optionalFields: optionalFields,
  );
}

Map<int, Object?> readWireMap(
  Object? value, {
  required Set<int> requiredFields,
  Set<int> optionalFields = const {},
}) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('CBOR message must be a map');
  }
  final allowed = {...requiredFields, ...optionalFields};
  final result = <int, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
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
  final value = map[key];
  if (value is! List<Object?> || value.any((byte) => byte is! int)) {
    throw FormatException('CBOR field $key must be a byte string');
  }
  return List<int>.unmodifiable(value.cast<int>());
}

String readString(Map<int, Object?> map, int key) {
  final value = map[key];
  if (value is! String) throw FormatException('CBOR field $key must be text');
  return value;
}

int readInt(
  Map<int, Object?> map,
  int key, {
  int minimum = 0,
  int maximum = 0x7fffffffffffffff,
}) {
  final value = map[key];
  final integer = switch (value) {
    int() => value,
    BigInt() when value.isValidInt => value.toInt(),
    _ => null,
  };
  if (integer == null || integer < minimum || integer > maximum) {
    throw FormatException('CBOR field $key is outside its integer range');
  }
  return integer;
}

bool readBool(Map<int, Object?> map, int key) {
  final value = map[key];
  if (value is! bool) throw FormatException('CBOR field $key must be boolean');
  return value;
}

List<Object?> readList(Map<int, Object?> map, int key) {
  final value = map[key];
  if (value is! List<Object?>) {
    throw FormatException('CBOR field $key must be an array');
  }
  return value;
}

List<T> readListOf<T>(
  Map<int, Object?> map,
  int key,
  T Function(Object?) decode,
) => List.unmodifiable(readList(map, key).map(decode));

List<List<int>> readBytesList(Map<int, Object?> map, int key) =>
    List.unmodifiable(
      readList(map, key).map((value) {
        if (value is! List<Object?> || value.any((byte) => byte is! int)) {
          throw FormatException('CBOR field $key must contain byte strings');
        }
        return List<int>.unmodifiable(value.cast<int>());
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

  _Slice _readItem(int depth) {
    if (depth > _maximumNestingDepth) {
      throw const FormatException('CBOR nesting limit exceeded');
    }
    final start = _offset;
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
        final length = _boundedLength(argument);
        _take(length);
      case 4:
        final length = _boundedCollection(argument);
        for (var i = 0; i < length; i++) {
          _readItem(depth + 1);
        }
      case 5:
        final length = _boundedCollection(argument);
        _Slice? previous;
        for (var i = 0; i < length; i++) {
          final keyStart = _offset;
          final keyInitial = _peekByte();
          if (keyInitial >> 5 != 0) {
            throw const FormatException(
              'CBOR field keys must be unsigned integers',
            );
          }
          final key = _readItem(depth + 1);
          if (previous != null && _compareKeys(previous, key) >= 0) {
            throw const FormatException(
              'Duplicate or incorrectly ordered CBOR map key',
            );
          }
          previous = _Slice(keyStart, key.end);
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
    return _Slice(start, _offset);
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

  int _boundedLength(BigInt value) {
    if (value > BigInt.from(_maximumValueLength)) {
      throw const FormatException('CBOR value length limit exceeded');
    }
    return value.toInt();
  }

  int _boundedCollection(BigInt value) {
    if (value > BigInt.from(_maximumCollectionLength)) {
      throw const FormatException('CBOR collection limit exceeded');
    }
    return value.toInt();
  }

  int _compareKeys(_Slice first, _Slice second) {
    final firstLength = first.end - first.start;
    final secondLength = second.end - second.start;
    if (firstLength != secondLength) return firstLength.compareTo(secondLength);
    for (var i = 0; i < firstLength; i++) {
      final comparison = _bytes[first.start + i].compareTo(
        _bytes[second.start + i],
      );
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  int _peekByte() {
    if (_offset >= _bytes.length) throw const FormatException('Truncated CBOR');
    return _bytes[_offset];
  }

  int _readByte() {
    final value = _peekByte();
    _offset++;
    return value;
  }

  void _take(int count) {
    if (_offset + count > _bytes.length) {
      throw const FormatException('Truncated CBOR');
    }
    _offset += count;
  }
}

final class _Slice(final int start, final int end);

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

const int defaultMaxMessageLength = 1024 * 1024;
const int maximumQuicVarInt = 0x3fffffffffffffff;

sealed class FrameException implements Exception {
  const FrameException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class FrameTooLargeException extends FrameException {
  const FrameTooLargeException({required this.length, required this.maximum})
    : super('message length $length exceeds maximum $maximum');
  final int length;
  final int maximum;
}

final class TruncatedFrameException extends FrameException {
  const TruncatedFrameException(super.message);
}

/// Encodes [value] using the shortest RFC 9000 QUIC variable-length integer.
Uint8List encodeQuicVarInt(int value) {
  if (value < 0 || value > maximumQuicVarInt) {
    throw RangeError.range(value, 0, maximumQuicVarInt, 'value');
  }
  final length = switch (value) {
    < 0x40 => 1,
    < 0x4000 => 2,
    < 0x40000000 => 4,
    _ => 8,
  };
  final bytes = Uint8List(length);
  var remaining = value;
  for (var index = length - 1; index >= 0; index--) {
    bytes[index] = remaining & 0xff;
    remaining ~/= 256;
  }
  bytes[0] |= switch (length) {
    1 => 0x00,
    2 => 0x40,
    4 => 0x80,
    _ => 0xc0,
  };
  return bytes;
}

/// Prefixes one message for a stream that carries multiple protobuf messages.
Uint8List encodeLengthPrefixedMessage(
  List<int> message, {
  int maxMessageLength = defaultMaxMessageLength,
}) {
  _checkMaximum(maxMessageLength);
  if (message.length > maxMessageLength) {
    throw FrameTooLargeException(
      length: message.length,
      maximum: maxMessageLength,
    );
  }
  final length = encodeQuicVarInt(message.length);
  final framed = Uint8List(length.length + message.length);
  framed.setRange(0, length.length, length);
  framed.setRange(length.length, framed.length, message);
  return framed;
}

/// Decodes `[QUIC varint length][message]` records from a persistent stream.
Stream<Uint8List> decodeLengthPrefixedMessages(
  Stream<List<int>> source, {
  int maxMessageLength = defaultMaxMessageLength,
}) async* {
  final reader = QuicStreamReader(source);
  try {
    while (true) {
      final length = await reader.readVarIntOrNull();
      if (length == null) return;
      yield await reader.readExactly(length, maxLength: maxMessageLength);
    }
  } finally {
    await reader.cancel();
  }
}

/// Incremental reader shared by FIN-delimited RPC bodies and persistent streams.
final class QuicStreamReader {
  QuicStreamReader(Stream<List<int>> source)
    : _iterator = StreamIterator<List<int>>(source);

  final StreamIterator<List<int>> _iterator;
  List<int> _chunk = const [];
  int _offset = 0;
  bool _ended = false;

  Future<int> readVarInt() async {
    final value = await readVarIntOrNull();
    if (value == null) {
      throw const TruncatedFrameException(
        'stream ended before a QUIC varint was received',
      );
    }
    return value;
  }

  Future<int?> readVarIntOrNull() async {
    final first = await _readByte();
    if (first == null) return null;
    final length = 1 << (first >> 6);
    var value = first & 0x3f;
    for (var index = 1; index < length; index++) {
      final byte = await _readByte();
      if (byte == null) {
        throw TruncatedFrameException(
          'stream ended after $index of $length QUIC varint bytes',
        );
      }
      value = value * 256 + byte;
    }
    return value;
  }

  Future<Uint8List> readExactly(
    int length, {
    int maxLength = defaultMaxMessageLength,
  }) async {
    _checkLength(length, maxLength);
    final result = Uint8List(length);
    var written = 0;
    while (written < length) {
      if (!await _ensureData()) {
        throw TruncatedFrameException(
          'stream ended after $written of $length message bytes',
        );
      }
      final count = math.min(length - written, _chunk.length - _offset);
      result.setRange(written, written + count, _chunk, _offset);
      written += count;
      _offset += count;
    }
    return result;
  }

  /// Reads the rest of a single-message stream, using FIN as its boundary.
  Future<Uint8List> readToEnd({int maxLength = defaultMaxMessageLength}) async {
    _checkMaximum(maxLength);
    final builder = BytesBuilder(copy: false);
    var length = 0;
    while (await _ensureData()) {
      final available = _chunk.length - _offset;
      length += available;
      if (length > maxLength) {
        throw FrameTooLargeException(length: length, maximum: maxLength);
      }
      builder.add(_chunk.sublist(_offset));
      _offset = _chunk.length;
    }
    return builder.takeBytes();
  }

  Future<void> cancel() => _iterator.cancel();

  Future<int?> _readByte() async {
    if (!await _ensureData()) return null;
    return _chunk[_offset++];
  }

  Future<bool> _ensureData() async {
    while (_offset >= _chunk.length) {
      if (_ended) return false;
      if (!await _iterator.moveNext()) {
        _ended = true;
        return false;
      }
      _chunk = _iterator.current;
      _offset = 0;
    }
    return true;
  }
}

void _checkLength(int length, int maximum) {
  _checkMaximum(maximum);
  if (length < 0) throw RangeError.value(length, 'length');
  if (length > maximum) {
    throw FrameTooLargeException(length: length, maximum: maximum);
  }
}

void _checkMaximum(int maximum) {
  if (maximum < 1 || maximum > maximumQuicVarInt) {
    throw RangeError.range(maximum, 1, maximumQuicVarInt, 'maxMessageLength');
  }
}

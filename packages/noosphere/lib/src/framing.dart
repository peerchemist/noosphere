import 'dart:math' as math;
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import 'generated/noosphere.pb.dart';

const int defaultMaxEnvelopeLength = 1024 * 1024;

sealed class FrameException implements Exception {
  const FrameException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class FrameTooLargeException extends FrameException {
  const FrameTooLargeException({required this.length, required this.maximum})
    : super('frame length $length exceeds maximum $maximum');

  final int length;
  final int maximum;
}

final class TruncatedFrameException extends FrameException {
  const TruncatedFrameException(super.message);
}

final class InvalidEnvelopeException extends FrameException {
  const InvalidEnvelopeException(super.message, {this.cause});

  final Object? cause;
}

/// Serializes one envelope with a four-byte unsigned big-endian length prefix.
Uint8List encodeEnvelope(
  Envelope envelope, {
  int maxEnvelopeLength = defaultMaxEnvelopeLength,
}) {
  _checkMaximum(maxEnvelopeLength);
  _checkPayload(envelope);

  final body = envelope.writeToBuffer();
  if (body.length > maxEnvelopeLength) {
    throw FrameTooLargeException(
      length: body.length,
      maximum: maxEnvelopeLength,
    );
  }

  final framed = Uint8List(4 + body.length);
  ByteData.sublistView(framed, 0, 4).setUint32(0, body.length, Endian.big);
  framed.setRange(4, framed.length, body);
  return framed;
}

/// Lazily decodes length-prefixed envelopes from arbitrary input chunks.
///
/// A frame is emitted as soon as its body is complete. The decoder retains at
/// most one frame body in addition to the chunk currently supplied by [source].
Stream<Envelope> decodeEnvelopes(
  Stream<List<int>> source, {
  int maxEnvelopeLength = defaultMaxEnvelopeLength,
}) async* {
  _checkMaximum(maxEnvelopeLength);

  final header = Uint8List(4);
  var headerLength = 0;
  Uint8List? body;
  var bodyLength = 0;

  await for (final chunk in source) {
    var chunkOffset = 0;
    while (chunkOffset < chunk.length) {
      if (headerLength < header.length) {
        final count = math.min(
          header.length - headerLength,
          chunk.length - chunkOffset,
        );
        header.setRange(headerLength, headerLength + count, chunk, chunkOffset);
        headerLength += count;
        chunkOffset += count;

        if (headerLength < header.length) continue;

        final expectedLength = ByteData.sublistView(header)
            .getUint32(0, Endian.big);
        if (expectedLength > maxEnvelopeLength) {
          throw FrameTooLargeException(
            length: expectedLength,
            maximum: maxEnvelopeLength,
          );
        }
        body = Uint8List(expectedLength);
        bodyLength = 0;

        if (expectedLength == 0) {
          headerLength = 0;
          body = null;
          yield _decodeEnvelope(const <int>[]);
        }
      }

      final currentBody = body;
      if (currentBody == null) continue;

      final count = math.min(
        currentBody.length - bodyLength,
        chunk.length - chunkOffset,
      );
      currentBody.setRange(bodyLength, bodyLength + count, chunk, chunkOffset);
      bodyLength += count;
      chunkOffset += count;

      if (bodyLength == currentBody.length) {
        headerLength = 0;
        body = null;
        bodyLength = 0;
        yield _decodeEnvelope(currentBody);
      }
    }
  }

  if (headerLength != 0) {
    throw TruncatedFrameException(
      'stream ended after $headerLength of 4 header bytes',
    );
  }
  if (body != null) {
    throw TruncatedFrameException(
      'stream ended after $bodyLength of ${body.length} body bytes',
    );
  }
}

Envelope _decodeEnvelope(List<int> body) {
  final Envelope envelope;
  try {
    envelope = Envelope.fromBuffer(body);
  } on InvalidProtocolBufferException catch (error) {
    throw InvalidEnvelopeException(
      'frame body is not a valid Envelope protobuf',
      cause: error,
    );
  }
  _checkPayload(envelope);
  return envelope;
}

void _checkPayload(Envelope envelope) {
  if (envelope.whichPayload() == Envelope_Payload.notSet) {
    throw const InvalidEnvelopeException('envelope payload is not set');
  }
}

void _checkMaximum(int maximum) {
  if (maximum < 1 || maximum > 0xffffffff) {
    throw RangeError.range(maximum, 1, 0xffffffff, 'maxEnvelopeLength');
  }
}

import 'dart:async';

import 'package:noosphere/noosphere.dart';
import 'package:test/test.dart';

void main() {
  Envelope requestEnvelope(int id) => Envelope(
    wireVersion: 1,
    rpcRequest: RpcRequest(
      requestId: [id],
      extendSession: Bytes(data: [id + 1]),
    ),
  );

  group('encodeEnvelope', () {
    test('writes a four-byte big-endian length', () {
      final envelope = requestEnvelope(1);
      final encoded = encodeEnvelope(envelope);

      expect(encoded.sublist(0, 4), [0, 0, 0, encoded.length - 4]);
      expect(
        Envelope.fromBuffer(encoded.sublist(4)).writeToBuffer(),
        envelope.writeToBuffer(),
      );
    });

    test('rejects missing payload and oversized body', () {
      expect(
        () => encodeEnvelope(Envelope(wireVersion: 1)),
        throwsA(isA<InvalidEnvelopeException>()),
      );
      expect(
        () => encodeEnvelope(requestEnvelope(1), maxEnvelopeLength: 1),
        throwsA(isA<FrameTooLargeException>()),
      );
    });
  });

  group('decodeEnvelopes', () {
    test('reads a header and body split across chunks', () async {
      final encoded = encodeEnvelope(requestEnvelope(4));
      final chunks = <List<int>>[
        encoded.sublist(0, 1),
        encoded.sublist(1, 3),
        encoded.sublist(3, 6),
        encoded.sublist(6),
      ];

      final decoded = await decodeEnvelopes(Stream.fromIterable(chunks)).single;

      expect(decoded.rpcRequest.requestId, [4]);
      expect(decoded.rpcRequest.extendSession.data, [5]);
    });

    test('emits multiple frames from one chunk in order', () async {
      final first = encodeEnvelope(requestEnvelope(1));
      final second = encodeEnvelope(requestEnvelope(2));

      final decoded = await decodeEnvelopes(Stream.value([...first, ...second]))
          .toList();

      expect(decoded.map((envelope) => envelope.rpcRequest.requestId.single), [
        1,
        2,
      ]);
    });

    test('rejects truncated header and body', () async {
      await expectLater(
        decodeEnvelopes(Stream.value([0, 0])).toList(),
        throwsA(isA<TruncatedFrameException>()),
      );

      final encoded = encodeEnvelope(requestEnvelope(3));
      await expectLater(
        decodeEnvelopes(Stream.value(encoded.sublist(0, encoded.length - 1)))
            .toList(),
        throwsA(isA<TruncatedFrameException>()),
      );
    });

    test('rejects malformed protobuf and unset oneof', () async {
      await expectLater(
        decodeEnvelopes(Stream.value([0, 0, 0, 1, 255])).toList(),
        throwsA(isA<InvalidEnvelopeException>()),
      );
      await expectLater(
        decodeEnvelopes(Stream.value([0, 0, 0, 0])).toList(),
        throwsA(isA<InvalidEnvelopeException>()),
      );

      // Envelope wire_version = 1 and unknown length-delimited field 99.
      await expectLater(
        decodeEnvelopes(Stream.value([0, 0, 0, 5, 8, 1, 154, 6, 0])).toList(),
        throwsA(isA<InvalidEnvelopeException>()),
      );
    });

    test('rejects an oversized length before reading its body', () async {
      await expectLater(
        decodeEnvelopes(
          Stream.value([0, 0, 4, 0]),
          maxEnvelopeLength: 1023,
        ).toList(),
        throwsA(
          isA<FrameTooLargeException>()
              .having((error) => error.length, 'length', 1024)
              .having((error) => error.maximum, 'maximum', 1023),
        ),
      );
    });

    test('cancels the source after the consumer stops early', () async {
      var cancelled = false;
      late StreamController<List<int>> controller;
      controller = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final firstOnly = decodeEnvelopes(controller.stream).take(1).toList();
      controller.add([
        ...encodeEnvelope(requestEnvelope(1)),
        ...encodeEnvelope(requestEnvelope(2)),
      ]);

      final decoded = await firstOnly;
      await Future<void>.delayed(Duration.zero);

      expect(decoded.single.rpcRequest.requestId, [1]);
      expect(cancelled, isTrue);
      await controller.close();
    });
  });
}

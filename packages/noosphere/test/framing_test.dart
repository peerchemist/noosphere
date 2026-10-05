import 'dart:async';

import 'package:noosphere/wire.dart';
import 'package:test/test.dart';

void main() {
  group('QUIC varints', () {
    test('use the shortest RFC 9000 encoding', () {
      expect(encodeQuicVarInt(0), [0]);
      expect(encodeQuicVarInt(63), [63]);
      expect(encodeQuicVarInt(64), [0x40, 0x40]);
      expect(encodeQuicVarInt(16383), [0x7f, 0xff]);
      expect(encodeQuicVarInt(16384), [0x80, 0, 0x40, 0]);
      expect(encodeQuicVarInt(maximumQuicVarInt), [
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
      ]);
    });

    test('decode across arbitrary chunks', () async {
      final reader = QuicStreamReader(
        Stream.fromIterable([
          [0x80],
          [0, 0x40],
          [0],
        ]),
      );
      expect(await reader.readVarInt(), 16384);
      await reader.cancel();
    });

    test('rejects truncated values', () async {
      final reader = QuicStreamReader(Stream.value([0x40]));
      await expectLater(
        reader.readVarInt(),
        throwsA(isA<TruncatedFrameException>()),
      );
    });
  });

  group('persistent message framing', () {
    test('emits multiple messages split across chunks', () async {
      final first = encodeLengthPrefixedMessage([1, 2, 3]);
      final second = encodeLengthPrefixedMessage(List.filled(64, 4));
      final bytes = [...first, ...second];
      final decoded = await decodeLengthPrefixedMessages(
        Stream.fromIterable([
          bytes.sublist(0, 1),
          bytes.sublist(1, 5),
          bytes.sublist(5),
        ]),
      ).toList();

      expect(decoded, [
        [1, 2, 3],
        List.filled(64, 4),
      ]);
    });

    test('rejects truncated and oversized messages', () async {
      await expectLater(
        decodeLengthPrefixedMessages(Stream.value([3, 1, 2])).toList(),
        throwsA(isA<TruncatedFrameException>()),
      );
      await expectLater(
        decodeLengthPrefixedMessages(
          Stream.value([0x40, 0x40]),
          maxMessageLength: 63,
        ).toList(),
        throwsA(isA<FrameTooLargeException>()),
      );
    });

    test('cancels its source when a consumer stops early', () async {
      var cancelled = false;
      final controller = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final firstOnly = decodeLengthPrefixedMessages(controller.stream)
          .take(1)
          .toList();
      controller.add([
        ...encodeLengthPrefixedMessage([1]),
        ...encodeLengthPrefixedMessage([2]),
      ]);

      expect(await firstOnly, [
        [1],
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      await controller.close();
    });
  });

  test('readToEnd uses FIN as the single-message boundary', () async {
    final reader = QuicStreamReader(
      Stream.fromIterable([
        [1, 2],
        [3],
      ]),
    );
    expect(await reader.readToEnd(), [1, 2, 3]);

    final oversized = QuicStreamReader(Stream.value([1, 2]));
    await expectLater(
      oversized.readToEnd(maxLength: 1),
      throwsA(isA<FrameTooLargeException>()),
    );
  });
}

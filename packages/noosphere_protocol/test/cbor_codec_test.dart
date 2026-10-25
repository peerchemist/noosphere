import 'package:noosphere_protocol/src/wire/cbor_codec.dart' show decodeWireMap;
import 'package:noosphere_protocol/wire.dart';
import 'package:test/test.dart';

void main() {
  group('restricted deterministic CBOR decoder', () {
    test('rejects structural and deterministic-profile violations', () {
      final invalid = <String, List<int>>{
        'trailing bytes': [0xa1, 0x01, 0x40, 0x00],
        'duplicate keys': [0xa2, 0x01, 0x40, 0x01, 0x40],
        'out-of-order keys': [0xa2, 0x02, 0x40, 0x01, 0x40],
        'nonminimal key': [0xa1, 0x18, 0x01, 0x40],
        'nonminimal byte-string length': [0xa1, 0x01, 0x58, 0x00],
        'indefinite map': [0xbf, 0x01, 0x40, 0xff],
        'null': [0xa1, 0x01, 0xf6],
        'floating point': [0xa1, 0x01, 0xf9, 0x00, 0x00],
        'tag': [0xa1, 0x01, 0xc0, 0x40],
        'oversized collection': [0xa1, 0x01, 0x99, 0x10, 0x01],
        'oversized value': [0xa1, 0x01, 0x5a, 0x01, 0x00, 0x00, 0x01],
        'excessive nesting': [0xa1, 0x01, ...List<int>.filled(17, 0x81), 0x40],
      };
      for (final MapEntry(:key, :value) in invalid.entries) {
        expect(
          () => Bytes.fromBuffer(value),
          throwsFormatException,
          reason: key,
        );
      }
    });

    test('orders integer keys canonically across encoding widths', () {
      expect(
        decodeWireMap(
          [0xa2, 0x17, 0x40, 0x18, 0x18, 0x40],
          requiredFields: {23, 24},
        ).keys,
        orderedEquals([23, 24]),
      );
      expect(
        () => decodeWireMap(
          [0xa2, 0x18, 0x18, 0x40, 0x17, 0x40],
          requiredFields: {23, 24},
        ),
        throwsFormatException,
      );
    });

    test('rejects missing, unknown and incorrectly typed fields', () {
      expect(() => LoginRequest.fromBuffer([0xa0]), throwsFormatException);
      expect(
        () => LoginRequest.fromBuffer([
          0xa4,
          0x01,
          0x40,
          0x02,
          0x40,
          0x03,
          0x01,
          0x04,
          0x00,
        ]),
        throwsFormatException,
      );
      expect(
        () =>
            LoginRequest.fromBuffer([0xa3, 0x01, 0x40, 0x02, 0x40, 0x03, 0xf4]),
        throwsFormatException,
      );
    });

    test('rejects unknown enum values and variants', () {
      expect(
        () => ProtocolError.fromBuffer([
          0xa3,
          0x01,
          0x0b,
          0x02,
          0x60,
          0x03,
          0xf4,
        ]),
        throwsFormatException,
      );
      expect(
        () => EventMessage.fromBuffer([0xa2, 0x01, 0x11, 0x02, 0xa0]),
        throwsFormatException,
      );
    });

    test('rejects arrays in byte-string fields, including nested fields', () {
      final arrays = <String, List<int>>{
        'empty': [0x80],
        'valid byte': [0x81, 0x01],
        'negative integer': [0x81, 0x20],
        'integer above 255': [0x81, 0x19, 0x01, 0x00],
      };
      for (final MapEntry(:key, :value) in arrays.entries) {
        expect(
          () => Bytes.fromBuffer([0xa1, 0x01, ...value]),
          throwsFormatException,
          reason: key,
        );
        expect(
          () => RequestDkgAcksResponse.fromBuffer([0xa1, 0x01, 0x81, ...value]),
          throwsFormatException,
          reason: 'byte-string array element: $key',
        );
        expect(
          () => EventMessage.fromBuffer([
            0xa2,
            0x01,
            0x01,
            0x02,
            0xa2,
            0x01,
            ...value,
            0x02,
            0xf5,
          ]),
          throwsFormatException,
          reason: 'event payload: $key',
        );
      }
    });

    test('rejects byte strings in array fields', () {
      for (final value in <List<int>>[
        [0x40],
        [0x41, 0x01],
      ]) {
        expect(
          () => RequestDkgAcksResponse.fromBuffer([0xa1, 0x01, ...value]),
          throwsFormatException,
        );
        expect(
          () => ShareSecretShareResponse.fromBuffer([0xa1, 0x01, ...value]),
          throwsFormatException,
        );
      }
    });

    test('preserves valid byte strings and arrays exactly', () {
      for (final value in <List<int>>[
        [0x40],
        [0x42, 0x00, 0xff],
      ]) {
        final bytes = [0xa1, 0x01, ...value];
        expect(Bytes.fromBuffer(bytes).writeToBuffer(), bytes);
      }
      for (final value in <List<int>>[
        [0x80],
        [0x82, 0x40, 0x42, 0x00, 0xff],
      ]) {
        final bytes = [0xa1, 0x01, ...value];
        expect(RequestDkgAcksResponse.fromBuffer(bytes).writeToBuffer(), bytes);
      }
    });
  });

  test('encoding is independent of map insertion order', () {
    final first = _TestMessage({
      1: 1,
      2: [2],
    });
    final second = _TestMessage({
      2: [2],
      1: 1,
    });
    expect(first.writeToBuffer(), second.writeToBuffer());
    expect(first.writeToBuffer(), [0xa2, 0x01, 0x01, 0x02, 0x41, 0x02]);
  });

  test('signed 64-bit integer boundaries retain precision', () {
    final request = GetPublicFeedRequest(
      feedId: List<int>.filled(32, 0),
      afterCursor: 0x7fffffffffffffff,
      limit: 1,
    );
    expect(
      GetPublicFeedRequest.fromBuffer(request.writeToBuffer()).afterCursor,
      0x7fffffffffffffff,
    );
    final entry = PublicFeedEntry(
      cursor: 1,
      eventId: List<int>.filled(32, 0),
      observedAtMs: -0x8000000000000000,
    );
    final page = PublicFeedPage(
      schemaVersion: 1,
      feedId: List<int>.filled(32, 0),
      entries: [entry],
      oldestAvailableCursor: 1,
      latestCursor: 1,
      nextCursor: 1,
      generatedAtMs: -0x8000000000000000,
    );
    final decoded = PublicFeedPage.fromBuffer(page.writeToBuffer());
    expect(decoded.generatedAtMs, -0x8000000000000000);
    expect(decoded.entries.single.observedAtMs, -0x8000000000000000);
  });
}

final class _TestMessage(@override final Map<int, Object?> cborFields)
    extends WireMessage;

import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:test/test.dart';

void main() {
  group('SignedMessagePayload', () {
    const vectors = {
      '': '52286e2b590ab9908eb8d774b9a5c28e19bd9c80ebf223cc2fa135ee66b434b9',
      'Hello!':
          '1c25eb284f8082610da542f9c70cab1a67baaaf64ba760b197921d9d03ade851',
      'Di si?':
          'f56ddd5212d63b0475a519e9e2f164a192e7913dbbcf75dff97f13d43bd53636',
      'line 1\nline 2':
          'fd9e4d34d3039ca9925e8fda36b35237bb2be4638a66b871325be203a8580d6f',
      'line 1\r\nline 2':
          '4fb27450152323d496e7e83f1129658cd29077e888d36f73c62bd4801141b6ef',
    };

    test('matches independent digest vectors', () {
      for (final entry in vectors.entries) {
        expect(
          cl.bytesToHex(SignedMessagePayload(text: entry.key).digest),
          entry.value,
        );
      }
      expect(vectors['line 1\nline 2'], isNot(vectors['line 1\r\nline 2']));
    });

    test('round-trips the canonical encoding', () {
      final payload = SignedMessagePayload(text: 'Exact\r\ntext 🌍');
      final decoded = SignedMessagePayload.fromBytes(payload.toBytes());

      expect(decoded.version, 1);
      expect(decoded.text, payload.text);
      expect(decoded.digest, orderedEquals(payload.digest));
      expect(decoded.toBytes(), orderedEquals(payload.toBytes()));
    });

    test('accepts exact UTF-8 byte limits', () {
      expect(
        SignedMessagePayload(text: 'a' * SignedMessagePayload.maxTextBytes)
            .toBytes(),
        isNotEmpty,
      );
      expect(
        SignedMessagePayload(
          text: 'é' * (SignedMessagePayload.maxTextBytes ~/ 2),
        ).toBytes(),
        isNotEmpty,
      );
    });

    test('rejects text beyond the UTF-8 byte limit', () {
      expect(
        () => SignedMessagePayload(
          text: 'é' * (SignedMessagePayload.maxTextBytes ~/ 2 + 1),
        ),
        throwsArgumentError,
      );

      // version, 0xfd varint marker, 1025 little-endian; no body is needed
      // because the declared bound is rejected before trying to read it.
      expect(
        () => SignedMessagePayload.fromBytes(
          Uint8List.fromList([1, 0xfd, 0x01, 0x04]),
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed Unicode and UTF-8', () {
      expect(
        () => SignedMessagePayload(text: String.fromCharCode(0xd800)),
        throwsFormatException,
      );
      expect(
        () => SignedMessagePayload.fromBytes(
          Uint8List.fromList([1, 2, 0xc3, 0x28]),
        ),
        throwsFormatException,
      );
    });

    test(
      'rejects unsupported versions, malformed lengths, and trailing data',
      () {
        expect(
          () => SignedMessagePayload(text: '', version: 2),
          throwsArgumentError,
        );
        expect(
          () => SignedMessagePayload.fromBytes(Uint8List.fromList([2, 0])),
          throwsFormatException,
        );
        expect(
          () => SignedMessagePayload.fromBytes(Uint8List.fromList([1, 1])),
          throwsA(isA<cl.OutOfData>()),
        );
        expect(
          () => SignedMessagePayload.fromBytes(Uint8List.fromList([1, 0, 0])),
          throwsFormatException,
        );
      },
    );

    test('does not expose mutable digest state', () {
      final payload = SignedMessagePayload(text: 'immutable');
      final expected = payload.digest;
      final expectedBytes = payload.toBytes();
      payload.digest[0] ^= 0xff;
      payload.toBytes()[0] ^= 0xff;
      expect(payload.digest, orderedEquals(expected));
      expect(payload.toBytes(), orderedEquals(expectedBytes));
    });
  });
}

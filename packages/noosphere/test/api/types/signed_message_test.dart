import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:test/test.dart';

import '../../support/data.dart';

void main() {
  group('SignedMessage', () {
    late cl.ECPrivateKey key;
    late SignaturesRequestDetails details;
    late cl.SchnorrSignature signature;
    late SignedMessage signedMessage;

    setUpAll(loadFrosty);

    setUp(() {
      key = getPrivkey(0);
      details = SignaturesRequestDetails.forMessage(
        text: 'Hello from Noosphere 🌍',
        groupKey: cl.ECCompressedPublicKey.fromPubkey(key.pubkey),
        expiry: futureExpiry,
      );
      signature = cl.SchnorrSignature.sign(
        key,
        details.requiredSigs.single.signDetails.message,
      );
      signedMessage = SignedMessage.fromCompletedRequest(
        details: details,
        signatures: [signature],
      );
    });

    test('constructs and verifies a completed request', () {
      expect(signedMessage.version, 1);
      expect(signedMessage.text, 'Hello from Noosphere 🌍');
      expect(signedMessage.publicKey.x, orderedEquals(key.pubkey.x));
      expect(signedMessage.verify(), isTrue);
    });

    test('round-trips canonical JSON', () {
      final json = signedMessage.toJson();
      expect(json, {
        'format': 'noosphere-signed-message',
        'version': 1,
        'text': signedMessage.text,
        'publicKey': key.pubkey.xhex,
        'signature': cl.bytesToHex(signature.data),
      });

      final decoded = SignedMessage.fromJsonString(
        signedMessage.toJsonString(),
      );
      expect(decoded.verify(), isTrue);
      expect(decoded.toJson(), json);
    });

    test('changed text, public key, or signature fails verification', () {
      final otherKey = getPrivkey(1);
      final changedSignature = Uint8List.fromList(signature.data)..last ^= 1;

      expect(
        SignedMessage(
          text: '${signedMessage.text}!',
          publicKey: signedMessage.publicKey,
          signature: signature,
        ).verify(),
        isFalse,
      );
      expect(
        SignedMessage(
          text: signedMessage.text,
          publicKey: cl.ECCompressedPublicKey.fromPubkey(otherKey.pubkey),
          signature: signature,
        ).verify(),
        isFalse,
      );
      expect(
        SignedMessage(
          text: signedMessage.text,
          publicKey: signedMessage.publicKey,
          signature: cl.SchnorrSignature(changedSignature),
        ).verify(),
        isFalse,
      );
    });

    test('rejects invalid completion shapes and signatures', () {
      expect(
        () => SignedMessage.fromCompletedRequest(
          details: SignaturesRequestDetails(
            requiredSigs: details.requiredSigs,
            expiry: futureExpiry,
          ),
          signatures: [signature],
        ),
        throwsA(isA<InvalidMetaData>()),
      );
      expect(
        () => SignedMessage.fromCompletedRequest(
          details: details,
          signatures: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => SignedMessage.fromCompletedRequest(
          details: details,
          signatures: [
            cl.SchnorrSignature(Uint8List.fromList(signature.data)..last ^= 1),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed JSON fields and canonical encodings', () {
      final valid = signedMessage.toJson();

      void expectBad(Map<String, Object?> json) =>
          expect(() => SignedMessage.fromJson(json), throwsFormatException);

      expectBad({...valid, 'format': 'other'});
      expectBad({...valid, 'version': '1'});
      expectBad({...valid, 'version': 2});
      expectBad({...valid, 'text': 1});
      expectBad({...valid, 'publicKey': key.pubkey.xhex.toUpperCase()});
      expectBad({...valid, 'publicKey': '00'});
      expectBad({...valid, 'publicKey': 'f' * 64});
      expectBad({...valid, 'signature': '00'});
      expectBad({...valid, 'signature': 'A' * 128});
      expect(
        () => SignedMessage.fromJsonString(jsonEncode([])),
        throwsFormatException,
      );
    });

    test('refuses to export an invalid signature', () {
      final invalid = SignedMessage(
        text: '${signedMessage.text}!',
        publicKey: signedMessage.publicKey,
        signature: signedMessage.signature,
      );
      expect(invalid.verify(), isFalse);
      expect(invalid.toJson, throwsStateError);
    });
  });
}

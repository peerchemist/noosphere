import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:test/test.dart';

import '../../support/data.dart';

void main() {
  group('MessageSignatureMetadata', () {
    late cl.ECCompressedPublicKey key;
    setUpAll(() async {
      await loadFrosty();
      key = cl.ECCompressedPublicKey.fromPubkey(getPrivkey(0).pubkey);
    });

    SingleSignatureDetails requiredSig(
      SignedMessagePayload payload, {
      Uint8List? message,
      Uint8List? mastHash,
      List<int> derivation = const [],
    }) => SingleSignatureDetails(
      signDetails: SignDetails(
        message: message ?? payload.digest,
        mastHash: mastHash,
      ),
      groupKey: key,
      hdDerivation: derivation,
    );

    test('round-trips as metadata type 2', () {
      final payload = SignedMessagePayload(text: 'Approve this exact text');
      final metadata = MessageSignatureMetadata(payload: payload);
      final decoded = SignatureMetadata.fromBytes(metadata.toBytes());

      expect(metadata.toBytes().first, 2);
      expect(decoded, isA<MessageSignatureMetadata>());
      final messageMetadata = decoded as MessageSignatureMetadata;
      expect(messageMetadata.payload.text, payload.text);
      expect(messageMetadata.payload.digest, orderedEquals(payload.digest));
      expect(messageMetadata.toBytes(), orderedEquals(metadata.toBytes()));
    });

    test('requires one matching untweaked, underived signature', () {
      final payload = SignedMessagePayload(text: 'sign me');
      final metadata = MessageSignatureMetadata(payload: payload);
      final valid = requiredSig(payload);

      expect(metadata.verifyRequiredSigs([valid]), isTrue);
      expect(metadata.verifyRequiredSigs([]), isFalse);
      expect(metadata.verifyRequiredSigs([valid, valid]), isFalse);
      expect(
        metadata.verifyRequiredSigs([
          requiredSig(payload, message: Uint8List(32)),
        ]),
        isFalse,
      );
      expect(
        metadata.verifyRequiredSigs([
          requiredSig(payload, mastHash: Uint8List(0)),
        ]),
        isFalse,
      );
      expect(
        metadata.verifyRequiredSigs([
          requiredSig(payload, mastHash: Uint8List(32)),
        ]),
        isFalse,
      );
      expect(
        metadata.verifyRequiredSigs([
          requiredSig(payload, derivation: const [0]),
        ]),
        isFalse,
      );
    });
  });

  group('SignaturesRequestDetails.forMessage', () {
    setUpAll(loadFrosty);

    test('constructs matching message metadata and signature details', () {
      final key = cl.ECCompressedPublicKey.fromPubkey(getPrivkey(0).pubkey);
      final details = SignaturesRequestDetails.forMessage(
        text: 'Hello!',
        groupKey: key,
        expiry: futureExpiry,
        message: 'Please approve this greeting',
      );

      final metadata = details.metadata as MessageSignatureMetadata;
      final requiredSig = details.requiredSigs.single;
      expect(metadata.payload.text, 'Hello!');
      expect(
        requiredSig.signDetails.message,
        orderedEquals(metadata.payload.digest),
      );
      expect(requiredSig.signDetails.mastHash, isNull);
      expect(requiredSig.hdDerivation, isEmpty);
      expect(requiredSig.groupKey, key);
      expect(details.message, 'Please approve this greeting');

      final decoded = SignaturesRequestDetails.fromBytes(details.toBytes());
      expect(decoded.metadata, isA<MessageSignatureMetadata>());
      expect(
        (decoded.metadata as MessageSignatureMetadata).payload.text,
        'Hello!',
      );
    });

    test('constructor rejects metadata and requested-signature mismatches', () {
      final key = cl.ECCompressedPublicKey.fromPubkey(getPrivkey(0).pubkey);
      final payload = SignedMessagePayload(text: 'original');

      expect(
        () => SignaturesRequestDetails(
          requiredSigs: [
            SingleSignatureDetails(
              signDetails: SignDetails(message: Uint8List(32), mastHash: null),
              groupKey: key,
              hdDerivation: const [],
            ),
          ],
          metadata: MessageSignatureMetadata(payload: payload),
          expiry: futureExpiry,
        ),
        throwsA(isA<InvalidMetaData>()),
      );
    });
  });
}

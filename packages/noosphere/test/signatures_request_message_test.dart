import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(loadFrosty);

  late cl.ECPrivateKey key;
  late Expiry expiry;
  late List<SingleSignatureDetails> requiredSigs;

  setUp(() {
    key = cl.ECPrivateKey(Uint8List(32)..last = 1);
    expiry = Expiry(const Duration(hours: 1));
    requiredSigs = [
      SingleSignatureDetails(
        signDetails: SignDetails.keySpend(message: Uint8List(32)),
        groupKey: cl.ECCompressedPublicKey.fromPubkey(key.pubkey),
        hdDerivation: const [],
      ),
    ];
  });

  SignaturesRequestDetails details(String message) => SignaturesRequestDetails(
    requiredSigs: requiredSigs,
    expiry: expiry,
    message: message,
  );

  SignaturesProgress progress() => SignaturesProgress(
    threshold: 1,
    contributingParticipants: [Identifier.fromUint16(1)],
    stage: SignaturesProgressStage.collecting,
  );

  test('round-trips empty, Unicode, multiline and long explanations', () {
    for (final message in [
      '',
      'Račun #123 🧾\nApprove payment',
      'a' * SignaturesRequestDetails.maxMessageBytes,
      '🧾' * (SignaturesRequestDetails.maxMessageBytes ~/ 4),
    ]) {
      final original = details(message);
      final decoded = SignaturesRequestDetails.fromBytes(original.toBytes());
      expect(decoded.message, message);
      expect(decoded.toBytes(), original.toBytes());
      expect(decoded.id, original.id);
    }
  });

  test('constructors reject explanations exceeding the UTF-8 byte limit', () {
    for (final message in [
      'a' * (SignaturesRequestDetails.maxMessageBytes + 1),
      '${'🧾' * (SignaturesRequestDetails.maxMessageBytes ~/ 4)}a',
    ]) {
      expect(() => details(message), throwsArgumentError);
      expect(
        () => SignaturesRequestDetails.allowNegativeExpiry(
          requiredSigs: requiredSigs,
          expiry: Expiry(const Duration(days: -1)),
          message: message,
        ),
        throwsArgumentError,
      );
    }
  });

  test('readers reject oversized lengths before reading message bytes', () {
    final empty = details('').toBytes();
    for (final prefix in [
      // 1025 bytes, without a message body.
      [0xfd, 0x01, 0x04],
      // Maximum unsigned 64-bit length must also be rejected.
      [0xff, ...List.filled(8, 0xff)],
    ]) {
      final bytes = Uint8List.fromList([
        ...empty.sublist(0, empty.length - 1),
        ...prefix,
      ]);
      expect(
        () => SignaturesRequestDetails.fromBytes(bytes),
        throwsFormatException,
      );
      expect(
        () => SignaturesRequestDetails.fromReaderAllowNegativeExpiry(
          cl.BytesReader(bytes),
        ),
        throwsFormatException,
      );
    }
  });

  test('events authenticate the explanation with the requester signature', () {
    final original = details('Approve invoice #123');
    final signed = Signed.sign(obj: original, key: key);
    final event = SignaturesRequestEvent(
      details: signed,
      creator: Identifier.fromUint16(1),
      progress: progress(),
    );
    final decoded = SignaturesRequestEvent.fromBytes(event.toBytes());
    expect(decoded.details.obj.message, original.message);
    expect(decoded.details.verify(key.pubkey), isTrue);
    expect(decoded.creator, event.creator);
    expect(decoded.progress.threshold, 1);
    expect(decoded.progress.contributingParticipants, {
      Identifier.fromUint16(1),
    });
    expect(decoded.progress.stage, SignaturesProgressStage.collecting);
    expect(decoded.toBytes(), event.toBytes());

    final changed = details('Approve invoice #456');
    expect(changed.id, isNot(original.id));
    expect(
      changed.requiredSigs.single.toBytes(),
      requiredSigs.single.toBytes(),
    );
    expect(
      Signed(obj: changed, signature: signed.signature).verify(key.pubkey),
      isFalse,
    );
  });

  test('events can decode expired requests for replay and cleanup', () {
    final expired = SignaturesRequestDetails.allowNegativeExpiry(
      requiredSigs: requiredSigs,
      expiry: Expiry(const Duration(seconds: -1)),
      message: 'Expired request',
    );
    final event = SignaturesRequestEvent(
      details: Signed.sign(obj: expired, key: key),
      creator: Identifier.fromUint16(1),
      progress: progress(),
    );

    final decoded = SignaturesRequestEvent.fromBytes(event.toBytes());

    expect(decoded.details.obj.expiry.isExpired, isTrue);
    expect(decoded.details.obj.message, expired.message);
    expect(decoded.details.verify(key.pubkey), isTrue);
  });

  test('login replay preserves request explanations', () {
    final original = details('Approve invoice #123');
    final response = LoginCompleteResponse(
      id: SessionID(),
      expiry: expiry,
      startTime: DateTime.now(),
      onlineParticipants: {Identifier.fromUint16(1)},
      newDkgs: [],
      sigRequests: [
        SignaturesRequestEvent(
          details: Signed.sign(obj: original, key: key),
          creator: Identifier.fromUint16(1),
          progress: progress(),
        ),
      ],
      sigRounds: [],
      completedSigs: [],
      secretShares: [],
      events: const Stream.empty(),
    );
    final decoded = LoginCompleteResponse.fromBytes(
      response.toBytes(),
      const Stream.empty(),
    );
    expect(decoded.sigRequests.single.details.obj.message, original.message);
    expect(decoded.sigRequests.single.progress.threshold, 1);
    expect(decoded.sigRequests.single.details.verify(key.pubkey), isTrue);
    expect(decoded.toBytes(), response.toBytes());
  });
}

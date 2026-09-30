import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:test/test.dart';
import 'package:noosphere/domain.dart';

import '../../support/data.dart';
import '../../support/test_keys.dart';

void main() {
  group("SignaturesRequestDetails", () {
    setUpAll(loadFrosty);

    final il32 = List<int>.filled(32, 0);

    test("can read/write", () {
      final bytes = [
        2,
        0,
        ...il32,
        0,
        ...groupPublicKey.data,
        0,
        ...il32,
        1,
        ...groupPublicKey.data,
        0,
        0,
        ...expiryBytes,
        0,
      ];

      final obj = SignaturesRequestDetails.fromBytes(Uint8List.fromList(bytes));
      expect(obj.toBytes(), bytes);
      expect(obj.requiredSigs, hasLength(2));
      expect(obj.metadata, isA<EmptySignatureMetadata>());
      expect(obj.message, isEmpty);
      expect(obj.expiry.time.millisecondsSinceEpoch, expiryTimestamp);
    });

    test("invalid details", () {
      SingleSignatureDetails getSingleSig() => SingleSignatureDetails(
        signDetails: SignDetails.scriptSpend(message: Uint8List(32)),
        groupKey: groupPublicKey,
        hdDerivation: [],
      );

      void expectInvalid({
        List<SingleSignatureDetails>? sigs,
        Expiry? expiry,
      }) => expect(
        () => SignaturesRequestDetails(
          requiredSigs: sigs ?? [getSingleSig()],
          expiry: expiry ?? Expiry(Duration(days: 1)),
        ),
        throwsArgumentError,
      );

      // Duplicate sig
      expectInvalid(sigs: [getSingleSig(), getSingleSig()]);

      // No sigs
      expectInvalid(sigs: []);

      // Expired
      expectInvalid(expiry: Expiry(Duration(days: -1)));
    });

    test("completed requests can contain expired details", () {
      final key = getPrivkey(0);
      final details = SignaturesRequestDetails.allowNegativeExpiry(
        requiredSigs: [
          SingleSignatureDetails(
            signDetails: SignDetails.keySpend(message: Uint8List(32)),
            groupKey: cl.ECCompressedPublicKey.fromPubkey(key.pubkey),
            hdDerivation: const [],
          ),
        ],
        expiry: Expiry(Duration(days: -1)),
        message: 'Previously approved payment',
      );
      final signed = Signed.sign(obj: details, key: key);
      final completed = CompletedSignaturesRequest(
        details: signed,
        signatures: [signed.signature],
        creator: ids.first,
      );

      expect(
        () => SignaturesRequestDetails.fromBytes(details.toBytes()),
        throwsArgumentError,
      );
      final historical = SignaturesRequestDetails.fromBytesAllowExpired(
        details.toBytes(),
      );
      expect(historical.expiry.isExpired, isTrue);
      expect(historical.message, details.message);
      expect(historical.toBytes(), details.toBytes());

      final decoded = CompletedSignaturesRequest.fromBytes(completed.toBytes());
      expect(decoded.details.obj.expiry.isExpired, isTrue);
      expect(decoded.details.obj.message, details.message);
      expect(decoded.details.verify(key.pubkey), isTrue);
      expect(decoded.toBytes(), completed.toBytes());
    });

    test("requires metadata hashes to match", () {
      final key = getPrivkey(0);
      final tr = cl.Taproot(internalKey: key.pubkey);
      final output = cl.Output.fromProgram(
        cl.CoinUnit.coin.toSats("1"),
        cl.P2TR.fromTaproot(tr),
      );
      final tx = cl.Transaction(
        inputs: [cl.TaprootKeyInput(prevOut: cl.OutPoint(dummyHash, 0))],
        outputs: [output],
      );
      final trDetails = cl.TaprootKeySignDetails(
        tx: tx,
        inputN: 0,
        prevOuts: [output],
      );
      final metadata = TaprootTransactionSignatureMetadata(
        transaction: tx,
        signDetails: [trDetails],
      );

      void makeDetailsWithMsg(Uint8List msg) => SignaturesRequestDetails(
        requiredSigs: [
          SingleSignatureDetails(
            signDetails: SignDetails.keySpend(message: msg),
            groupKey: cl.ECCompressedPublicKey.fromPubkey(key.pubkey),
            hdDerivation: [],
          ),
        ],
        expiry: futureExpiry,
        metadata: metadata,
        message: 'Approve this transaction',
      );

      expect(
        () => makeDetailsWithMsg(Uint8List(32)),
        throwsA(isA<InvalidMetaData>()),
      );
      expect(
        () => makeDetailsWithMsg(cl.TaprootSignatureHasher(trDetails).hash),
        returnsNormally,
      );
    });
  });
}

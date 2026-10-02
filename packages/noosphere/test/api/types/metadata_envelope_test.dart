import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(loadFrosty);
  for (final type in [0, 1, 2]) {
    test(
      'metadata $type survives authenticated request, event and login replay',
      () {
        final key = cl.ECPrivateKey(Uint8List(32)..last = 1);
        final groupKey = cl.ECCompressedPublicKey.fromPubkey(key.pubkey);
        final payload = SignedMessagePayload(text: 'Metadata envelope 🧾');
        final tx = cl.Transaction(
          inputs: [cl.TaprootKeyInput(prevOut: cl.OutPoint(Uint8List(32), 0))],
          outputs: [
            cl.Output.fromProgram(
              BigInt.one,
              cl.P2TR.fromTaproot(cl.Taproot(internalKey: groupKey)),
            ),
          ],
        );
        final taproot = cl.TaprootKeySignDetails(
          tx: tx,
          inputN: 0,
          prevOuts: tx.outputs,
        );
        final metadata = switch (type) {
          0 => EmptySignatureMetadata(),
          1 => TaprootTransactionSignatureMetadata(
            transaction: tx,
            signDetails: [taproot],
          ),
          _ => MessageSignatureMetadata(payload: payload),
        };
        final signDetails = switch (type) {
          1 => SignDetails.keySpend(
            message: cl.TaprootSignatureHasher(taproot).hash,
          ),
          _ => SignDetails.scriptSpend(message: payload.digest),
        };
        final details = SignaturesRequestDetails(
          requiredSigs: [
            SingleSignatureDetails(
              signDetails: signDetails,
              groupKey: groupKey,
              hdDerivation: [],
            ),
          ],
          expiry: Expiry(const Duration(hours: 1)),
          metadata: metadata,
        );
        final signed = Signed.sign(obj: details, key: key);
        final event = SignaturesRequestEvent(
          details: signed,
          creator: Identifier.fromUint16(1),
          progress: SignaturesProgress(
            threshold: 1,
            contributingParticipants: [],
            stage: SignaturesProgressStage.collecting,
          ),
        );
        final login = LoginCompleteResponse(
          id: SessionID(),
          expiry: details.expiry,
          startTime: DateTime.now(),
          onlineParticipants: {event.creator},
          newDkgs: [],
          sigRequests: [event],
          sigRounds: [],
          completedSigs: [],
          secretShares: [],
          events: const Stream.empty(),
        );
        final request = SignaturesRequestDetails.fromBytes(details.toBytes());
        final decodedEvent = SignaturesRequestEvent.fromBytes(event.toBytes());
        final decodedLogin = LoginCompleteResponse.fromBytes(
          login.toBytes(),
          const Stream.empty(),
        );
        for (final decoded in [
          request,
          decodedEvent.details.obj,
          decodedLogin.sigRequests.single.details.obj,
        ]) {
          expect(decoded.metadata.type, type);
          expect(
            decoded.metadata.verifyRequiredSigs(decoded.requiredSigs),
            isTrue,
          );
          expect(decoded.toBytes(), details.toBytes());
          expect(
            Signed(
              obj: decoded,
              signature: signed.signature,
            ).verify(key.pubkey),
            isTrue,
          );
        }
        expect(decodedEvent.toBytes(), event.toBytes());
        expect(decodedLogin.toBytes(), login.toBytes());
      },
    );
  }
}

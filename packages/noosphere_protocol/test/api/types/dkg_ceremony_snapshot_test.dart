import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/domain.dart';
import 'package:test/test.dart';

import '../../support/data.dart';

void main() {
  setUpAll(loadFrosty);

  test('snapshot is canonical and round-trips caller-scoped progress', () {
    final details = getDkgDetails(name: 'resumable');
    final signed = Signed.sign(obj: details, key: getPrivkey(0));
    final first = DkgPart1(identifier: ids[0], threshold: 2, n: 2).public;
    final second = DkgPart1(identifier: ids[1], threshold: 2, n: 2).public;
    final snapshot = DkgCeremonySnapshot(
      details: signed,
      creator: ids[0],
      commitments: [(ids[1], second), (ids[0], first)],
      stage: DkgCeremonyStage.collectingShares,
      shareContributors: {ids[1], ids[0]},
      shares: const [],
      completedParticipants: {ids[1]},
    );
    final same = DkgCeremonySnapshot(
      details: signed,
      creator: ids[0],
      commitments: [(ids[0], first), (ids[1], second)],
      stage: DkgCeremonyStage.collectingShares,
      shareContributors: {ids[0], ids[1]},
      shares: const [],
      completedParticipants: {ids[1]},
    );

    expect(snapshot.toBytes(), same.toBytes());
    final decoded = DkgCeremonySnapshot.fromBytes(snapshot.toBytes());
    expect(decoded.details.toBytes(), signed.toBytes());
    expect(decoded.ceremonyId, details.ceremonyId);
    expect(decoded.commitments.map((entry) => entry.$1), [ids[0], ids[1]]);
    expect(decoded.shareContributors, {ids[0], ids[1]});
    expect(decoded.completedParticipants, {ids[1]});
    expect(decoded.stage, DkgCeremonyStage.collectingShares);
    expect(decoded.groupPublicKey, isNull);
  });

  test('completion acknowledgement binds ceremony, transcript and key', () {
    final groupKey = cl.ECCompressedPublicKey.fromPubkey(getPrivkey(1).pubkey);
    final ceremonyId = Uint8List(32)..first = 1;
    final transcriptHash = Uint8List(32)..last = 2;
    final ack = DkgAck(
      groupKey: groupKey,
      accepted: true,
      ceremonyId: ceremonyId,
      transcriptHash: transcriptHash,
    );
    final signed = Signed.sign(obj: ack, key: getPrivkey(0));
    expect(signed.verify(getPrivkey(0).pubkey), isTrue);

    final decoded = Signed<DkgAck>.fromBytes(
      signed.toBytes(),
      DkgAck.fromReader,
    );
    expect(decoded.obj.ceremonyId, ceremonyId);
    expect(decoded.obj.transcriptHash, transcriptHash);
    expect(decoded.obj.groupKey, groupKey);

    expect(
      Signed(
        obj: DkgAck(
          groupKey: groupKey,
          accepted: true,
          ceremonyId: Uint8List.fromList(ceremonyId)..last = 9,
          transcriptHash: transcriptHash,
        ),
        signature: signed.signature,
      ).verify(getPrivkey(0).pubkey),
      isFalse,
    );

    final first = SignedDkgAck(signer: ids[0], signed: signed);
    final differentTranscript = SignedDkgAck(
      signer: ids[0],
      signed: Signed.sign(
        obj: DkgAck(
          groupKey: groupKey,
          accepted: true,
          ceremonyId: ceremonyId,
          transcriptHash: Uint8List.fromList(transcriptHash)..first = 3,
        ),
        key: getPrivkey(0),
      ),
    );
    expect(first, isNot(differentTranscript));
    expect({first, differentTranscript}, hasLength(2));
  });

  test('malformed acknowledgement bytes fail decoding', () {
    final groupKey = cl.ECCompressedPublicKey.fromPubkey(getPrivkey(1).pubkey);
    final signed = Signed.sign(
      obj: DkgAck(
        groupKey: groupKey,
        accepted: true,
        ceremonyId: Uint8List(32),
        transcriptHash: Uint8List(32),
      ),
      key: getPrivkey(0),
    ).toBytes();

    expect(
      () => Signed<DkgAck>.fromBytes(
        Uint8List.sublistView(signed, 0, signed.length - 1),
        DkgAck.fromReader,
      ),
      throwsA(anything),
    );
  });
}

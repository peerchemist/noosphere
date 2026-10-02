import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common.dart';
import 'package:noosphere/config.dart';
import 'package:noosphere/domain.dart';
import 'package:test/test.dart';

import '../support/data.dart';

void main() {
  setUpAll(loadFrosty);

  test('whole-value decoders respect typed-list slice boundaries', () {
    final details = getDkgDetails();
    final encoded = details.toBytes();
    final backing = Uint8List.fromList([99, ...encoded, 88]);
    final view = Uint8List.sublistView(backing, 1, backing.length - 1);
    expect(NewDkgDetails.fromBytes(view).toBytes(), encoded);
    expect(
      () => NewDkgDetails.fromBytes(Uint8List.sublistView(view, 0, 3)),
      throwsA(anyOf(isA<FormatException>(), isA<cl.OutOfData>())),
    );
  });

  test('signed and unsigned whole-value decoders reject trailing bytes', () {
    final details = getDkgDetails();
    final signed = Signed.sign(obj: details, key: getPrivkey(0));
    expect(
      () => NewDkgDetails.fromBytes(
        Uint8List.fromList([...details.toBytes(), 0]),
      ),
      throwsFormatException,
    );
    expect(
      () => Signed.fromBytes(
        Uint8List.fromList([...signed.toBytes(), 0]),
        NewDkgDetails.fromReader,
      ),
      throwsFormatException,
    );
    expect(
      () => SignaturesRequestId.fromBytes(Uint8List(17)),
      throwsFormatException,
    );
  });

  test('cached hashes and serialized signed values cannot be modified', () {
    final details = getDkgDetails();
    final signed = Signed.sign(obj: details, key: getPrivkey(0));
    expect(() => details.sigHash[0] ^= 1, throwsUnsupportedError);
    expect(() => details.toBytes()[0] ^= 1, throwsUnsupportedError);
    expect(() => signed.toBytes()[0] ^= 1, throwsUnsupportedError);
    expect(signed.verify(getPrivkey(0).pubkey), isTrue);
    expect(
      Signed.fromBytes(
        signed.toBytes(),
        NewDkgDetails.fromReader,
      ).verify(getPrivkey(0).pubkey),
      isTrue,
    );
  });

  test('hash and session inputs are owned and cannot invalidate map keys', () {
    final bytes = Uint8List(32)..last = 7;
    final hash = SignableHash(bytes);
    bytes.last = 8;
    expect(hash.bytes.last, 7);
    expect(() => hash.bytes.last = 9, throwsUnsupportedError);

    final input = Uint8List(16)..last = 1;
    final session = SessionID.fromBytes(input);
    final sessions = {session: 'active'};
    input.last = 2;
    expect(sessions[SessionID.fromBytes(Uint8List(16)..last = 1)], 'active');
    expect(() => session.n.last = 2, throwsUnsupportedError);
  });

  test('signing details freeze Frosty message and tweak bytes', () {
    final message = Uint8List(32)..last = 1;
    final mastHash = Uint8List(32)..last = 2;
    final details = SingleSignatureDetails(
      signDetails: SignDetails(message: message, mastHash: mastHash),
      groupKey: groupConfig.participants.values.first,
      hdDerivation: const [],
    );
    message.last = 3;
    mastHash.last = 4;
    expect(details.signDetails.message.last, 1);
    expect(details.signDetails.mastHash!.last, 2);
    expect(() => details.signDetails.message.last = 5, throwsUnsupportedError);
    expect(
      () => details.signDetails.mastHash!.last = 5,
      throwsUnsupportedError,
    );
    expect(() => details.signDetails.toBytes()[0] = 5, throwsUnsupportedError);
  });

  test('group roster is immutable and rejects duplicate wire identifiers', () {
    final fingerprint = groupConfig.fingerprint;
    expect(() => groupConfig.participants.clear(), throwsUnsupportedError);
    expect(groupConfig.fingerprint, fingerprint);
    final id = ids.first.toBytes();
    final key = groupConfig.participants.values.first.data;
    expect(
      () => GroupConfig.fromBytes(
        Uint8List.fromList([
          1,
          65,
          3,
          0,
          ...id,
          ...key,
          ...id,
          ...key,
          ...ids[1].toBytes(),
          ...key,
        ]),
      ),
      throwsFormatException,
    );
  });

  test('lengths, booleans and maps reject ambiguous input', () {
    for (final bytes in [
      [0xfd, 1, 0],
      [0xfe, 1, 0, 0, 0],
      [0xff, 1, 0, 0, 0, 0, 0, 0, 0],
    ]) {
      expect(
        () => NoosphereBytesReader(Uint8List.fromList(bytes)).readVarInt(),
        throwsFormatException,
      );
    }
    for (final read in [
      (NoosphereBytesReader reader) => reader.readVector(),
      (NoosphereBytesReader reader) => reader.readVarSlice(),
    ]) {
      expect(
        () => read(
          NoosphereBytesReader(
            Uint8List.fromList([0xff, 255, 255, 255, 255, 255, 255, 255, 255]),
          ),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => NoosphereBytesReader(Uint8List.fromList([2])).readBool(),
      throwsFormatException,
    );
    final reader = NoosphereBytesReader(Uint8List.fromList([2, 0, 1, 7, 1, 8]));
    expect(
      () => reader.readMap(reader.readUInt8, reader.readUInt8),
      throwsFormatException,
    );
  });

  test('canonical lengths include the exact integer-width boundaries', () {
    for (final value in [
      252,
      253,
      65534,
      65535,
      65536,
      0xffffffff,
      0x100000000,
    ]) {
      final buffer = Uint8List(9);
      final writer = cl.BytesWriter(buffer)..writeVarInt(BigInt.from(value));
      final reader = NoosphereBytesReader(
        Uint8List.sublistView(buffer, 0, writer.offset),
      );
      expect(reader.readVarInt(), BigInt.from(value));
      expect(reader.atEnd, isTrue);
    }
    final policy = GroupTransitionMigrationPolicy(
      kind: 'boundary',
      version: 1,
      payload: Uint8List(0xffff),
    );
    final reader = NoosphereBytesReader(policy.toBytes());
    expect(
      GroupTransitionMigrationPolicy.fromReader(reader).payload,
      hasLength(0xffff),
    );
    expect(
      reader.atEnd,
      isTrue,
      reason: 'no padding after a 65535-byte payload',
    );
  });

  test('unknown metadata is bounded standalone and rejected in requests', () {
    final backing = Uint8List.fromList([77, 255, 1, 2, 88]);
    final metadata = SignatureMetadata.fromBytes(
      Uint8List.sublistView(backing, 1, 4),
    ) as UnknownSignatureMetadata;
    expect(metadata.toBytes(), [255, 1, 2]);
    expect(metadata.verifyRequiredSigs([]), isFalse);
    expect(
      () => SignatureMetadata.fromReader(
        NoosphereBytesReader(Uint8List.fromList([255, 1, 2])),
      ),
      throwsFormatException,
    );
  });

  test('empty YAML reports a configuration error', () {
    expect(() => GroupConfig.fromYaml(''), throwsA(isA<MapReaderException>()));
  });

  test('login consumers can update their own participant set', () {
    final snapshot = LoginCompleteResponse(
      id: SessionID(),
      expiry: futureExpiry,
      startTime: DateTime.utc(2026),
      onlineParticipants: {ids.first},
      newDkgs: const [],
      sigRequests: const [],
      sigRounds: const [],
      completedSigs: const [],
      secretShares: const [],
      events: const Stream.empty(),
    );
    final bytes = snapshot.toBytes();
    final live = snapshot.onlineParticipants;
    live.add(ids[1]);
    expect(live, hasLength(2));
    expect(snapshot.onlineParticipants, {ids.first});
    expect(snapshot.toBytes(), bytes);
  });
}

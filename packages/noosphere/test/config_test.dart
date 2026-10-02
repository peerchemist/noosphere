import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/config.dart';
import 'package:noosphere/domain.dart';
import 'package:test/test.dart';

import 'support/data.dart';

void writableTest(
  cl.Writable Function() getWritable,
  cl.Writable Function(cl.BytesReader) fromReader,
) => test("read/write", () {
  final bytes = getWritable().toBytes();
  expect(fromReader(cl.BytesReader(bytes)).toBytes(), bytes);
});

void main() {
  setUpAll(loadFrosty);

  group("GroupConfig", () {
    test(
      ".fingerprint",
      () => expect(
        cl.bytesToHex(groupConfig.fingerprint),
        "348ca21ac5395f845f12728139ecbb396698388b8d47543350e4b053476d938d",
      ),
    );

    test(
      "require 2 or more participants",
      () => expect(
        () => GroupConfig(
          id: "id",
          participants: {
            Identifier.fromUint16(1): cl.ECCompressedPublicKey.fromPubkey(
              getPrivkey(1).pubkey,
            ),
          },
        ),
        throwsRangeError,
      ),
    );

    writableTest(() => groupConfig, (reader) => GroupConfig.fromReader(reader));
    test('binary round trip preserves fingerprint', () {
      expect(
        GroupConfig.fromBytes(groupConfig.toBytes()).fingerprint,
        groupConfig.fingerprint,
      );
    });
  });
}

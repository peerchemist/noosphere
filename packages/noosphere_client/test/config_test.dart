import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_client/noosphere_client.dart';
import 'package:test/test.dart';

import 'data.dart';

void writableTest(
  cl.Writable Function() getWritable,
  cl.Writable Function(cl.BytesReader) fromReader,
) => test("read/write", () {
  final bytes = getWritable().toBytes();
  expect(fromReader(cl.BytesReader(bytes)).toBytes(), bytes);
});

void main() {
  setUpAll(loadFrosty);

  group("ClientConfig", () {
    writableTest(
      () => getClientConfig(0),
      (reader) => ClientConfig.fromReader(reader),
    );

    test(
      "require client id to be in group",
      () => expect(
        () => ClientConfig(group: groupConfig, id: Identifier.fromUint16(11)),
        throwsArgumentError,
      ),
    );

    test('accepts defaults and explicit lifetimes', () {
      final config = ClientConfig(
        id: groupConfig.participants.keys.first,
        group: groupConfig,
        maxDkgRequestTTL: const Duration(milliseconds: 50000),
      );
      expect(config.minDkgRequestTTL, ClientConfig.defaultMinDkgRequestTTL);
      expect(config.maxDkgRequestTTL.inMilliseconds, 50000);
    });
  });
}

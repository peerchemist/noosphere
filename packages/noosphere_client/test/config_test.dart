import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_client/noosphere_client.dart';
import 'package:test/test.dart';

import 'data.dart';

final String id1 =
    "000000000000000000000000000000000000000000000000000000000000000a";
final String id2 =
    "000000000000000000000000000000000000000000000000000000000000000b";
final String key1 =
    "02774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cb";
final String key2 =
    "03a0434d9e47f3c86235477c7b1ae6ae5d3442d49b1943c2b752a68e2a47e247c7";

void writableTest(
  cl.Writable Function() getWritable,
  cl.Writable Function(cl.BytesReader) fromReader,
) => test("read/write", () {
  final bytes = getWritable().toBytes();
  expect(fromReader(cl.BytesReader(bytes)).toBytes(), bytes);
});

void yamlTest<T extends MapWritable>(
  T Function() getWritable,
  T Function(String) fromYaml,
  String Function(T) toHex,
) => test("read/write yaml", () {
  final writable = getWritable();
  expect(fromYaml(writable.yaml).yaml, writable.yaml);
  // Expect bytes to be the same after YAML conversion
  expect(toHex(writable), toHex(fromYaml(writable.yaml)));
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

    yamlTest(
      () => getClientConfig(0),
      (yaml) => ClientConfig.fromYaml(yaml),
      (config) => config.toHex(),
    );

    test("accepts defaults", () {
      final config = ClientConfig.fromYaml("""
id: $id1
ms-lifetimes:
  max-dkg-request: 50000
group:
  id: SomeGroup
  participant-keys:
    $id1: $key1
    $id2: $key2
      """);
      expect(config.minDkgRequestTTL, ClientConfig.defaultMinDkgRequestTTL);
      expect(config.maxDkgRequestTTL.inMilliseconds, 50000);
    });
  });
}

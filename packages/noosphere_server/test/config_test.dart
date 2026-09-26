import 'package:noosphere_server/noosphere_server.dart';
import 'package:test/test.dart';

import 'data.dart';
import 'helpers.dart';

final String id1 =
    "000000000000000000000000000000000000000000000000000000000000000a";
final String id2 =
    "000000000000000000000000000000000000000000000000000000000000000b";
final String key1 =
    "02774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cb";
final String key2 =
    "03a0434d9e47f3c86235477c7b1ae6ae5d3442d49b1943c2b752a68e2a47e247c7";

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

final irohConfig = IrohConfig(
  server: serverConfig,
  secretKeyPath: '/var/lib/noosphere/identity.key',
  relay: IrohRelayConfig.custom(const ['https://relay.example']),
  nativeLibraryPath: '/app/libirohdart_ffi.so',
);

void main() {
  setUpAll(loadFrosty);

  group("ServerConfig", () {
    writableTest(
      () => serverConfig,
      (reader) => ServerConfig.fromReader(reader),
    );
    yamlTest(
      () => serverConfig,
      (yaml) => ServerConfig.fromYaml(yaml),
      (config) => config.toHex(),
    );
  });

  group('IrohConfig', () {
    test('read/write yaml', () {
      final decoded = IrohConfig.fromYaml(irohConfig.yaml);
      expect(decoded.yaml, irohConfig.yaml);
      expect(decoded.server.toHex(), irohConfig.server.toHex());
    });

    test('rejects unknown relay policy', () {
      expect(
        () => IrohConfig.fromYaml(
          irohConfig.yaml.replaceFirst('custom', 'surprise'),
        ),
        throwsA(isA<MapReaderException>()),
      );
    });
  });
}

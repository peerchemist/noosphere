import 'package:noosphere_server/noosphere_server.dart';
import 'package:test/test.dart';

import '../bin/src/config.dart';
import 'data.dart';
import 'helpers.dart';

String cliYaml({String extra = ''}) =>
    '''
secret-key-path: /data/identity.key
server:
  group:
    id: ${groupConfig.id}
    participant-keys:
${groupConfig.participants.entries.map((e) => '      "${e.key}": "${e.value.hex}"').join('\n')}
$extra
''';

void main() {
  setUpAll(loadFrosty);

  group('ServerConfig', () {
    writableTest(() => serverConfig, ServerConfig.fromReader);
    test(
      'optional public-feed config round-trips and old config stays disabled',
      () {
        final feed = PublicFeedConfig(
          feedId: PublicFeedId.generate(),
          maxEntries: 17,
          maxAge: const Duration(hours: 2),
        );
        final config = ServerConfig(group: groupConfig, publicFeed: feed);
        final restored = ServerConfig.fromBytes(config.toBytes());
        expect(restored.publicFeed!.feedId, feed.feedId);
        expect(restored.publicFeed!.maxEntries, 17);
        expect(restored.publicFeed!.maxAge, const Duration(hours: 2));
        expect(
          ServerConfig.fromBytes(serverConfig.toBytes()).publicFeed,
          isNull,
        );
      },
    );
  });

  group('CLI configuration', () {
    CliConfig parse(String source) =>
        CliConfig.fromYaml(source, configPath: '/data/server.yaml');

    test('loads group and filesystem paths with transport defaults', () {
      final config = parse(cliYaml());
      expect(config.server.server.group.toBytes(), groupConfig.toBytes());
      expect(config.server.server.group.fingerprint, groupConfig.fingerprint);
      expect(config.secretKeyPath, '/data/identity.key');
      expect(config.stateDirectory, '/data/server.yaml.state');
      expect(config.server.authTimeout, IrohConfig.defaultAuthTimeout);
      expect(config.server.server.sessionTTL, ServerConfig.defaultSessionTTL);
      expect(config.server.relay.policy, IrohRelayPolicy.defaultNetwork);
      expect(config.server.server.publicFeed, isNull);
    });

    test('public feed requires explicit opt-in and a valid opaque ID', () {
      final id = PublicFeedId.generate();
      final config = parse(
        cliYaml(
          extra:
              '  public-feed:\n    enabled: true\n    feed-id: "${id.hex}"\n    max-entries: 37\n    max-age-ms: 60000',
        ),
      );
      expect(config.server.server.publicFeed!.feedId, id);
      expect(config.server.server.publicFeed!.maxEntries, 37);
      expect(
        config.server.server.publicFeed!.maxAge,
        const Duration(minutes: 1),
      );
      expect(
        parse(cliYaml(extra: '  public-feed:\n    feed-id: "${id.hex}"'))
            .server
            .server
            .publicFeed,
        isNull,
      );
      expect(
        () => parse(
          cliYaml(
            extra: '  public-feed:\n    enabled: true\n    feed-id: wrong',
          ),
        ),
        throwsFormatException,
      );
    });

    test('loads explicit transport options and server lifetimes', () {
      final config = parse(
        cliYaml(
          extra: '''
  ms-lifetimes:
    max-signatures-request: 50000
  keep-alive-event-ms: 1200
state-directory: /custom/state
relay:
  policy: custom
  urls: [https://relay.example]
timeouts-ms:
  auth: 2345
  rpc: 3456
  shutdown: 4567
limits:
  max-message-bytes: 8192
  max-connections: 16
  max-streams-per-connection: 8
native-library-path: /app/libirohdart_ffi.so
''',
        ),
      );
      expect(config.stateDirectory, '/custom/state');
      expect(config.server.relay.urls, ['https://relay.example']);
      expect(config.server.authTimeout.inMilliseconds, 2345);
      expect(config.server.rpcTimeout.inMilliseconds, 3456);
      expect(config.server.shutdownTimeout.inMilliseconds, 4567);
      expect(config.server.maxMessageLength, 8192);
      expect(config.server.maxConnections, 16);
      expect(config.server.maxStreamsPerConnection, 8);
      expect(config.server.nativeLibraryPath, '/app/libirohdart_ffi.so');
      expect(
        config.server.server.maxSignaturesRequestTTL.inMilliseconds,
        50000,
      );
      expect(config.server.server.keepAliveFreq!.inMilliseconds, 1200);
    });

    test('rejects malformed configuration with a format error', () {
      for (final source in [
        '',
        'server: {}',
        cliYaml(extra: 'relay:\n  policy: surprise'),
        cliYaml(extra: 'relay:\n  policy: custom\n  urls: [5]'),
        cliYaml().replaceFirst('secret-key-path:', 'unused:'),
        cliYaml().replaceFirst('id: ${groupConfig.id}', 'id: 5'),
      ]) {
        expect(() => parse(source), throwsFormatException);
      }
    });
  });
}

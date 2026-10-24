import 'package:noosphere_server/noosphere_server.dart';
import 'package:test/test.dart';

import 'data.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadFrosty);

  group('ServerConfig', () {
    writableTest(() => serverConfig, ServerConfig.fromReader);

    test('DKG participant limit defaults to 64 and round-trips', () {
      expect(
        ServerConfig(group: groupConfig).maxDkgParticipants,
        ServerConfig.defaultMaxDkgParticipants,
      );

      final feed = PublicFeedConfig(
        feedId: PublicFeedId.generate(),
        maxEntries: 17,
        maxAge: const Duration(hours: 2),
      );
      final restored = ServerConfig.fromBytes(
        ServerConfig(
          group: groupConfig,
          maxDkgParticipants: 17,
          publicFeed: feed,
        ).toBytes(),
      );

      expect(restored.maxDkgParticipants, 17);
      expect(restored.publicFeed!.feedId, feed.feedId);
    });

    test('DKG participant limit must contain the configured group', () {
      expect(
        () => ServerConfig(group: groupConfig, maxDkgParticipants: 1),
        throwsRangeError,
      );
      expect(
        () => ServerConfig(group: groupConfig, maxDkgParticipants: 9),
        throwsArgumentError,
      );
    });

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
}

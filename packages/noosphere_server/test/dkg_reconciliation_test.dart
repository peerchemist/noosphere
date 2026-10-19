import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_client/noosphere_client.dart';
import 'package:test/test.dart';

import 'context.dart';
import 'data.dart';
import 'test_keys.dart';

void main() {
  setUpAll(() async {
    await cl.loadCoinlib();
    await loadFrosty();
  });
  test(
    'blocked signer stays connected when asked for possession ACK',
    () async {
      final ctx = TestContext();
      final original = await TestClient.login(ctx.api, 0);
      final details = getDkgDetails();
      await original.client.requestDkg(details);
      await original.logout();
      var disconnected = false;
      final blocked = await TestClient.login(
        ctx.api,
        0,
        onDisconnect: () {
          disconnected = true;
        },
      );
      addTearDown(blocked.logout);
      expect(blocked.client.acceptedDkgs.single.canResume, isFalse);
      final peer = await ctx.login(1);
      await ctx.api.requestDkgAcks(
        sid: peer.sid,
        requests: {
          DkgAckRequest(
            ids: {ids[0]},
            groupPublicKey: groupPublicKey,
            ceremonyId: details.ceremonyId,
            transcriptHash: Uint8List(32),
          ),
        },
      );
      await pumpEventQueue();
      expect(disconnected, isFalse);
      await blocked.evCollector.expectNoError();
    },
  );
  test(
    'refresh retains commitments delivered while snapshot is in flight',
    () async {
      final api = DelayedGetDkgApi();
      final ctx = TestContext(api);
      final client = await TestClient.login(api, 0);
      addTearDown(client.logout);
      final details = getDkgDetails();
      await client.client.requestDkg(details);
      final peer = await ctx.login(1);
      final refresh = client.client.refreshDkg(details.name);
      await api.fetched.future;
      await api.submitDkgCommitment(
        sid: peer.sid,
        name: details.name,
        ceremonyId: details.ceremonyId,
        commitment: getDkgPart1(1).public,
      );
      await pumpEventQueue();
      expect(client.client.acceptedDkgs.single.completed, contains(ids[1]));
      api.release.complete();
      await refresh;
      expect(client.client.acceptedDkgs.single.completed, contains(ids[1]));
    },
  );
}

@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_client/testing.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/iroh/dispatcher.dart';
import 'package:test/test.dart';

import 'data.dart';

void main() {
  setUpAll(loadFrosty);

  test('local client authenticates and releases its server session', () async {
    final handler = getApiHandler();
    final dispatcher = IrohDispatcher.single(handler);
    final api = LocalCoordinatorApi.attach(
      dispatcher: dispatcher,
      groupFingerprint: groupConfig.fingerprint,
      onClose: (_) {},
    );
    addTearDown(dispatcher.close);

    final client = await Client.login(
      config: getClientConfig(0),
      api: api,
      store: InMemoryClientStorage(),
      getPrivateKey: (_) async => getPrivkey(0),
    );

    expect(handler.debugState.clientSessions.values, hasLength(1));
    await client.logout();
    await api.close();
    expect(handler.debugState.clientSessions.values, isEmpty);
  });

  test('local API rejects a client for another group', () async {
    final dispatcher = IrohDispatcher.single(getApiHandler());
    final api = LocalCoordinatorApi.attach(
      dispatcher: dispatcher,
      groupFingerprint: groupConfig.fingerprint,
      onClose: (_) {},
    );
    addTearDown(api.close);
    addTearDown(dispatcher.close);

    expect(
      () =>
          api.login(groupFingerprint: Uint8List(32), participantId: ids.first),
      throwsA(isA<InvalidRequest>()),
    );
  });

  test('local API fetches a caller-scoped DKG snapshot', () async {
    final handler = getApiHandler();
    final dispatcher = IrohDispatcher.single(handler);
    final api = LocalCoordinatorApi.attach(
      dispatcher: dispatcher,
      groupFingerprint: groupConfig.fingerprint,
      onClose: (_) {},
    );
    addTearDown(api.close);
    addTearDown(dispatcher.close);

    final challenge = await api.login(
      groupFingerprint: groupConfig.fingerprint,
      participantId: ids.first,
    );
    final login = await api.respondToChallenge(
      Signed.sign(obj: challenge.challenge, key: getPrivkey(0)),
    );
    final details = getDkgDetails(name: 'local-fetch');
    await api.requestNewDkg(
      sid: login.id,
      signedDetails: signObject(details),
      commitment: getDkgPart1(0).public,
    );

    final snapshot = (await api.getDkg(
      sid: login.id,
      name: details.name,
      ceremonyId: details.ceremonyId,
    ))!;
    expect(snapshot.stage, DkgCeremonyStage.collectingCommitments);
    expect(snapshot.commitments.single.$1, ids.first);
    expect(snapshot.shares, isEmpty);
  });

  test('cannot attach to a group the server does not host', () async {
    final dispatcher = IrohDispatcher.single(getApiHandler());
    addTearDown(dispatcher.close);

    expect(
      () => LocalCoordinatorApi.attach(
        dispatcher: dispatcher,
        groupFingerprint: Uint8List(32),
        onClose: (_) {},
      ),
      throwsA(isA<UnknownIrohGroupException>()),
    );
  });
}

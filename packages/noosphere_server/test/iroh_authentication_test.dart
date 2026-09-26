@TestOn('vm')
library;

import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/server/state/state.dart';
import 'package:test/test.dart';

import 'data.dart';

void main() {
  setUpAll(() async {
    await loadFrosty();
    await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  });

  late ServerApiHandler api;
  late IrohDispatcher dispatcher;

  setUp(() {
    api = getApiHandler();
    dispatcher = IrohDispatcher.single(api);
  });
  tearDown(() => dispatcher.close());

  ConnectionContext connection(int id) => ConnectionContext(
    connectionId: id,
    remoteEndpointId: SecretKey.generate().publicKey,
  );

  Future<ExpirableAuthChallengeResponse> begin(
    ConnectionContext context, [
    int participant = 0,
  ]) => dispatcher.beginAuthentication(
    groupFingerprint: groupConfig.fingerprint,
    participantId: ids[participant],
    connection: context,
  );

  Signed<AuthChallenge> sign(AuthChallenge challenge, [int participant = 0]) =>
      Signed.sign(obj: challenge, key: getPrivkey(participant));

  test(
    'challenge response is bound to the connection that requested it',
    () async {
      final first = connection(1);
      final second = connection(2);
      final challenge = await begin(first);

      await expectLater(
        dispatcher.completeAuthentication(
          groupFingerprint: groupConfig.fingerprint,
          connection: second,
          signedChallenge: sign(challenge.challenge),
        ),
        throwsA(isA<InvalidRequest>()),
      );

      await dispatcher.completeAuthentication(
        groupFingerprint: groupConfig.fingerprint,
        connection: first,
        signedChallenge: sign(challenge.challenge),
      );
      expect(first.phase, IrohConnectionPhase.authenticated);
      expect(first.participantId, ids.first);
      expect(second.phase, IrohConnectionPhase.connected);
    },
  );

  test('authentication does not replace an existing logical session', () async {
    final legacyChallenge = await api.login(
      groupFingerprint: groupConfig.fingerprint,
      participantId: ids.first,
    );
    final existing = await api.respondToChallenge(
      sign(legacyChallenge.challenge),
    );
    final context = connection(1);
    final challenge = await begin(context);

    await dispatcher.completeAuthentication(
      groupFingerprint: groupConfig.fingerprint,
      connection: context,
      signedChallenge: sign(challenge.challenge),
    );

    expect(api.debugState.clientSessions[existing.id], isNotNull);
    expect(context.sessionId, isNull);

    final replacement = await dispatcher.startSession(
      groupFingerprint: groupConfig.fingerprint,
      connection: context,
    );
    final replacementId = replacement.domainSessionId;

    expect(api.debugState.clientSessions[existing.id], isNull);
    expect(api.debugState.clientSessions[replacementId], isNotNull);
    expect(context.sessionId, replacementId);
    expect(context.phase, IrohConnectionPhase.sessionAttached);
  });

  test('expired and already consumed challenges cannot be reused', () async {
    final expiredContext = connection(1);
    final expired = await begin(expiredContext);
    api.debugState.challenges[expired.challenge] = ChallengeDetails(
      id: ids.first,
      expiry: Expiry(const Duration(seconds: -1)),
    );

    await expectLater(
      dispatcher.completeAuthentication(
        groupFingerprint: groupConfig.fingerprint,
        connection: expiredContext,
        signedChallenge: sign(expired.challenge),
      ),
      throwsA(isA<InvalidRequest>()),
    );

    final context = connection(2);
    final valid = await begin(context);
    final signed = sign(valid.challenge);
    await dispatcher.completeAuthentication(
      groupFingerprint: groupConfig.fingerprint,
      connection: context,
      signedChallenge: signed,
    );
    await expectLater(
      dispatcher.completeAuthentication(
        groupFingerprint: groupConfig.fingerprint,
        connection: context,
        signedChallenge: signed,
      ),
      throwsA(isA<InvalidRequest>()),
    );
  });

  test('invalid signature does not authenticate the connection', () async {
    final context = connection(1);
    final challenge = await begin(context);

    await expectLater(
      dispatcher.completeAuthentication(
        groupFingerprint: groupConfig.fingerprint,
        connection: context,
        signedChallenge: sign(challenge.challenge, 1),
      ),
      throwsA(isA<InvalidRequest>()),
    );

    expect(context.phase, IrohConnectionPhase.challengeIssued);
    expect(context.sessionId, isNull);
  });
}

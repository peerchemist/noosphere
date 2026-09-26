@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_client/testing.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/server/state/dkg.dart';
import 'package:test/test.dart';

import 'context.dart';
import 'data.dart';
import 'helpers.dart';
import 'sig_data.dart';
import 'test_keys.dart';

void main() {
  setUpAll(() async {
    await loadFrosty();
    await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  });

  test('client logs in, receives session events, and logs out', () async {
    final handler = getApiHandler();
    final server = await IrohServer.start(
      IrohConfig(
        server: serverConfig,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
      handler: handler,
      secretKey: SecretKey.generate(),
      persistence: newServerPersistence(),
    );
    unawaited(server.serve());
    addTearDown(server.close);

    final api = await IrohClientApi.connect(
      IrohClientTransportConfig(
        bootstrapAddress: EndpointAddr(
          server.id,
          ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
        ),
        pinnedServerId: server.id,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
    );
    addTearDown(api.close);

    final challenge = await api.login(
      groupFingerprint: groupConfig.fingerprint,
      participantId: ids.first,
    );
    final login = await api.respondToChallenge(
      Signed.sign(obj: challenge.challenge, key: getPrivkey(0)),
    );
    final received = Completer<Event>();
    final extended = Completer<Expiry>();
    final subscription = login.events.listen((event) async {
      if (!received.isCompleted) received.complete(event);
      try {
        final expiry = await api.extendSession(login.id);
        if (!extended.isCompleted) extended.complete(expiry);
      } catch (error, stackTrace) {
        if (!extended.isCompleted) {
          extended.completeError(error, stackTrace);
        }
      }
    });
    handler.debugState.sendEventToAll(KeepaliveEvent());

    expect(
      await received.future.timeout(const Duration(seconds: 2)),
      isA<KeepaliveEvent>(),
    );
    expect(
      (await extended.future.timeout(const Duration(seconds: 2))).isExpired,
      isFalse,
    );
    expect(handler.debugState.clientSessions[login.id], isNotNull);

    await api.logout();
    await waitFor(() => handler.debugState.clientSessions[login.id] == null);
    await subscription.cancel();
  });

  test('server disconnect completes a waiting event stream', () async {
    final persistence = newServerPersistence();
    final server = await IrohServer.start(
      IrohConfig(
        server: serverConfig,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
      secretKey: SecretKey.generate(),
      persistence: persistence,
    );
    unawaited(server.serve());
    final api = await IrohClientApi.connect(
      IrohClientTransportConfig(
        bootstrapAddress: EndpointAddr(
          server.id,
          ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
        ),
        pinnedServerId: server.id,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
    );
    addTearDown(api.close);
    final challenge = await api.login(
      groupFingerprint: groupConfig.fingerprint,
      participantId: ids.first,
    );
    final login = await api.respondToChallenge(
      Signed.sign(obj: challenge.challenge, key: getPrivkey(0)),
    );
    final completed = login.events.drain<void>().catchError((_) {});

    await server.close();

    await completed.timeout(const Duration(seconds: 2));
  });

  test('runtime reconnects with a new session and snapshot', () async {
    final secretKey = SecretKey.generate();
    final handler = getApiHandler();
    final serverConfigWithIdentity = IrohConfig(
      server: serverConfig,
      relay: IrohRelayConfig.disabled(),
      nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
    );
    var server = await IrohServer.start(
      serverConfigWithIdentity,
      handler: handler,
      secretKey: secretKey,
      persistence: handler.persistence,
    );
    unawaited(server.serve());

    final runtime = await ReconnectingIrohClient.connect(
      clientConfig: getClientConfig(0),
      transportConfig: IrohClientTransportConfig(
        bootstrapAddress: EndpointAddr(
          server.id,
          ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
        ),
        pinnedServerId: server.id,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
      store: InMemoryClientStorage(),
      getPrivateKey: (_) async => getPrivkey(0),
      reconnectConfig: const IrohReconnectConfig(
        initialDelay: Duration(milliseconds: 500),
        maxDelay: Duration(seconds: 1),
        jitter: 0,
      ),
    );

    final oldClient = runtime.current;
    final oldSession = handler.debugState.participantToSession[ids[0]]!;
    handler.debugState.nameToDkg['after-disconnect'] = DkgState(
      details: signObject(getDkgDetails(name: 'after-disconnect'), 1),
      creator: ids[1],
      commitments: [],
    );

    final nextSession = runtime.sessions.first;
    await server.close();
    server = await IrohServer.start(
      serverConfigWithIdentity,
      handler: handler,
      secretKey: secretKey,
      persistence: handler.persistence,
    );
    unawaited(server.serve());
    runtime.updateTransportConfig(
      IrohClientTransportConfig(
        bootstrapAddress: EndpointAddr(
          server.id,
          ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
        ),
        pinnedServerId: server.id,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
    );
    final newClient = await nextSession.timeout(const Duration(seconds: 5));
    final newSession = handler.debugState.participantToSession[ids[0]]!;

    expect(newClient, isNot(same(oldClient)));
    expect(runtime.current, same(newClient));
    expect(runtime.isConnected, isTrue);
    expect(newSession.sessionID, isNot(oldSession.sessionID));
    expect(handler.debugState.clientSessions[oldSession.sessionID], isNull);
    expect(
      newClient.dkgRequests.map((request) => request.details.name),
      contains('after-disconnect'),
    );
    await runtime.close().timeout(const Duration(seconds: 3));
    await server.close().timeout(const Duration(seconds: 3));
  });

  test('client limits concurrent RPC streams', () async {
    final handler = BlockingExtendSessionApi();
    final server = await IrohServer.start(
      IrohConfig(
        server: serverConfig,
        relay: IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
      handler: handler,
      secretKey: SecretKey.generate(),
      persistence: handler.persistence,
    );
    unawaited(server.serve());
    addTearDown(server.close);
    final api = await IrohClientApi.connect(
      IrohClientTransportConfig(
        bootstrapAddress: EndpointAddr(
          server.id,
          ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
        ),
        pinnedServerId: server.id,
        relay: IrohRelayConfig.disabled(),
        maxConcurrentStreams: 1,
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
    );
    addTearDown(api.close);
    final challenge = await api.login(
      groupFingerprint: groupConfig.fingerprint,
      participantId: ids[0],
    );
    final login = await api.respondToChallenge(
      Signed.sign(obj: challenge.challenge, key: getPrivkey(0)),
    );

    final first = api.extendSession(login.id);
    await handler.entered.future;
    final second = api.extendSession(login.id);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(handler.calls, 1);
    expect(handler.maxActive, 1);

    handler.release.complete();
    await Future.wait([first, second]);
    expect(handler.calls, 2);
    expect(handler.maxActive, 1);
  });

  test('server enforces connection and stream limits', () async {
    final handler = BlockingExtendSessionApi();
    final server = await IrohServer.start(
      IrohConfig(
        server: serverConfig,
        relay: IrohRelayConfig.disabled(),
        maxConnections: 1,
        maxStreamsPerConnection: 2,
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
      handler: handler,
      secretKey: SecretKey.generate(),
      persistence: handler.persistence,
    );
    unawaited(server.serve());
    addTearDown(server.close);
    IrohClientTransportConfig clientConfig({int streams = 2}) =>
        IrohClientTransportConfig(
          bootstrapAddress: EndpointAddr(
            server.id,
            ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
          ),
          pinnedServerId: server.id,
          relay: IrohRelayConfig.disabled(),
          rpcTimeout: const Duration(seconds: 1),
          maxConcurrentStreams: streams,
          nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
        );

    final api = await IrohClientApi.connect(clientConfig());
    addTearDown(api.close);
    final challenge = await api.login(
      groupFingerprint: groupConfig.fingerprint,
      participantId: ids[0],
    );
    final login = await api.respondToChallenge(
      Signed.sign(obj: challenge.challenge, key: getPrivkey(0)),
    );

    await expectLater(() async {
      final secondApi = await IrohClientApi.connect(clientConfig(streams: 1));
      try {
        await secondApi.login(
          groupFingerprint: groupConfig.fingerprint,
          participantId: ids[1],
        );
      } finally {
        await secondApi.close();
      }
    }, throwsA(anything));

    final first = api.extendSession(login.id);
    await handler.entered.future;
    final rejected = api.extendSession(login.id);
    await expectLater(rejected, throwsA(anything));
    expect(handler.calls, 1);
    handler.release.complete();
    await first;
  });

  test(
    'server times out a partial frame and shuts down a blocked RPC',
    () async {
      final handler = BlockingExtendSessionApi();
      final server = await IrohServer.start(
        IrohConfig(
          server: serverConfig,
          relay: IrohRelayConfig.disabled(),
          authTimeout: const Duration(milliseconds: 100),
          rpcTimeout: const Duration(milliseconds: 100),
          shutdownTimeout: const Duration(seconds: 2),
          nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
        ),
        handler: handler,
        secretKey: SecretKey.generate(),
        persistence: handler.persistence,
      );
      unawaited(server.serve());

      final rawEndpoint = await Endpoint.bind(relayMode: RelayMode.disabled);
      final rawConnection = await rawEndpoint.connect(
        EndpointAddr(
          server.id,
          ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
        ),
        noosphereIrohAlpn.codeUnits,
      );
      final (partialSend, partialReceive) = await rawConnection.openBi();
      await partialSend.writeAll([0, 0]);
      expect(
        await partialReceive
            .read(64 * 1024)
            .timeout(const Duration(seconds: 1)),
        isNotNull,
      );
      rawConnection.close(reason: 'partial frame tested'.codeUnits);
      await rawEndpoint.close();

      final api = await IrohClientApi.connect(
        IrohClientTransportConfig(
          bootstrapAddress: EndpointAddr(
            server.id,
            ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
          ),
          pinnedServerId: server.id,
          relay: IrohRelayConfig.disabled(),
          rpcTimeout: const Duration(seconds: 1),
          nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
        ),
      );
      final challenge = await api.login(
        groupFingerprint: groupConfig.fingerprint,
        participantId: ids[0],
      );
      final login = await api.respondToChallenge(
        Signed.sign(obj: challenge.challenge, key: getPrivkey(0)),
      );
      final blocked = api.extendSession(login.id);
      await handler.entered.future;

      final closing = server.close();
      await expectLater(blocked, throwsA(anything));
      await expectLater(
        closing.timeout(const Duration(seconds: 5)),
        throwsA(isA<TimeoutException>()),
      );
      handler.release.complete();
      await api.close();
    },
  );

  final domainRpcViaRelay =
      Platform.environment['IROH_INTEGRATION_RELAY'] == '1';
  test('client maps domain RPCs over Iroh '
      '${domainRpcViaRelay ? 'relay-only bootstrap' : 'directly'}', () async {
    final handler = getApiHandler();
    final server = await IrohServer.start(
      IrohConfig(
        server: serverConfig,
        relay: domainRpcViaRelay
            ? IrohRelayConfig.defaultNetwork()
            : IrohRelayConfig.disabled(),
        nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
      ),
      handler: handler,
      secretKey: SecretKey.generate(),
      persistence: handler.persistence,
    );
    unawaited(server.serve());
    addTearDown(server.close);
    final bootstrapAddress = domainRpcViaRelay
        ? await _relayOnlyAddress(server.endpoint)
        : EndpointAddr(
            server.id,
            ipAddrs: _loopbackAddresses(server.endpoint.boundSockets),
          );

    Future<(IrohClientApi, LoginCompleteResponse, EventCollector<Event>)> login(
      int i,
    ) async {
      final api = await IrohClientApi.connect(
        IrohClientTransportConfig(
          bootstrapAddress: bootstrapAddress,
          pinnedServerId: server.id,
          relay: domainRpcViaRelay
              ? IrohRelayConfig.defaultNetwork()
              : IrohRelayConfig.disabled(),
          nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
        ),
      );
      addTearDown(api.close);
      final challenge = await api.login(
        groupFingerprint: groupConfig.fingerprint,
        participantId: ids[i],
      );
      final response = await api.respondToChallenge(
        Signed.sign(obj: challenge.challenge, key: getPrivkey(i)),
      );
      final events = EventCollector<Event>(response.events);
      addTearDown(events.cancel);
      return (api, response, events);
    }

    final (api0, login0, events0) = await login(0);
    final (api1, login1, events1) = await login(1);
    await events0.getEvents();
    await events1.getEvents();

    final details = signObject(getDkgDetails(name: 'iroh-dkg'));
    final part0 = getDkgPart1(0);
    final part1 = getDkgPart1(1);
    await api0.requestNewDkg(
      sid: login0.id,
      signedDetails: details,
      commitment: part0.public,
    );
    final requestEvent = await events1.getExpectOneEvent<NewDkgEvent>();
    expect(requestEvent.details.toBytes(), details.toBytes());
    expect(requestEvent.creator, ids[0]);

    await api1.submitDkgCommitment(
      sid: login1.id,
      name: details.obj.name,
      commitment: part1.public,
    );
    final commitmentEvent = await events0
        .getExpectOneEvent<DkgCommitmentEvent>();
    expect(commitmentEvent.participant, ids[1]);
    expect(commitmentEvent.commitment.toBytes(), part1.public.toBytes());

    await api1.rejectDkg(sid: login1.id, name: details.obj.name);
    final rejectionEvent = await events0.getExpectOneEvent<DkgRejectEvent>();
    expect(rejectionEvent.name, details.obj.name);
    expect(rejectionEvent.participant, ids[1]);

    final parts = List.generate(10, getDkgPart1);
    final commitmentSet = DkgCommitmentSet(
      List.generate(10, (i) => (ids[i], parts[i].public)),
    );
    final part2 = DkgPart2(
      identifier: ids[0],
      round1Secret: parts[0].secret,
      commitments: commitmentSet,
    );
    final secrets = {
      for (var i = 1; i < 10; i++)
        ids[i]: DkgEncryptedSecret.encrypt(
          secretShare: part2.sharesToGive[ids[i]]!,
          recipientKey: getPrivkey(i).pubkey,
          senderKey: getPrivkey(0),
        ),
    };
    handler.debugState.nameToDkg['iroh-round2'] = DkgState(
      details: signObject(getDkgDetails(name: 'iroh-round2')),
      creator: ids[0],
      commitments: const [],
    )..round = DkgRound2State(expectedHash: commitmentSet.hash);

    final commitmentSetSignature = coinlib.SchnorrSignature.sign(
      getPrivkey(0),
      commitmentSet.hash,
    );
    await api0.submitDkgRound2(
      sid: login0.id,
      name: 'iroh-round2',
      commitmentSetSignature: commitmentSetSignature,
      secrets: secrets,
    );
    final round2Event = await events1.getExpectOneEvent<DkgRound2ShareEvent>();
    expect(round2Event.sender, ids[0]);
    expect(
      round2Event.commitmentSetSignature.data,
      commitmentSetSignature.data,
    );
    expect(
      round2Event.secret.ciphertext.toBytes(),
      secrets[ids[1]]!.ciphertext.toBytes(),
    );

    final ack = getDkgAck(0, true);
    await api0.sendDkgAcks(sid: login0.id, acks: {ack});
    final ackEvent = await events1.getExpectOneEvent<DkgAckEvent>();
    expect(ackEvent.acks, {ack});

    final found = await api1.requestDkgAcks(
      sid: login1.id,
      requests: {
        DkgAckRequest(ids: {ids[0], ids[2]}, groupPublicKey: groupPublicKey),
      },
    );
    expect(found, {ack});
    final ackRequestEvent = await events0
        .getExpectOneEvent<DkgAckRequestEvent>();
    expect(ackRequestEvent.requests.single.ids, {ids[2]});

    final keyInfos = generateNewKey(2);
    final signatureDetails = SignaturesRequestDetails(
      requiredSigs: [
        SingleSignatureDetails(
          signDetails: SignDetails.scriptSpend(message: Uint8List(32)),
          groupKey: keyInfos.first.groupKey,
          hdDerivation: const [],
        ),
      ],
      expiry: futureExpiry,
    );
    final signedSignatureDetails = Signed.sign(
      obj: signatureDetails,
      key: getPrivkey(0),
    );
    final part1s = [
      SignPart1(privateShare: keyInfos[0].private.share),
      SignPart1(privateShare: keyInfos[1].private.share),
    ];
    await api0.requestSignatures(
      sid: login0.id,
      keys: {keyInfos.first.aggregate},
      signedDetails: signedSignatureDetails,
      commitments: [part1s[0].commitment],
    );
    final signatureRequest = await events1
        .getExpectOneEvent<SignaturesRequestEvent>();
    expect(
      signatureRequest.details.toBytes(),
      signedSignatureDetails.toBytes(),
    );

    final roundResponse = await api1.submitSignatureReplies(
      sid: login1.id,
      reqId: signatureDetails.id,
      replies: [SignatureReply(sigI: 0, nextCommitment: part1s[1].commitment)],
    );
    expect(roundResponse, isA<SignatureNewRoundsResponse>());
    final round = (roundResponse as SignatureNewRoundsResponse).rounds.single;
    final roundEvent = await events0
        .getExpectOneEvent<SignatureNewRoundsEvent>();
    expect(roundEvent.reqId, signatureDetails.id);
    expect(roundEvent.rounds.single.toBytes(), round.toBytes());

    SignatureReply shareReply(int i) {
      final next = SignPart1(privateShare: keyInfos[i].private.share);
      final share = SignPart2(
        identifier: ids[i],
        details: signatureDetails.requiredSigs.single.signDetails,
        ourNonces: part1s[i].nonces,
        commitments: round.commitments,
        info: keyInfos[i].signing,
      ).share;
      return SignatureReply(
        sigI: 0,
        nextCommitment: next.commitment,
        share: share,
      );
    }

    expect(
      await api0.submitSignatureReplies(
        sid: login0.id,
        reqId: signatureDetails.id,
        replies: [shareReply(0)],
      ),
      isNull,
    );
    final completeResponse = await api1.submitSignatureReplies(
      sid: login1.id,
      reqId: signatureDetails.id,
      replies: [shareReply(1)],
    );
    expect(completeResponse, isA<SignaturesCompleteResponse>());
    final signature =
        (completeResponse as SignaturesCompleteResponse).signatures.single;
    expect(
      signature.verify(
        keyInfos.first.groupKey,
        signatureDetails.requiredSigs.single.signDetails.message,
      ),
      isTrue,
    );
    final completeEvent = await events0
        .getExpectOneEvent<SignaturesCompleteEvent>();
    expect(completeEvent.signatures.single.data, signature.data);

    final rejectedDetails = SignaturesRequestDetails(
      requiredSigs: [
        SingleSignatureDetails(
          signDetails: getSignDetails(1),
          groupKey: keyInfos.first.groupKey,
          hdDerivation: const [],
        ),
      ],
      expiry: futureExpiry,
    );
    await api0.requestSignatures(
      sid: login0.id,
      keys: {keyInfos.first.aggregate},
      signedDetails: Signed.sign(obj: rejectedDetails, key: getPrivkey(0)),
      commitments: [
        SignPart1(privateShare: keyInfos[0].private.share).commitment,
      ],
    );
    await events1.getExpectOneEvent<SignaturesRequestEvent>();
    await api1.rejectSignaturesRequest(
      sid: login1.id,
      reqId: rejectedDetails.id,
    );
    expect(
      handler.debugState.sigRequests[rejectedDetails.id]!.rejectors,
      contains(ids[1]),
    );

    final encryptedShare = EncryptedKeyShare.encrypt(
      keyShare: getPrivkey(2),
      recipientKey: getPrivkey(1).pubkey,
      senderKey: getPrivkey(0),
    );
    expect(
      await api0.shareSecretShare(
        sid: login0.id,
        groupKey: groupPublicKey,
        encryptedSecrets: {ids[1]: encryptedShare},
      ),
      isEmpty,
    );
    final secretShareEvent = await events1
        .getExpectOneEvent<SecretShareEvent>();
    expect(secretShareEvent.sender, ids[0]);
    expect(secretShareEvent.groupKey, groupPublicKey);
    expect(
      secretShareEvent.keyShare.ciphertext.toBytes(),
      encryptedShare.ciphertext.toBytes(),
    );

    final constructed = Signed.sign(
      obj: KeyWasConstructed(groupPublicKey),
      key: getPrivkey(1),
    );
    await api1.ackKeyConstructed(sid: login1.id, constructedKey: constructed);
    final constructedEvent = await events0
        .getExpectOneEvent<ConstructedKeyEvent>();
    expect(constructedEvent.participant, ids[1]);
    expect(constructedEvent.constructedKey.toBytes(), constructed.toBytes());

    final cachedConstructed = await api0.shareSecretShare(
      sid: login0.id,
      groupKey: groupPublicKey,
      encryptedSecrets: {ids[1]: encryptedShare},
    );
    expect(cachedConstructed, hasLength(1));
    expect(cachedConstructed.single.toBytes(), constructedEvent.toBytes());

    await expectLater(
      () => api0.rejectDkg(sid: login1.id, name: 'foreign-session'),
      throwsA(isA<IrohProtocolException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<EndpointAddr> _relayOnlyAddress(Endpoint endpoint) async {
  var address = endpoint.addr;
  if (address.relayUrls.isEmpty) {
    address = await endpoint
        .watchAddr()
        .firstWhere((candidate) => candidate.relayUrls.isNotEmpty)
        .timeout(const Duration(seconds: 30));
  }
  return EndpointAddr(endpoint.id, relayUrls: address.relayUrls);
}

List<String> _loopbackAddresses(List<String> boundAddresses) =>
    boundAddresses.map((address) {
      final separator = address.lastIndexOf(':');
      final host = address.substring(0, separator);
      final port = address.substring(separator + 1);
      return host.startsWith('[') || host.contains(':')
          ? '[::1]:$port'
          : '127.0.0.1:$port';
    }).toList();

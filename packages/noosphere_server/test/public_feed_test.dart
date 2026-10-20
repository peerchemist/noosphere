@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/wire.dart' as wire;
import 'package:noosphere_client/public_feed.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/server/state/public_feed.dart';
import 'package:noosphere_server/src/server/state/state.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'data.dart';
import 'sig_data.dart';

ServerConfig _config(PublicFeedConfig? feed) => ServerConfig(
  group: GroupConfig(
    id: 'feed-test',
    participants: {
      ids[0]: groupConfig.participants[ids[0]]!,
      ids[1]: groupConfig.participants[ids[1]]!,
    },
  ),
  minDkgRequestTTL: const Duration(milliseconds: 1),
  minSignaturesRequestTTL: const Duration(milliseconds: 1),
  publicFeed: feed,
);

Future<SessionID> _login(ServerApiHandler handler, int i) async {
  final challenge = await handler.login(
    groupFingerprint: handler.config.group.fingerprint,
    participantId: ids[i],
  );
  final session = await handler.respondToChallenge(
    signObject(challenge.challenge, i),
  );
  // Drain the signer event stream. Public polling never opens one.
  unawaited(session.events.drain<void>());
  return session.id;
}

NewDkgDetails _dkgDetails(
  ServerApiHandler handler,
  String name, {
  Expiry? expiry,
}) => getDkgDetails(
  name: name,
  expiry: expiry,
  groupFingerprint: handler.config.group.fingerprint,
);

Future<void> _dkg(
  ServerApiHandler handler,
  SessionID sid,
  String name, {
  Expiry? expiry,
}) => handler.requestNewDkg(
  sid: sid,
  signedDetails: signObject(_dkgDetails(handler, name, expiry: expiry)),
  commitment: DkgPart1(identifier: ids[0], threshold: 2, n: 2).public,
);

EndpointAddr _address(IrohServer server) => EndpointAddr(
  server.id,
  ipAddrs: server.endpoint.boundSockets.map((address) {
    final split = address.lastIndexOf(':');
    return address.startsWith('[')
        ? '[::1]${address.substring(split)}'
        : '127.0.0.1${address.substring(split)}';
  }).toList(),
);

Future<IrohServer> _serve(
  ServerApiHandler handler, {
  SecretKey? identity,
  int maxMessageLength = wire.defaultMaxMessageLength,
}) async {
  final server = await IrohServer.start(
    IrohConfig(
      server: handler.config,
      relay: IrohRelayConfig.disabled(),
      maxMessageLength: maxMessageLength,
      nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
    ),
    secretKey: identity ?? SecretKey.generate(),
    persistence: handler.persistence,
    handler: handler,
  );
  unawaited(server.serve());
  addTearDown(server.close);
  return server;
}

Future<PublicFeedClient> _connect(IrohServer server) async {
  final client = await PublicFeedClient.connect(
    _address(server),
    server.id,
    relay: IrohRelayConfig.disabled(),
    nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
  );
  addTearDown(client.close);
  return client;
}

void main() {
  setUpAll(() async {
    await loadFrosty();
    await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  });

  test(
    'one public connection routes independent groups only by opaque feed ID',
    () async {
      final firstId = PublicFeedId.generate();
      final secondId = PublicFeedId.generate();
      final first = ServerApiHandler(
        config: _config(PublicFeedConfig(feedId: firstId)),
        persistence: InMemoryServerPersistence(),
      );
      final firstSid = await _login(first, 0);
      await _dkg(first, firstSid, 'first-private-name');
      final second = ServerApiHandler(
        config: ServerConfig(
          group: GroupConfig(
            id: 'second-private-group',
            participants: first.config.group.participants,
          ),
          publicFeed: PublicFeedConfig(feedId: secondId),
        ),
        persistence: InMemoryServerPersistence(),
      );
      final secondSid = await _login(second, 0);
      await _dkg(second, secondSid, 'second-private-name');
      final server = await _serve(first);
      server.dispatcher.addHandler(second);
      final client = await _connect(server);
      final firstPage = await client.fetch(firstId);
      final secondPage = await client.fetch(secondId);
      expect(firstPage.feedId, firstId);
      expect(secondPage.feedId, secondId);
      expect(firstPage.entries.single.cursor, 1);
      expect(secondPage.entries.single.cursor, 1);
      expect(
        firstPage.entries.single.eventId,
        isNot(secondPage.entries.single.eventId),
      );
      final duplicate = ServerApiHandler(
        config: ServerConfig(
          group: GroupConfig(
            id: 'third-private-group',
            participants: first.config.group.participants,
          ),
          publicFeed: PublicFeedConfig(feedId: firstId),
        ),
        persistence: InMemoryServerPersistence(),
      );
      expect(
        () => server.dispatcher.addHandler(duplicate),
        throwsArgumentError,
      );
      await first.shutdown();
      await second.shutdown();
    },
  );

  test('terminal IDs survive pruning of their requested entries', () async {
    final id = PublicFeedId.generate();
    final handler = ServerApiHandler(
      config: _config(PublicFeedConfig(feedId: id, maxEntries: 1)),
      persistence: InMemoryServerPersistence(),
    );
    final sid = await _login(handler, 0);
    await _dkg(handler, sid, 'pending-a');
    final eventId = (await handler.getPublicFeed(
      id,
      0,
      100,
    ))!.entries.single.eventId;
    await _dkg(handler, sid, 'pending-b');
    await handler.rejectDkg(
      sid: sid,
      name: 'pending-a',
      ceremonyId: _dkgDetails(handler, 'pending-a').ceremonyId,
    );
    final page = (await handler.getPublicFeed(id, 0, 100))!;
    expect(page.entries.single.cursor, 3);
    expect(page.entries.single.eventId, eventId);
    expect(page.entries.single.state, PublicFeedLifecycle.rejected);
    expect(page.historyGap, isTrue);
    await handler.shutdown();
  });

  test(
    'polling reads committed history while the protocol lane waits for a host',
    () async {
      final id = PublicFeedId.generate();
      final handler = ServerApiHandler(
        config: _config(PublicFeedConfig(feedId: id)),
        persistence: InMemoryServerPersistence(),
      );
      final server = await _serve(handler);
      final client = await _connect(server);
      final entered = Completer<void>();
      final release = Completer<void>();
      final blocked = server.dispatcher.invokeGroup(
        groupFingerprint: handler.config.group.fingerprint,
        operation: (_) async {
          entered.complete();
          await release.future;
        },
      );
      try {
        await entered.future;
        final page = await client.fetch(id);
        expect(page.entries, isEmpty);
        expect(
          server.dispatcher.pendingFor(handler.config.group.fingerprint),
          1,
        );
        expect(handler.debugState.clientSessions.values, isEmpty);
      } finally {
        release.complete();
        await blocked;
      }
    },
  );

  test('unauthenticated ephemeral polling needs no keys or storage and changes no presence or state', () async {
    final id = PublicFeedId.generate();
    final handler = ServerApiHandler(
      config: _config(PublicFeedConfig(feedId: id)),
      persistence: InMemoryServerPersistence(),
    );
    final server = await _serve(handler);
    final before = handler.state.toBytes();
    // This constructor accepts only public connection information. No signer
    // callback, client config, participant identity, or storage is supplied.
    final client = await _connect(server);
    final page = await client.fetch(id);
    expect(page.entries, isEmpty);
    expect(page.latestCursor, 0);
    expect(page.oldestAvailableCursor, 1);
    expect(page.nextCursor, 0);
    expect(page.historyGap, isFalse);
    expect(page.hasMore, isFalse);
    expect(handler.debugState.clientSessions.values, isEmpty);
    expect(handler.debugState.participantToSession.values, isEmpty);
    expect(handler.debugState.challenges.values, isEmpty);
    expect(handler.state.toBytes(), before);
    final helper = File('test/public_feed_poll_helper.dart').existsSync()
        ? 'test/public_feed_poll_helper.dart'
        : 'packages/noosphere_server/test/public_feed_poll_helper.dart';
    final packageConfig = File('.dart_tool/package_config.json').existsSync()
        ? '.dart_tool/package_config.json'
        : '../../.dart_tool/package_config.json';
    final standalone = await Process.run(Platform.resolvedExecutable, [
      '--packages=$packageConfig',
      helper,
      base64Encode(_address(server).encode()),
      server.id.toHex(),
      id.hex,
    ]);
    expect(standalone.exitCode, 0, reason: standalone.stderr as String);
    expect(jsonDecode((standalone.stdout as String).trim()), {
      'entries': 0,
      'cursor': 0,
    });
    expect(handler.debugState.clientSessions.values, isEmpty);
    await client.close();
    await client.close();
    expect(client.isClosed, isTrue);
  });

  test('polling leaves an existing participant and DKG unchanged', () async {
    final id = PublicFeedId.generate();
    final handler = ServerApiHandler(
      config: _config(PublicFeedConfig(feedId: id)),
      persistence: InMemoryServerPersistence(),
    );
    final sid = await _login(handler, 0);
    await _dkg(handler, sid, 'private-dkg-name');
    final server = await _serve(handler);
    final session = handler.debugState.clientSessions[sid];
    final dkg = handler.debugState.nameToDkg['private-dkg-name'];
    final before = handler.state.toBytes();
    final client = await _connect(server);
    expect(
      (await client.fetch(id)).entries.single.category,
      PublicFeedCategory.dkg,
    );
    expect(handler.debugState.clientSessions.values, [session]);
    expect(handler.debugState.nameToDkg['private-dkg-name'], same(dkg));
    expect(handler.state.toBytes(), before);
    await handler.shutdown();
  });

  test(
    'public ALPN rejects every signer operation without a signer context',
    () async {
      final id = PublicFeedId.generate();
      final handler = ServerApiHandler(
        config: _config(PublicFeedConfig(feedId: id)),
        persistence: InMemoryServerPersistence(),
      );
      final server = await _serve(handler);
      final endpoint = await Endpoint.bind(relayMode: RelayMode.disabled);
      addTearDown(endpoint.close);
      final connection = await endpoint.connect(
        _address(server),
        noospherePublicFeedAlpn.codeUnits,
      );
      final before = handler.state.toBytes();
      for (final operation in wire.RoastOperation.values) {
        final (send, receive) = await connection.openBi();
        await send.writeAll([
          ...wire.encodeQuicVarInt(operation.id),
          if (operation == wire.RoastOperation.login)
            ...wire.LoginRequest(
              groupFingerprint: handler.config.group.fingerprint,
              participantId: ids[0].toBytes(),
              protocolVersion: 1,
            ).writeToBuffer(),
        ]);
        await send.finish();
        final reader = wire.QuicStreamReader(_chunks(receive));
        expect(await reader.readVarInt(), wire.RpcResponseStatus.error);
        final error = wire.ProtocolError.fromBuffer(await reader.readToEnd());
        expect(
          error.code,
          wire.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
        );
        await reader.cancel();
      }
      expect(handler.state.toBytes(), before);
      expect(handler.debugState.clientSessions.values, isEmpty);
      expect(handler.debugState.challenges.values, isEmpty);
    },
  );

  test(
    'disabled and unknown feeds have the same generic not-found response',
    () async {
      for (final enabled in [false, true]) {
        final id = PublicFeedId.generate();
        final handler = ServerApiHandler(
          config: _config(enabled ? PublicFeedConfig(feedId: id) : null),
          persistence: InMemoryServerPersistence(),
        );
        final server = await _serve(handler);
        final client = await _connect(server);
        await expectLater(
          client.fetch(enabled ? PublicFeedId.generate() : id),
          throwsA(
            isA<PublicFeedException>().having(
              (e) => e.code,
              'code',
              wire.ProtocolErrorCode.PROTOCOL_ERROR_NOT_FOUND,
            ),
          ),
        );
      }
    },
  );

  test('pin mismatch is rejected and altered entries/checkpoint metadata/signatures fail verification', () async {
    final id = PublicFeedId.generate();
    final handler = ServerApiHandler(
      config: _config(PublicFeedConfig(feedId: id)),
      persistence: InMemoryServerPersistence(),
    );
    final sid = await _login(handler, 0);
    await _dkg(handler, sid, 'tamper-test');
    final server = await _serve(handler);
    await expectLater(
      PublicFeedClient.connect(
        _address(server),
        SecretKey.generate().publicKey,
      ),
      throwsA(isA<Exception>()),
    );
    final checkpoint = await (await _connect(server)).fetchCheckpoint(id);
    expect(
      () => PublicFeedCheckpoint.verify([
        ...checkpoint.toBytes(),
        0x18,
        0x01,
      ], server.id),
      throwsFormatException,
    );
    expect(
      PublicFeedCheckpoint.verify(checkpoint.toBytes(), server.id).page.entries,
      hasLength(1),
    );
    for (final field in [
      'entry',
      'feed',
      'oldest',
      'latest',
      'generation',
      'version',
      'signature',
    ]) {
      final envelope = wire.SignedPublicFeedPage.fromBuffer(
        checkpoint.toBytes(),
      );
      final page = wire.PublicFeedPage.fromBuffer(envelope.page);
      switch (field) {
        case 'entry':
          page.entries.single.state = 'completed';
        case 'feed':
          page.feedId = PublicFeedId.generate().toBytes();
        case 'oldest':
          page.oldestAvailableCursor += 1;
        case 'latest':
          page.latestCursor += 1;
        case 'generation':
          page.generatedAtMs += 1;
        case 'version':
          page.schemaVersion++;
        case 'signature':
          envelope.signature = List<int>.from(envelope.signature)..[0] ^= 1;
      }
      envelope.page = page.writeToBuffer();
      expect(
        () => PublicFeedCheckpoint.verify(envelope.writeToBuffer(), server.id),
        throwsA(isA<Exception>()),
        reason: field,
      );
    }
    expect(
      () => PublicFeedCheckpoint.verify(
        checkpoint.toBytes(),
        SecretKey.generate().publicKey,
      ),
      throwsA(isA<Exception>()),
    );
    await handler.shutdown();
  });

  test('DKG and signing requested/terminal entries have stable IDs and ordered cursors; retries are idempotent', () async {
    final id = PublicFeedId.generate();
    final handler = ServerApiHandler(
      config: _config(PublicFeedConfig(feedId: id)),
      persistence: InMemoryServerPersistence(),
    );
    final sid0 = await _login(handler, 0);
    final sid1 = await _login(handler, 1);
    final details = signObject(_dkgDetails(handler, 'secret-description'));
    final parts = List.generate(
      2,
      (i) => DkgPart1(identifier: ids[i], threshold: 2, n: 2),
    );
    await handler.requestNewDkg(
      sid: sid0,
      signedDetails: details,
      commitment: parts[0].public,
    );
    await expectLater(
      handler.requestNewDkg(
        sid: sid0,
        signedDetails: details,
        commitment: parts[0].public,
      ),
      throwsA(isA<InvalidRequest>()),
    );
    await handler.submitDkgCommitment(
      sid: sid1,
      name: details.obj.name,
      ceremonyId: details.obj.ceremonyId,
      commitment: parts[1].public,
    );
    final commitments = DkgCommitmentSet(
      List.generate(2, (i) => (ids[i], parts[i].public)),
    );
    for (var i = 0; i < 2; i++) {
      final part2 = DkgPart2(
        identifier: ids[i],
        round1Secret: parts[i].secret,
        commitments: commitments,
      );
      final other = 1 - i;
      await handler.submitDkgRound2(
        sid: i == 0 ? sid0 : sid1,
        name: details.obj.name,
        ceremonyId: details.obj.ceremonyId,
        commitmentSetSignature: cl.SchnorrSignature.sign(
          getPrivkey(i),
          details.obj.hashWithCommitments(commitments),
        ),
        secrets: {
          ids[other]: DkgEncryptedSecret.encrypt(
            secretShare: part2.sharesToGive[ids[other]]!,
            protocolVersion: noosphereRoastProtocolVersion,
            ceremonyId: details.obj.ceremonyId,
            transcriptHash: details.obj.hashWithCommitments(commitments),
            sender: ids[i],
            recipient: ids[other],
            recipientKey: getPrivkey(other).pubkey,
            senderKey: getPrivkey(i),
          ),
        },
      );
    }
    for (var i = 0; i < 2; i++) {
      final ack = DkgAck(
        groupKey: getAggregateKeyInfo().groupKey,
        accepted: true,
        ceremonyId: details.obj.ceremonyId,
        transcriptHash: details.obj.hashWithCommitments(commitments),
      );
      await handler.sendDkgAcks(
        sid: i == 0 ? sid0 : sid1,
        acks: {
          SignedDkgAck(
            signer: ids[i],
            signed: Signed.sign(obj: ack, key: getPrivkey(i)),
          ),
        },
      );
    }
    final signing = signObject(getSignaturesDetails());
    final signParts = [getSignPart1(i: 0), getSignPart1(i: 1)];
    await handler.requestSignatures(
      sid: sid0,
      keys: {getAggregateKeyInfo()},
      signedDetails: signing,
      commitments: [signParts[0].commitment],
    );
    final rounds = await handler.submitSignatureReplies(
      sid: sid1,
      reqId: signing.obj.id,
      replies: [
        SignatureReply(sigI: 0, nextCommitment: signParts[1].commitment),
      ],
    ) as SignatureNewRoundsResponse;
    for (var i = 0; i < 2; i++) {
      final share = SignPart2(
        identifier: ids[i],
        details: signing.obj.requiredSigs.single.signDetails,
        ourNonces: signParts[i].nonces,
        commitments: rounds.rounds.single.commitments,
        info: getParticipantKeyInfo(i: i).signing,
      ).share;
      await handler.submitSignatureReplies(
        sid: i == 0 ? sid0 : sid1,
        reqId: signing.obj.id,
        replies: [
          SignatureReply(
            sigI: 0,
            nextCommitment: getSignPart1(i: i).commitment,
            share: share,
          ),
        ],
      );
    }
    await handler.submitSignatureReplies(
      sid: sid1,
      reqId: signing.obj.id,
      replies: [],
    );
    await handler.rejectDkg(
      sid: sid1,
      name: details.obj.name,
      ceremonyId: details.obj.ceremonyId,
    );
    final page = (await handler.getPublicFeed(id, 0, 100))!;
    expect(page.entries.map((e) => e.cursor), [1, 2, 3, 4]);
    expect(page.entries.map((e) => e.state), [
      PublicFeedLifecycle.requested,
      PublicFeedLifecycle.completed,
      PublicFeedLifecycle.requested,
      PublicFeedLifecycle.completed,
    ]);
    expect(page.entries[0].eventId, page.entries[1].eventId);
    expect(page.entries[2].eventId, page.entries[3].eventId);
    expect(page.entries[0].eventId, isNot(page.entries[2].eventId));
    expect(page.entries[2].eventId.toBytes(), isNot(signing.obj.id.toBytes()));
    await expectLater(
      handler.requestSignatures(
        sid: sid0,
        keys: {getAggregateKeyInfo()},
        signedDetails: signing,
        commitments: [getSignPart1().commitment],
      ),
      throwsA(isA<InvalidRequest>()),
    );
    expect((await handler.getPublicFeed(id, 0, 100))!.latestCursor, 4);
    await handler.shutdown();
  });

  test(
    'rejection and expiry produce terminal entries independently of polling',
    () async {
      final id = PublicFeedId.generate();
      final handler = ServerApiHandler(
        config: _config(PublicFeedConfig(feedId: id)),
        persistence: InMemoryServerPersistence(),
      );
      final sid = await _login(handler, 0);
      await _dkg(handler, sid, 'rejected');
      final rejectedId = _dkgDetails(handler, 'rejected').ceremonyId;
      await handler.rejectDkg(
        sid: sid,
        name: 'rejected',
        ceremonyId: rejectedId,
      );
      await handler.rejectDkg(
        sid: sid,
        name: 'rejected',
        ceremonyId: rejectedId,
      );
      final signing = signObject(getSignaturesDetails());
      await handler.requestSignatures(
        sid: sid,
        keys: {getAggregateKeyInfo()},
        signedDetails: signing,
        commitments: [getSignPart1().commitment],
      );
      await handler.rejectSignaturesRequest(sid: sid, reqId: signing.obj.id);
      await handler.rejectSignaturesRequest(sid: sid, reqId: signing.obj.id);
      await _dkg(
        handler,
        sid,
        'expired',
        expiry: Expiry(const Duration(milliseconds: 100)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      // Polling itself must not expire or remove the operation.
      expect((await handler.getPublicFeed(id, 0, 100))!.latestCursor, 5);
      expect(
        handler.debugState.persistent.publicFeed!.active,
        contains('dkg:expired'),
      );
      await handler.maintainPublicFeed();
      final page = (await handler.getPublicFeed(id, 0, 100))!;
      expect(page.entries.map((e) => e.state), [
        PublicFeedLifecycle.requested,
        PublicFeedLifecycle.rejected,
        PublicFeedLifecycle.requested,
        PublicFeedLifecycle.rejected,
        PublicFeedLifecycle.requested,
        PublicFeedLifecycle.expired,
      ]);
      await handler.maintainPublicFeed();
      expect((await handler.getPublicFeed(id, 0, 100))!.latestCursor, 6);
      await handler.shutdown();
    },
  );

  test(
    'restart preserves history and cancels interrupted operations exactly once',
    () async {
      final id = PublicFeedId.generate();
      final config = _config(PublicFeedConfig(feedId: id));
      final persistence = InMemoryServerPersistence();
      var handler = ServerApiHandler(config: config, persistence: persistence);
      final sid = await _login(handler, 0);
      await _dkg(handler, sid, 'restart');
      final signing = signObject(getSignaturesDetails());
      await handler.requestSignatures(
        sid: sid,
        keys: {getAggregateKeyInfo()},
        signedDetails: signing,
        commitments: [getSignPart1().commitment],
      );
      final before = (await handler.getPublicFeed(id, 0, 100))!;
      await handler.shutdown();
      for (var i = 0; i < 3; i++) {
        handler = ServerApiHandler(config: config, persistence: persistence);
        await handler.ready;
        final page = (await handler.getPublicFeed(id, 0, 100))!;
        expect(page.entries.map((e) => e.cursor), [1, 2, 3]);
        expect(
          page.entries.take(2).map((e) => e.eventId),
          before.entries.map((e) => e.eventId),
        );
        expect(page.entries.last.state, PublicFeedLifecycle.failed);
        expect(page.entries[1].eventId, page.entries[2].eventId);
      }
      final nextSid = await _login(handler, 0);
      await _dkg(handler, nextSid, 'new-after-restart');
      expect(
        (await handler.getPublicFeed(id, 3, 100))!.entries.single.cursor,
        4,
      );
      await handler.shutdown();
    },
  );

  test('pagination, server clamping, retention gaps, and entirely aged-out history', () async {
    final id = PublicFeedId.generate();
    final feed = PublicFeedConfig(feedId: id, maxEntries: 3);
    final handler = ServerApiHandler(
      config: _config(feed),
      persistence: InMemoryServerPersistence(),
    );
    final sid = await _login(handler, 0);
    for (var i = 0; i < 3; i++) {
      await _dkg(handler, sid, 'retained-$i');
      await handler.rejectDkg(
        sid: sid,
        name: 'retained-$i',
        ceremonyId: _dkgDetails(handler, 'retained-$i').ceremonyId,
      );
    }
    final page = (await handler.getPublicFeed(id, 0, 2))!;
    expect(page.entries.map((e) => e.cursor), [4, 5]);
    expect(page.oldestAvailableCursor, 4);
    expect(page.latestCursor, 6);
    expect(page.nextCursor, 5);
    expect(page.historyGap, isTrue);
    expect(page.hasMore, isTrue);
    final last = (await handler.getPublicFeed(id, page.nextCursor, 2))!;
    expect(last.entries.single.cursor, 6);
    expect(last.hasMore, isFalse);
    expect(last.historyGap, isFalse);
    expect((await handler.getPublicFeed(id, 6, 0))!.entries, isEmpty);
    expect((await handler.getPublicFeed(id, 0, -1))!.entries, hasLength(1));
    expect(
      (await handler.getPublicFeed(id, 0, 0xffffffff))!.entries,
      hasLength(3),
    );
    PublicFeedPage.fromBytes(page.toBytes());
    await handler.shutdown();

    final restored = ServerApiHandler(
      config: _config(
        PublicFeedConfig(
          feedId: id,
          maxEntries: 3,
          maxAge: const Duration(microseconds: 1),
        ),
      ),
      persistence: handler.persistence,
    );
    await restored.ready;
    final empty = (await restored.getPublicFeed(id, 0, 100))!;
    expect(empty.entries, isEmpty);
    expect(empty.oldestAvailableCursor, 7);
    expect(empty.latestCursor, 6);
    expect(empty.nextCursor, 6);
    expect(empty.historyGap, isTrue);
    expect(empty.hasMore, isFalse);
    PublicFeedPage.fromBytes(empty.toBytes());
    final nextSid = await _login(restored, 0);
    await _dkg(restored, nextSid, 'after-total-pruning');
    expect((await restored.getPublicFeed(id, 6, 100))!.latestCursor, 7);
    await restored.shutdown();
  });

  test(
    'page limit and byte budget apply on the wire, including hostile limits',
    () async {
      final id = PublicFeedId.generate();
      final feed = PublicFeedConfig(feedId: id);
      final state = ServerState();
      final journal = state.persistent.publicFeed = PublicFeedJournal(feed);
      for (var i = 0; i < 150; i++) {
        journal.requested(
          'dkg:$i',
          PublicFeedCategory.dkg,
          DateTime.now().add(const Duration(days: 1)),
        );
        journal.finish('dkg:$i', PublicFeedLifecycle.completed);
      }
      final handler = ServerApiHandler(
        config: _config(feed),
        persistence: InMemoryServerPersistence(),
        state: state,
      );
      final server = await _serve(handler);
      final checkpoint = await (await _connect(server))
          .fetchCheckpoint(id, limit: 1000000);
      expect(checkpoint.page.entries, hasLength(100));
      expect(checkpoint.toBytes().length, lessThan(publicFeedMaxResponseBytes));
      // Bypass the client-side clamp to prove the server also clamps.
      final endpoint = await Endpoint.bind(relayMode: RelayMode.disabled);
      addTearDown(endpoint.close);
      final connection = await endpoint.connect(
        _address(server),
        noospherePublicFeedAlpn.codeUnits,
      );
      final (send, receive) = await connection.openBi();
      await send.writeAll([
        ...wire.encodeQuicVarInt(1),
        ...wire.GetPublicFeedRequest(
          feedId: id.toBytes(),
          limit: 0xffffffff,
        ).writeToBuffer(),
      ]);
      await send.finish();
      final reader = wire.QuicStreamReader(_chunks(receive));
      expect(await reader.readVarInt(), wire.RpcResponseStatus.success);
      expect(
        PublicFeedCheckpoint.verify(
          await reader.readToEnd(),
          server.id,
        ).page.entries,
        hasLength(100),
      );
      await reader.cancel();
      final small = await _serve(handler, maxMessageLength: 256);
      await expectLater(
        (await _connect(small)).fetch(id),
        throwsA(
          isA<PublicFeedException>().having(
            (e) => e.code,
            'code',
            wire.ProtocolErrorCode.PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
          ),
        ),
      );
    },
  );

  test(
    'serialized public responses contain only the redaction allowlist',
    () async {
      final id = PublicFeedId.generate();
      final handler = ServerApiHandler(
        config: _config(PublicFeedConfig(feedId: id)),
        persistence: InMemoryServerPersistence(),
      );
      final sid = await _login(handler, 0);
      final details = signObject(
        getDkgDetails(
          name: 'PRIVATE_DKG_NAME',
          description: 'PRIVATE_PROPOSAL_CONTENT',
          groupFingerprint: handler.config.group.fingerprint,
        ),
      );
      final commitment = DkgPart1(
        identifier: ids[0],
        threshold: 2,
        n: 2,
      ).public;
      await handler.requestNewDkg(
        sid: sid,
        signedDetails: details,
        commitment: commitment,
      );
      final signing = signObject(
        SignaturesRequestDetails(
          requiredSigs: [getSingleSigDetails()],
          expiry: futureExpiry,
          message: 'PRIVATE_MESSAGE_PAYLOAD',
        ),
      );
      await handler.requestSignatures(
        sid: sid,
        keys: {getAggregateKeyInfo()},
        signedDetails: signing,
        commitments: [getSignPart1().commitment],
      );
      final server = await _serve(handler);
      final bytes = (await (await _connect(server)).fetchCheckpoint(id))
          .toBytes();
      final envelope = wire.SignedPublicFeedPage.fromBuffer(bytes);
      final page = wire.PublicFeedPage.fromBuffer(envelope.page);
      final json = page.toProto3Json() as Map<String, dynamic>;
      expect(
        json.keys.toSet().difference({
          'schemaVersion',
          'feedId',
          'entries',
          'oldestAvailableCursor',
          'latestCursor',
          'nextCursor',
          'hasMore',
          'historyGap',
          'generatedAtMs',
          'afterCursor',
        }),
        isEmpty,
      );
      for (final entry in page.entries) {
        expect((entry.toProto3Json() as Map).keys.toSet(), {
          'cursor',
          'eventId',
          'category',
          'state',
          'observedAtMs',
          'expiresAtMs',
        });
      }
      for (final forbidden in <List<int>>[
        utf8.encode('PRIVATE_DKG_NAME'),
        utf8.encode('PRIVATE_PROPOSAL_CONTENT'),
        utf8.encode('PRIVATE_MESSAGE_PAYLOAD'),
        utf8.encode(handler.config.group.id),
        handler.config.group.fingerprint,
        details.toBytes(),
        signing.toBytes(),
        signing.obj.id.toBytes(),
        commitment.toBytes(),
        ...ids.take(2).map((v) => v.toBytes()),
        ...handler.config.group.participants.values.map((v) => v.data),
      ]) {
        expect(_contains(bytes, forbidden), isFalse);
      }
      await handler.shutdown();
    },
  );

  test(
    'snapshots without a feed allow explicit opt-in without ID rotation',
    () async {
      final persistence = InMemoryServerPersistence();
      final config = _config(null);
      final empty = ServerStateSnapshot.fromBytes(
        Uint8List.fromList(
          utf8.encode(
            '{"version":${ServerStateSnapshot.currentVersion},"dkg":[],"signing":[],"completed":[],"shares":[],"cancelled":[],"terminalSigning":[],"terminalDkg":[]}',
          ),
        ),
      );
      await persistence.write(config.group.id, empty);
      final old = ServerApiHandler(config: config, persistence: persistence);
      await old.ready;
      expect(old.debugState.persistent.publicFeed, isNull);
      final id = PublicFeedId.generate();
      expect(await old.getPublicFeed(id, 0, 100), isNull);
      final enabled = ServerApiHandler(
        config: _config(PublicFeedConfig(feedId: id)),
        persistence: persistence,
      );
      await enabled.ready;
      expect((await enabled.getPublicFeed(id, 0, 100))!.entries, isEmpty);
      expect(
        (jsonDecode(utf8.decode(enabled.state.toBytes()))
            as Map)['publicFeed']['feedId'],
        id.hex,
      );
      final disabled = ServerApiHandler(
        config: config,
        persistence: persistence,
      );
      await disabled.ready;
      expect(await disabled.getPublicFeed(id, 0, 100), isNull);
      final rotated = ServerApiHandler(
        config: _config(PublicFeedConfig(feedId: PublicFeedId.generate())),
        persistence: persistence,
      );
      await expectLater(rotated.ready, throwsStateError);
    },
  );

  test(
    'failed atomic writes cannot expose uncommitted journal entries',
    () async {
      for (final commitBeforeFailure in [false, true]) {
        final id = PublicFeedId.generate();
        final persistence = _FailingPersistence()
          ..commitBeforeFailure = commitBeforeFailure;
        final handler = ServerApiHandler(
          config: _config(PublicFeedConfig(feedId: id)),
          persistence: persistence,
        );
        final sid = await _login(handler, 0);
        final before = handler.state.toBytes();
        persistence.fail = true;
        await expectLater(_dkg(handler, sid, 'failed'), throwsStateError);
        expect(handler.state.toBytes(), before);
        expect(await handler.getPublicFeed(id, 0, 100), isNull);
        final restored = ServerApiHandler(
          config: handler.config,
          persistence: persistence.delegate,
        );
        await restored.ready;
        final page = (await restored.getPublicFeed(id, 0, 100))!;
        expect(page.latestCursor, commitBeforeFailure ? 1 : 0);
        if (commitBeforeFailure) {
          expect(page.entries.map((e) => e.state), [
            PublicFeedLifecycle.requested,
          ]);
          final recoveredAgain = ServerApiHandler(
            config: handler.config,
            persistence: persistence.delegate,
          );
          expect(
            (await recoveredAgain.getPublicFeed(id, 0, 100))!.latestCursor,
            1,
          );
        } else {
          expect(page.entries, isEmpty);
        }
      }
    },
  );

  test('in-flight snapshots stay private and overlapping host writes commit in order', () async {
    final id = PublicFeedId.generate();
    final persistence = _GatedPersistence();
    final handler = ServerApiHandler(
      config: _config(PublicFeedConfig(feedId: id)),
      persistence: persistence,
    );
    final sid = await _login(handler, 0);
    persistence.blockNext = true;
    final creation = _dkg(handler, sid, 'overlap');
    await persistence.entered.future;
    expect((await handler.getPublicFeed(id, 0, 100))!.entries, isEmpty);
    final rejection = handler.rejectDkg(
      sid: sid,
      name: 'overlap',
      ceremonyId: _dkgDetails(handler, 'overlap').ceremonyId,
    );
    await pumpEventQueue();
    expect(persistence.writes, 2); // Initial snapshot and the blocked creation.
    expect((await handler.getPublicFeed(id, 0, 100))!.entries, isEmpty);
    persistence.release.complete();
    await Future.wait([creation, rejection]);
    final restored = ServerApiHandler(
      config: handler.config,
      persistence: persistence.delegate,
    );
    await restored.ready;
    expect(
      (await restored.getPublicFeed(id, 0, 100))!.entries.map((e) => e.state),
      [PublicFeedLifecycle.requested, PublicFeedLifecycle.rejected],
    );
    await handler.shutdown();
  });
}

final class _FailingPersistence implements ServerPersistence {
  final delegate = InMemoryServerPersistence();
  bool fail = false;
  bool commitBeforeFailure = false;
  @override
  Future<ServerStateSnapshot?> load(String groupId) => delegate.load(groupId);
  @override
  Future<void> write(String groupId, ServerStateSnapshot state) async {
    if (fail && !commitBeforeFailure) {
      throw StateError('simulated storage failure');
    }
    await delegate.write(groupId, state);
    if (fail) throw StateError('simulated uncertain storage outcome');
  }
}

final class _GatedPersistence implements ServerPersistence {
  final delegate = InMemoryServerPersistence();
  bool blockNext = false;
  int writes = 0;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<ServerStateSnapshot?> load(String groupId) => delegate.load(groupId);
  @override
  Future<void> write(String groupId, ServerStateSnapshot state) async {
    writes++;
    if (blockNext) {
      blockNext = false;
      entered.complete();
      await release.future;
    }
    await delegate.write(groupId, state);
  }
}

Stream<List<int>> _chunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(4096);
    if (chunk == null) return;
    yield chunk;
  }
}

bool _contains(List<int> bytes, List<int> needle) {
  for (var i = 0; i <= bytes.length - needle.length; i++) {
    var found = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        found = false;
        break;
      }
    }
    if (found) return true;
  }
  return false;
}

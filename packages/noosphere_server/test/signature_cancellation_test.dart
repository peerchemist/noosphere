@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_client/testing.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/iroh/dispatcher.dart';
import 'package:noosphere_server/src/server/state/signatures_coordination.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'context.dart' show EventCollector;
import 'data.dart';
import 'helpers.dart';

void main() {
  final keys = <int, List<ParticipantKeyInfo>>{};
  setUpAll(() async {
    await loadFrosty();
    for (final n in [2, 3]) {
      final first = [
        for (var i = 0; i < n; i++)
          DkgPart1(identifier: ids[i], threshold: 2, n: n),
      ];
      final commitments = DkgCommitmentSet([
        for (var i = 0; i < n; i++) (ids[i], first[i].public),
      ]);
      final second = [
        for (var i = 0; i < n; i++)
          DkgPart2(
            identifier: ids[i],
            round1Secret: first[i].secret,
            commitments: commitments,
          ),
      ];
      keys[n] = [
        for (var i = 0; i < n; i++)
          DkgPart3(
            identifier: ids[i],
            round2Secret: second[i].secret,
            commitments: commitments,
            receivedShares: {
              for (var j = 0; j < n; j++)
                if (i != j) ids[j]: second[j].sharesToGive[ids[i]]!,
            },
          ).participantInfo,
      ];
    }
  });

  Future<_Fixture> fixture(
    int n, {
    ServerPersistence? persistence,
    bool loseResponse = false,
  }) async {
    final value = _Fixture(
      keys[n]!,
      persistence ?? InMemoryServerPersistence(),
      loseResponse,
    );
    addTearDown(value.close);
    for (var i = 0; i < n; i++) {
      await value.login(i);
    }
    return value;
  }

  for (final n in [2, 3]) {
    test(
      'creator unilaterally cancels 2-of-$n; atomic cleanup, idempotency, replay and feed',
      () async {
        final f = await fixture(n);
        final request = f.request();
        await f.clients[0]!.requestSignatures(request);
        await waitFor(() => f.clients[1]!.signaturesRequests.isNotEmpty);
        // Keep a pending round, commitment, malicious marker and rejection in
        // the coordinator to ensure cancellation removes the entire object.
        final active = f.handler.debugState.sigRequests[request.id]!;
        final signature = active.sigs.single as SingleSignatureInProgressState;
        final parts = [
          for (final key in f.keys.take(2))
            SignPart1(privateShare: key.private.share),
        ];
        final round = SignatureRoundState(
          SigningCommitmentSet({
            for (var i = 0; i < 2; i++) ids[i]: parts[i].commitment,
          }),
        );
        round.shares.add((
          ids.first,
          SignPart2(
            identifier: ids.first,
            details: request.requiredSigs.single.signDetails,
            ourNonces: parts.first.nonces,
            commitments: round.commitments,
            info: f.keys.first.signing,
          ).share,
        ));
        for (final id in ids.take(2)) {
          signature.roundForId[id] = round;
        }
        active.malicious.add(ids[n - 1]);
        active.rejectors.add(ids[1]);
        final prepared = PreparedSignaturesOperation(
          id: request.id,
          kind: PreparedSignaturesOperationKind.replies,
          payloads: [request.toBytes()],
          transcripts: [Uint8List(32)],
          nextNonces: SignaturesNonces({
            0: SignPart1(privateShare: f.keys.first.private.share).nonces,
          }, request.expiry),
        );
        await f.stores.first.prepareSignaturesOperation(prepared, 1);
        await f.stores[1].addRejectedSigsRequest(
          request.id,
          FinalExpirable(request.expiry),
        );
        for (final collector in f.collectors.values) {
          await collector.getEvents();
        }

        expect(
          await f.clients[0]!.cancelSignaturesRequest(request.id),
          CancelSignaturesRequestResult.cancelled,
        );
        await waitFor(
          () => f.stores.every(
            (s) => s.cancelledRequests.containsKey(request.id),
          ),
        );
        expect(f.handler.debugState.sigRequests.values, isEmpty);
        expect(f.handler.debugState.persistent.blockedSignatures, isEmpty);
        for (var i = 0; i < n; i++) {
          expect(f.clients[i]!.signaturesRequests, isEmpty);
          final state = await f.stores[i].loadState();
          expect(state.sigNonces, isEmpty);
          expect(state.preparedOperations, isEmpty);
          expect(state.rejectedRequests, isEmpty);
          expect(state.cancelledRequests.keys, [request.id]);
          final tombstone = state.cancelledRequests.values.single;
          expect(tombstone.toBytes(), [
            ...request.id.toBytes(),
            ...request.expiry.toBytes(),
          ]);
          expect(
            await f.collectors[i]!.getEvents(),
            contains(isA<SignaturesCancelledClientEvent>()),
          );
        }
        final root = jsonDecode(utf8.decode(f.handler.state.toBytes())) as Map;
        expect(root['signing'], isEmpty);
        expect(root['completed'], isEmpty);
        expect(root['terminalSigning'], isEmpty);
        expect(root['cancelled'], [
          base64Encode(
            CancelledSignaturesRequest(request.id, request.expiry).toBytes(),
          ),
        ]);
        expect(
          utf8.decode(f.handler.state.toBytes()),
          isNot(contains(base64Encode(request.toBytes()))),
        );

        expect(
          await f.clients[0]!.cancelSignaturesRequest(request.id),
          CancelSignaturesRequestResult.alreadyCancelled,
        );
        expect(
          await f.clients[1]!.cancelSignaturesRequest(request.id),
          CancelSignaturesRequestResult.alreadyCancelled,
        );
        for (final collector in f.collectors.values) {
          expect(
            (await collector.getEvents())
                .whereType<SignaturesCancelledClientEvent>(),
            isEmpty,
          );
        }
        await expectLater(
          f.clients[0]!.requestSignatures(request),
          throwsArgumentError,
        );
        await expectLater(
          f.handler.requestSignatures(
            sid: f.sid(0),
            keys: {f.keys.first.aggregate},
            signedDetails: signObject(request),
            commitments: [
              SignPart1(privateShare: f.keys.first.private.share).commitment,
            ],
          ),
          throwsA(isA<InvalidRequest>()),
        );
        expect(
          await f.handler.submitSignatureReplies(
            sid: f.sid(1),
            reqId: request.id,
            replies: [],
          ),
          isNull,
        );
        await f.handler.rejectSignaturesRequest(
          sid: f.sid(1),
          reqId: request.id,
        );

        final page = (await f.handler.getPublicFeed(f.feedId, 0, 100))!;
        expect(page.entries.map((e) => e.state), [
          PublicFeedLifecycle.requested,
          PublicFeedLifecycle.cancelled,
        ]);
        expect(page.entries.first.eventId, page.entries.last.eventId);
        expect(f.handler.debugState.persistent.publicFeed!.active, isEmpty);
      },
    );
  }

  test(
    'non-creator cannot cancel and unknown ID creates no tombstone',
    () async {
      final f = await fixture(3);
      final request = f.request();
      await f.clients[0]!.requestSignatures(request);
      final before = f.handler.state.toBytes();
      await expectLater(
        f.clients[1]!.cancelSignaturesRequest(request.id),
        throwsA(isA<InvalidRequest>()),
      );
      expect(f.handler.state.toBytes(), before);
      expect(f.handler.debugState.sigRequests[request.id], isNotNull);
      final unknown = SignaturesRequestId.fromBytes(Uint8List(16));
      expect(
        await f.clients[0]!.cancelSignaturesRequest(unknown),
        CancelSignaturesRequestResult.notFound,
      );
      expect(
        f.handler.debugState.persistent.cancelledSignatures.values,
        isEmpty,
      );
    },
  );

  test('lost response is unknown; reconnect reconciles and retry returns already cancelled', () async {
    final f = await fixture(3, loseResponse: true);
    final request = f.request();
    await f.clients[0]!.requestSignatures(request);
    await expectLater(
      f.clients[0]!.cancelSignaturesRequest(request.id),
      throwsA(isA<TimeoutException>()),
    );
    expect(
      f.handler.debugState.persistent.cancelledSignatures[request.id],
      isNotNull,
    );
    await f.logout(0);
    await f.login(0);
    expect(f.clients[0]!.signaturesRequests, isEmpty);
    expect(
      f.clients[0]!.cancelledSignaturesRequests.single.requestId,
      request.id,
    );
    expect(
      await f.clients[0]!.cancelSignaturesRequest(request.id),
      CancelSignaturesRequestResult.alreadyCancelled,
    );
  });

  test('offline client and unseen request reconcile through snapshot; coordinator and client restart', () async {
    final f = await fixture(3);
    final request = f.request();
    await f.clients[0]!.requestSignatures(request);
    await waitFor(() => f.clients[1]!.signaturesRequests.isNotEmpty);
    final coordinatorRequest = f.handler.debugState.sigRequests[request.id]!;
    final staleSnapshotRequest = SignaturesRequestEvent(
      details: coordinatorRequest.details,
      creator: coordinatorRequest.creator,
      progress: coordinatorRequest.progress,
    );
    final stale = f.clients[1]!;
    await f.logout(1);
    await f.logout(2);
    // Participant 1 has retained nonce material; participant 2's fresh storage
    // represents a signer which never received the original proposal.
    await f.stores[1].addSignaturesNonces(
      request.id,
      SignaturesNonces({
        0: SignPart1(privateShare: f.keys[1].private.share).nonces,
      }, request.expiry),
      1,
    );
    f.stores[2] = InMemoryClientStorage()
      ..keys[f.keys[2].groupKey] = FrostKeyWithDetails(
        keyInfo: f.keys[2],
        name: 'key',
        description: '',
        ceremonyId: Uint8List(32),
        transcriptHash: Uint8List(32),
      );
    await f.clients[0]!.cancelSignaturesRequest(request.id);
    expect(stale.signaturesRequests, isNotEmpty);
    await f.restartCoordinator(stale: staleSnapshotRequest);
    for (final i in [1, 2]) {
      await f.login(i);
      expect(f.clients[i]!.signaturesRequests, isEmpty);
      expect(
        f.clients[i]!.cancelledSignaturesRequests.single.requestId,
        request.id,
      );
      expect(f.stores[i].sigNonces, isEmpty);
      expect(
        await f.collectors[i]!.getEvents(),
        contains(isA<SignaturesCancelledClientEvent>()),
      );
    }
    await f.logout(1);
    await f.login(1);
    expect(
      f.clients[1]!.cancelledSignaturesRequests.single.requestId,
      request.id,
    );
    expect(
      (await f.handler.getPublicFeed(f.feedId, 0, 100))!.entries,
      hasLength(2),
    );
  });

  test('delayed request, round, progress and failure cannot revive cancellation; completion is misbehaviour', () async {
    final f = await fixture(3);
    final request = f.request();
    await f.clients[0]!.requestSignatures(request);
    final active = f.handler.debugState.sigRequests[request.id]!;
    final staleEvent = SignaturesRequestEvent(
      details: active.details,
      creator: ids.first,
      progress: active.progress,
    );
    await f.clients[0]!.cancelSignaturesRequest(request.id);
    await waitFor(() => f.stores[1].cancelledRequests.containsKey(request.id));
    await f.collectors[1]!.getEvents();
    final session = f.handler.debugState.participantToSession[ids[1]]!;
    for (final event in <Event>[
      staleEvent,
      SignatureNewRoundsEvent(reqId: request.id, rounds: []),
      SignaturesProgressEvent(
        reqId: request.id,
        progress: SignaturesProgress(
          threshold: 100,
          contributingParticipants: [],
          stage: SignaturesProgressStage.collecting,
        ),
      ),
      SignaturesFailureEvent(request.id),
      SignaturesCancelledEvent(
        requestId: request.id,
        expiresAt: request.expiry,
      ),
    ]) {
      session.sendEvent(event);
    }
    expect(await f.collectors[1]!.getEvents(), isEmpty);
    expect(await f.collectors[1]!.getErrors(), isEmpty);
    expect(f.stores[1].sigNonces, isEmpty);
    session.sendEvent(
      SignaturesCompleteEvent(reqId: request.id, signatures: [dummySig]),
    );
    expect(
      await f.collectors[1]!.getErrors(),
      contains(isA<ServerMisbehaviour>()),
    );
    expect(f.stores[1].cancelledRequests, contains(request.id));
  });

  test(
    'completion wins in the serialized lane and cannot be cancelled',
    () async {
      final f = await fixture(3);
      final request = f.request();
      await f.clients[0]!.requestSignatures(request);
      await waitFor(() => f.clients[1]!.signaturesRequests.isNotEmpty);
      await f.clients[1]!.acceptSignaturesRequest(request.id);
      await waitFor(
        () => f.handler.debugState.completedSigs.containsKey(request.id),
      );
      final completed = f.handler.debugState.completedSigs[request.id]!;
      expect(
        await f.clients[0]!.cancelSignaturesRequest(request.id),
        CancelSignaturesRequestResult.alreadyCompleted,
      );
      expect(
        identical(f.handler.debugState.completedSigs[request.id], completed),
        isTrue,
      );
      expect(
        f.handler.debugState.persistent.cancelledSignatures.values,
        isEmpty,
      );
      expect(
        (await f.handler.getPublicFeed(f.feedId, 0, 100))!.entries.last.state,
        PublicFeedLifecycle.completed,
      );
      await f.restartCoordinator();
      await f.login(0);
      expect(
        await f.clients[0]!.cancelSignaturesRequest(request.id),
        CancelSignaturesRequestResult.alreadyCompleted,
      );
    },
  );

  for (final rejected in [true, false]) {
    test(
      '${rejected ? 'rejection' : 'failure'} wins and survives restart',
      () async {
        final f = await fixture(2);
        final request = f.request();
        await f.clients[0]!.requestSignatures(request);
        if (rejected) {
          await f.handler.rejectSignaturesRequest(
            sid: f.sid(1),
            reqId: request.id,
          );
        } else {
          await expectLater(
            f.handler.submitSignatureReplies(
              sid: f.sid(1),
              reqId: request.id,
              replies: [],
            ),
            throwsA(isA<InvalidRequest>()),
          );
        }
        expect(
          await f.clients[0]!.cancelSignaturesRequest(request.id),
          CancelSignaturesRequestResult.alreadyTerminal,
        );
        expect(
          f.handler.debugState.persistent.cancelledSignatures.values,
          isEmpty,
        );
        expect(
          (await f.handler.getPublicFeed(f.feedId, 0, 100))!.entries.last.state,
          rejected ? PublicFeedLifecycle.rejected : PublicFeedLifecycle.failed,
        );
        await f.restartCoordinator();
        await f.login(0);
        expect(
          await f.clients[0]!.cancelSignaturesRequest(request.id),
          CancelSignaturesRequestResult.alreadyTerminal,
        );
      },
    );
  }

  for (final committed in [false, true]) {
    test(
      'unknown persistence outcome (committed=$committed) broadcasts nothing and blocks processing',
      () async {
        final persistence = _FailingPersistence()
          ..commitBeforeFailure = committed;
        final f = await fixture(3, persistence: persistence);
        final request = f.request();
        await f.clients[0]!.requestSignatures(request);
        for (final collector in f.collectors.values) {
          await collector.getEvents();
        }
        final before = f.handler.state.toBytes();
        persistence.fail = true;
        await expectLater(
          f.handler.cancelSignaturesRequest(sid: f.sid(0), reqId: request.id),
          throwsStateError,
        );
        expect(f.handler.state.toBytes(), before);
        for (final collector in f.collectors.values) {
          expect(
            (await collector.getEvents())
                .whereType<SignaturesCancelledClientEvent>(),
            isEmpty,
          );
        }
        await expectLater(
          f.handler.submitSignatureReplies(
            sid: f.sid(1),
            reqId: request.id,
            replies: [],
          ),
          throwsStateError,
        );
        await expectLater(
          f.handler.cancelSignaturesRequest(sid: f.sid(0), reqId: request.id),
          throwsStateError,
        );
        persistence.fail = false;
        await f.restartCoordinator();
        await f.login(0);
        expect(
          await f.clients[0]!.cancelSignaturesRequest(request.id),
          committed
              ? CancelSignaturesRequestResult.alreadyCancelled
              : CancelSignaturesRequestResult.alreadyTerminal,
        );
      },
    );
  }

  for (final cancellationFirst in [true, false]) {
    test(
      'serialized race: ${cancellationFirst ? 'cancellation' : 'completion'} commits first',
      () async {
        final persistence = _GatedPersistence();
        final f = await fixture(3, persistence: persistence);
        addTearDown(() {
          if (!persistence.release.isCompleted) persistence.release.complete();
        });
        final request = f.request();
        await f.clients[0]!.requestSignatures(request);
        await waitFor(() => f.clients[1]!.signaturesRequests.isNotEmpty);
        for (final collector in f.collectors.values) {
          await collector.getEvents();
        }
        persistence.gateField = cancellationFirst ? 'cancelled' : 'completed';
        late Future<CancelSignaturesRequestResult> cancellation;
        late Future<void> acceptance;
        if (cancellationFirst) {
          cancellation = f.clients[0]!.cancelSignaturesRequest(request.id);
          await persistence.entered.future.timeout(const Duration(seconds: 2));
          acceptance = f.clients[1]!.acceptSignaturesRequest(request.id);
        } else {
          acceptance = f.clients[1]!.acceptSignaturesRequest(request.id);
          await persistence.entered.future.timeout(const Duration(seconds: 2));
          cancellation = f.clients[0]!.cancelSignaturesRequest(request.id);
        }
        // A transition waiting for durable persistence cannot emit cancellation.
        for (final collector in f.collectors.values) {
          expect(
            (await collector.getEvents())
                .whereType<SignaturesCancelledClientEvent>(),
            isEmpty,
          );
        }
        persistence.release.complete();
        expect(
          await cancellation,
          cancellationFirst
              ? CancelSignaturesRequestResult.cancelled
              : CancelSignaturesRequestResult.alreadyCompleted,
        );
        await acceptance;
        expect(
          f.handler.debugState.persistent.cancelledSignatures.containsKey(
            request.id,
          ),
          cancellationFirst,
        );
        expect(
          f.handler.debugState.completedSigs.containsKey(request.id),
          !cancellationFirst,
        );
      },
    );
  }

  test('coordinator prunes tombstones after original expiry without public-feed mutation', () async {
    final f = await fixture(2);
    final request = f.request();
    await f.clients[0]!.requestSignatures(request);
    await f.clients[0]!.cancelSignaturesRequest(request.id);
    f.handler.debugState.persistent.cancelledSignatures[request.id] =
        CancelledSignaturesRequest(
          request.id,
          Expiry(const Duration(seconds: -1)),
        );
    await f.handler.maintainPublicFeed();
    expect(
      (jsonDecode(utf8.decode(f.handler.state.toBytes())) as Map)['cancelled'],
      isEmpty,
    );
    expect(
      (await f.handler.getPublicFeed(f.feedId, 0, 100))!.entries,
      hasLength(2),
    );
  });
}

final class _Fixture(this.keys, this.persistence, this.loseResponse) {
  final List<ParticipantKeyInfo> keys;
  final ServerPersistence persistence;
  final bool loseResponse;
  final feedId = PublicFeedId.generate();
  late final group = GroupConfig(
    id: 'cancel-${keys.length}',
    participants: {
      for (var i = 0; i < keys.length; i++)
        ids[i]: groupConfig.participants[ids[i]]!,
    },
  );
  late final config = ServerConfig(
    group: group,
    publicFeed: PublicFeedConfig(feedId: feedId),
  );
  late ServerApiHandler handler = loseResponse
      ? _LostResponseHandler(config: config, persistence: persistence)
      : ServerApiHandler(config: config, persistence: persistence);
  late IrohDispatcher dispatcher = IrohDispatcher.single(handler);
  late final stores = [
    for (final key in keys)
      InMemoryClientStorage()
        ..keys[key.groupKey] = FrostKeyWithDetails(
          keyInfo: key,
          name: 'key',
          description: '',
          ceremonyId: Uint8List(32),
          transcriptHash: Uint8List(32),
        ),
  ];
  final clients = <int, Client>{};
  final apis = <int, LocalCoordinatorApi>{};
  final collectors = <int, EventCollector<ClientEvent>>{};

  Future<void> login(int i) async {
    final api = apis[i] = LocalCoordinatorApi.attach(
      dispatcher: dispatcher,
      groupFingerprint: group.fingerprint,
      onClose: (_) {},
    );
    final client = clients[i] = await Client.login(
      config: ClientConfig(id: ids[i], group: group),
      api: api,
      store: stores[i],
      getPrivateKey: (_) async => getPrivkey(i),
    );
    collectors[i] = EventCollector<ClientEvent>(client.events);
  }

  SessionID sid(int i) =>
      handler.debugState.participantToSession[ids[i]]!.sessionID;

  SignaturesRequestDetails request() => SignaturesRequestDetails.forMessage(
    text: 'Sensitive message that must be deleted',
    message: 'Sensitive explanation',
    groupKey: keys.first.groupKey,
    expiry: Expiry(const Duration(minutes: 2)),
  );

  Future<void> logout(int i) async {
    await clients.remove(i)?.logout();
    await apis.remove(i)?.close();
    collectors.remove(i)?.cancel();
  }

  Future<void> restartCoordinator({SignaturesRequestEvent? stale}) async {
    for (final i in clients.keys.toList()) {
      await logout(i);
    }
    await dispatcher.close();
    handler = stale == null
        ? ServerApiHandler(config: config, persistence: persistence)
        : _StaleSnapshotHandler(
            stale,
            config: config,
            persistence: persistence,
          );
    await handler.ready;
    dispatcher = IrohDispatcher.single(handler);
  }

  Future<void> close() async {
    for (final i in clients.keys.toList()) {
      await logout(i);
    }
    await dispatcher.close();
  }
}

final class _FailingPersistence implements ServerPersistence {
  final delegate = InMemoryServerPersistence();
  bool fail = false;
  bool commitBeforeFailure = false;
  @override
  Future<ServerStateSnapshot?> load(String groupId) => delegate.load(groupId);
  @override
  Future<void> write(String groupId, ServerStateSnapshot state) async {
    if (!fail || commitBeforeFailure) await delegate.write(groupId, state);
    if (fail) throw StateError('Unknown durable write outcome');
  }
}

final class _GatedPersistence implements ServerPersistence {
  final delegate = InMemoryServerPersistence();
  String? gateField;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<ServerStateSnapshot?> load(String groupId) => delegate.load(groupId);
  @override
  Future<void> write(String groupId, ServerStateSnapshot state) async {
    final root = jsonDecode(utf8.decode(state.toBytes())) as Map;
    if (gateField case final field? when (root[field] as List).isNotEmpty) {
      gateField = null;
      entered.complete();
      await release.future;
    }
    await delegate.write(groupId, state);
  }
}

/// Deliberately contradictory snapshot records must lose to a tombstone before
/// validation, nonce allocation, or restoration of local decisions.
final class _StaleSnapshotHandler(
  this.stale, {
  required super.config,
  required super.persistence,
}) extends ServerApiHandler {
  final SignaturesRequestEvent stale;
  @override
  Future<LoginCompleteResponse> respondToChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) async {
    final snapshot = await super.respondToChallenge(signedChallenge);
    return LoginCompleteResponse(
      id: snapshot.id,
      expiry: snapshot.expiry,
      startTime: snapshot.startTime,
      onlineParticipants: snapshot.onlineParticipants,
      newDkgs: snapshot.newDkgs,
      sigRequests: [stale, stale],
      sigRounds: [
        SignatureNewRoundsEvent(reqId: stale.details.obj.id, rounds: []),
      ],
      completedSigs: snapshot.completedSigs,
      cancelledRequests: snapshot.cancelledRequests,
      secretShares: snapshot.secretShares,
      events: snapshot.events,
    );
  }
}

final class _LostResponseHandler({
  required super.config,
  required super.persistence,
}) extends ServerApiHandler {
  bool loseNext = true;
  @override
  Future<CancelSignaturesRequestResponse> cancelSignaturesRequest({
    required SessionID sid,
    required SignaturesRequestId reqId,
  }) async {
    final result = await super.cancelSignaturesRequest(sid: sid, reqId: reqId);
    if (loseNext) {
      loseNext = false;
      throw TimeoutException('RPC response lost after commit');
    }
    return result;
  }
}

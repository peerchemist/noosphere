import 'dart:async';
import 'dart:typed_data';

import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_client/testing.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:test/test.dart';

import 'context.dart';
import 'data.dart';
import 'helpers.dart';
import 'sig_data.dart';

void main() {
  late List<ParticipantKeyInfo> keys;
  late _SnapshotHandler handler;
  late TestClient creator;
  late TestClient peer;

  setUpAll(() async {
    await loadFrosty();
    keys = generateNewKey(2);
  });

  setUp(() async {
    handler = _SnapshotHandler();
    Future<TestClient> login(int i) async {
      final storage = InMemoryClientStorage();
      await storage.addOrReplaceFrostKey(
        FrostKeyWithDetails(
          keyInfo: keys[i],
          name: '2-of-10',
          description: '',
          ceremonyId: Uint8List(32),
          transcriptHash: Uint8List(32),
        ),
      );
      final client = await TestClient.login(handler, i, storage: storage);
      addTearDown(client.logout);
      return client;
    }

    creator = await login(0);
    peer = await login(1);
    await creator.expectOnlyLoginEvents();
    await peer.expectOnlyLoginEvents();
  });

  SignaturesRequestDetails request(String text) =>
      SignaturesRequestDetails.forMessage(
        text: text,
        groupKey: keys.first.groupKey,
        expiry: futureExpiry,
      );

  test(
    'recovers a missed request once and survives a stale snapshot',
    () async {
      final missed = request('missed request');
      final live = request('live request');
      final session = handler.debugState.participantToSession[ids[1]];
      handler.deliverToPeer = (event) =>
          event is! SignaturesRequestEvent || event.details.obj.id != missed.id;
      await creator.client.requestSignatures(missed);
      await creator.client.requestSignatures(live);
      final liveEvent = await peer.evCollector
          .getExpectOneEvent<SignaturesRequestClientEvent>();
      expect(liveEvent.request.details.id, live.id);

      final original = handler.debugState.sigRequests[missed.id]!.details;
      handler.deliverToPeer = (event) {
        if (event is SigningSnapshotEvent) {
          final proposal = event.requests.singleWhere(
            (request) => request.details.obj.id == missed.id,
          );
          expect(proposal.details.toBytes(), original.toBytes());
        }
        return true;
      };
      expect(await peer.client.syncSigningRequests(), isTrue);
      final recovered = await peer.evCollector
          .getExpectOneEvent<SignaturesRequestClientEvent>();
      expect(recovered.request.details.toBytes(), missed.toBytes());
      await peer.client.rejectSignaturesRequest(live.id);
      expect(await peer.client.syncSigningRequests(), isTrue);
      await peer.evCollector.expectNoEventsOrError();

      final captured = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      handler.deliverToPeer = (event) async {
        if (event is SigningSnapshotEvent) {
          expect(
            event.requests.map((request) => request.details.obj.id),
            contains(missed.id),
          );
          captured.complete();
          await release.future;
        }
        return true;
      };
      handler.creatorShare = Completer<void>();
      final sync = peer.client.syncSigningRequests();
      await captured.future;
      await peer.client.acceptSignaturesRequest(missed.id);
      final completed = await peer.evCollector
          .getExpectOneEvent<SignaturesCompleteClientEvent>();
      expect(completed.details.id, missed.id);
      expect(
        completed.signatures.single.verify(
          keys.first.groupKey,
          missed.requiredSigs.single.signDetails.message,
        ),
        isTrue,
      );

      release.complete();
      expect(await sync, isTrue);
      await peer.evCollector.expectNoEventsOrError();
      expect(peer.client.signaturesRequests.single.details.id, live.id);
      expect(
        peer.client.signaturesRequests.single.status,
        SignaturesRequestStatus.rejected,
      );
      expect(peer.store.sigNonces, isEmpty);
      expect(handler.debugState.participantToSession[ids[1]], same(session));
    },
  );

  test('retries a lost snapshot and recovers a missed cancellation', () async {
    final cancelled = request('cancelled proposal');
    await creator.client.requestSignatures(cancelled);
    await peer.evCollector.getExpectOneEvent<SignaturesRequestClientEvent>();
    handler.deliverToPeer = (event) =>
        event is! SignaturesCancelledEvent && event is! SigningSnapshotEvent;
    await creator.client.cancelSignaturesRequest(cancelled.id);

    final first = peer.client.syncSigningRequests(
      timeout: const Duration(milliseconds: 30),
    );
    expect(peer.client.syncSigningRequests(), same(first));
    await expectLater(first, throwsA(isA<TimeoutException>()));
    expect(peer.client.signaturesRequests.single.details.id, cancelled.id);

    handler.deliverToPeer = null;
    final acknowledgement = Completer<void>();
    handler.snapshotAcknowledgement = acknowledgement.future;
    expect(await peer.client.syncSigningRequests(), isTrue);
    acknowledgement.completeError(TimeoutException('RPC response lost'));

    expect(peer.client.signaturesRequests, isEmpty);
    expect(
      peer.client.cancelledSignaturesRequests.single.requestId,
      cancelled.id,
    );
    await peer.evCollector.getExpectOneEvent<SignaturesCancelledClientEvent>();
    await peer.evCollector.expectNoEventsOrError();
  });

  test(
    'a request that reached the local expiry stays expired after sync',
    () async {
      await peer.logout();
      final client = await Client.login(
        config: ClientConfig(
          group: groupConfig,
          id: ids[1],
          maxSignaturesTTL: const Duration(milliseconds: 200),
        ),
        api: handler,
        store: peer.store,
        getPrivateKey: (_) async => getPrivkey(1),
      );
      final events = ClientEventCollector(client.events);
      addTearDown(client.logout);

      final active = request('longer server expiry');
      await creator.client.requestSignatures(active);
      final incoming = await events
          .getExpectOneEvent<SignaturesRequestClientEvent>();
      await waitFor(() => incoming.request.expiry.isExpired);
      expect(handler.debugState.sigRequests.containsKey(active.id), isTrue);

      expect(await client.syncSigningRequests(), isTrue);
      await events.getExpectOneEvent<SignaturesExpiryClientEvent>();
      expect(client.signaturesRequests, isEmpty);
    },
  );
}

final class _SnapshotHandler extends ServerApiHandler {
  _SnapshotHandler()
    : super(config: serverConfig, persistence: newServerPersistence());

  FutureOr<bool> Function(Event)? deliverToPeer;
  Completer<void>? creatorShare;
  Future<void>? snapshotAcknowledgement;

  @override
  Future<LoginCompleteResponse> respondToChallenge(
    Signed<AuthChallenge> signedChallenge,
  ) async {
    final response = await super.respondToChallenge(signedChallenge);
    if (getSession(response.id).participantId != ids[1]) return response;
    return LoginCompleteResponse(
      id: response.id,
      expiry: response.expiry,
      startTime: response.startTime,
      onlineParticipants: response.onlineParticipants,
      newDkgs: response.newDkgs,
      sigRequests: response.sigRequests,
      sigRounds: response.sigRounds,
      completedSigs: response.completedSigs,
      cancelledRequests: response.cancelledRequests,
      secretShares: response.secretShares,
      events: response.events.asyncExpand((event) async* {
        if (await (deliverToPeer?.call(event) ?? true)) yield event;
      }),
    );
  }

  @override
  Future<bool> getSigningSnapshot({
    required SessionID sid,
    required OnetimeNumber correlationId,
  }) async {
    final queued = await super.getSigningSnapshot(
      sid: sid,
      correlationId: correlationId,
    );
    await snapshotAcknowledgement;
    return queued;
  }

  @override
  Future<SignaturesResponse?> submitSignatureReplies({
    required SessionID sid,
    required SignaturesRequestId reqId,
    required List<SignatureReply> replies,
  }) async {
    final gate = creatorShare;
    final fromCreator = getSession(sid).participantId == ids.first;
    final hasShare = replies.any((reply) => reply.share != null);
    if (gate != null && !fromCreator && hasShare) await gate.future;
    final response = await super.submitSignatureReplies(
      sid: sid,
      reqId: reqId,
      replies: replies,
    );
    if (gate != null && fromCreator && hasShare) gate.complete();
    return response;
  }
}

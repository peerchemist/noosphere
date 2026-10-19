import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';
import 'package:noosphere_protocol/public_feed.dart';
import 'package:noosphere_server/noosphere_server.dart' show PublicFeedConfig;

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final n in [2, 3]) {
    testWidgets(
      'worker creator cancels 2-of-$n over Iroh; offline and restarted isolates reconcile',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Text('Signature cancellation')),
          ),
        );
        await NoosphereFlutter.initialize();
        final privateKeys = [
          for (var i = 1; i <= n; i++) ECPrivateKey(Uint8List(32)..last = i),
        ];
        final ids = [for (var i = 1; i <= n; i++) Identifier.fromUint16(i)];
        final group = GroupConfig(
          id: 'worker-cancellation-$n',
          participants: {
            for (var i = 0; i < n; i++)
              ids[i]: ECCompressedPublicKey.fromPubkey(privateKeys[i].pubkey),
          },
        );
        final first = [
          for (final id in ids) DkgPart1(identifier: id, threshold: 2, n: n),
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
        final keys = [
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
        final stores = [
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
        final persistence = MemoryServerPersistence();
        final identity = freshTestIrohSecretKey();
        final feedId = PublicFeedId.generate();
        var worker = await NoosphereWorker.start();
        var events = <NoosphereWorkerEvent>[];
        var subscription = worker.events.listen(events.add);

        Future<void> waitUntil(bool Function() condition) async {
          final deadline = DateTime.now().add(const Duration(seconds: 15));
          while (!condition()) {
            if (DateTime.now().isAfter(deadline)) {
              fail('Timed out waiting for worker cancellation state');
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }

        Future<EndpointAddr> startServer() async {
          var snapshot = await worker.startSetup(
            setupId: 'coordinator',
            server: EmbeddedServerOptions(
              serverConfig: ServerConfig(
                group: group,
                publicFeed: PublicFeedConfig(feedId: feedId),
              ),
              getIrohSecretKey: identity,
              serverPersistence: persistence,
              relay: IrohRelayConfig.disabled(),
            ),
          );
          await waitUntil(
            () => events.whereType<WorkerSnapshotEvent>().any(
              (e) =>
                  e.setupId == 'coordinator' &&
                  e.snapshot.coordinator?.ipAddrs.isNotEmpty == true,
            ),
          );
          snapshot = events
              .whereType<WorkerSnapshotEvent>()
              .lastWhere(
                (e) =>
                    e.setupId == 'coordinator' &&
                    e.snapshot.coordinator!.ipAddrs.isNotEmpty,
              )
              .snapshot;
          return EndpointAddr(
            PublicKey.fromZ32(snapshot.coordinator!.id),
            ipAddrs: snapshot.coordinator!.ipAddrs,
          );
        }

        Future<NoosphereWorkerSnapshot> login(int i, EndpointAddr address) =>
            worker.startSetup(
              setupId: 'signer-$i',
              client: nativeTestClientOptions(
                group: group,
                participant: ids[i],
                key: privateKeys[i],
                address: address,
                storage: stores[i],
              ),
            );

        try {
          final address = await startServer();
          for (var i = 0; i < n; i++) {
            await login(i, address);
          }
          final request = SignaturesRequestDetails.forMessage(
            text: 'First cancellation $n',
            groupKey: keys.first.groupKey,
            expiry: Expiry(const Duration(minutes: 5)),
          );
          await worker.requestSignatures('signer-0', request);
          await waitUntil(
            () =>
                events
                    .whereType<WorkerSigningRequestEvent>()
                    .where(
                      (e) =>
                          SignaturesRequestId.fromBytes(e.request.id) ==
                          request.id,
                    )
                    .length ==
                n - 1,
          );
          await expectLater(
            worker.cancelSignaturesRequest('signer-1', request.id),
            throwsA(isA<NoosphereWorkerException>()),
          );
          expect(
            (await worker.snapshot('signer-0')).signingRequests,
            hasLength(1),
          );
          expect((await worker.snapshot('signer-1')).connected, isTrue);
          expect(
            await worker.cancelSignaturesRequest('signer-0', request.id),
            CancelSignaturesRequestResult.cancelled,
          );
          await waitUntil(
            () =>
                events
                    .whereType<WorkerSignaturesCancelledEvent>()
                    .where(
                      (e) =>
                          SignaturesRequestId.fromBytes(e.requestId) ==
                          request.id,
                    )
                    .length ==
                n,
          );
          for (var i = 0; i < n; i++) {
            final snapshot = await worker.snapshot('signer-$i');
            expect(snapshot.signingRequests, isEmpty);
            expect(
              snapshot.cancelledRequests.single.requestId,
              request.id.toBytes(),
            );
            expect(
              snapshot
                  .cancelledRequests
                  .single
                  .expiresAt
                  .millisecondsSinceEpoch,
              request.expiry.time.millisecondsSinceEpoch,
            );
            expect(stores[i].sigNonces, isEmpty);
            expect(stores[i].preparedSigOperations, isEmpty);
          }
          expect(
            await worker.cancelSignaturesRequest('signer-0', request.id),
            CancelSignaturesRequestResult.alreadyCancelled,
          );
          await expectLater(
            worker.requestSignatures('signer-0', request),
            throwsA(isA<NoosphereWorkerException>()),
          );

          // Signer 1 sees the second proposal and retains an uncertain prepared
          // operation offline. In 2-of-3, signer 2 misses that proposal entirely.
          if (n == 3) await worker.lockSigner('signer-2');
          final offlineRequest = SignaturesRequestDetails.forMessage(
            text: 'Offline cancellation $n',
            groupKey: keys.first.groupKey,
            expiry: Expiry(const Duration(minutes: 5)),
          );
          await worker.requestSignatures('signer-0', offlineRequest);
          await waitUntil(
            () => events.whereType<WorkerSigningRequestEvent>().any(
              (e) =>
                  e.setupId == 'signer-1' &&
                  SignaturesRequestId.fromBytes(e.request.id) ==
                      offlineRequest.id,
            ),
          );
          await worker.lockSigner('signer-1');
          await stores[1].prepareSignaturesOperation(
            PreparedSignaturesOperation(
              id: offlineRequest.id,
              kind: PreparedSignaturesOperationKind.replies,
              payloads: [offlineRequest.toBytes()],
              transcripts: [Uint8List(32)],
              nextNonces: SignaturesNonces({
                0: SignPart1(privateShare: keys[1].private.share).nonces,
              }, offlineRequest.expiry),
            ),
            1,
          );
          expect(
            await worker.cancelSignaturesRequest('signer-0', offlineRequest.id),
            CancelSignaturesRequestResult.cancelled,
          );
          expect(stores[1].sigNonces, isNotEmpty);
          await worker.close();
          await subscription.cancel();

          // Both coordinator state and all client stores cross a fresh isolate.
          worker = await NoosphereWorker.start();
          events = [];
          subscription = worker.events.listen(events.add);
          final restartedAddress = await startServer();
          for (var i = 0; i < n; i++) {
            final snapshot = await login(i, restartedAddress);
            expect(snapshot.signingRequests, isEmpty);
            expect(
              snapshot.cancelledRequests
                  .map((e) => SignaturesRequestId.fromBytes(e.requestId))
                  .toSet(),
              {request.id, offlineRequest.id},
            );
            final state = await stores[i].loadState();
            expect(state.sigNonces, isEmpty);
            expect(state.preparedOperations, isEmpty);
            expect(state.rejectedRequests, isEmpty);
            expect(state.cancelledRequests.keys.toSet(), {
              request.id,
              offlineRequest.id,
            });
            for (final tombstone in state.cancelledRequests.values) {
              expect(tombstone.toBytes(), [
                ...tombstone.requestId.toBytes(),
                ...tombstone.expiry.toBytes(),
              ]);
            }
          }
          await waitUntil(
            () =>
                events.whereType<WorkerSignaturesCancelledEvent>().length ==
                n * 2,
          );
          expect(
            await worker.cancelSignaturesRequest('signer-0', offlineRequest.id),
            CancelSignaturesRequestResult.alreadyCancelled,
          );
          expect(events.whereType<WorkerSigningResultEvent>(), isEmpty);
          expect(events.whereType<WorkerSigningRequestEvent>(), isEmpty);
        } finally {
          await worker.close();
          await subscription.cancel();
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}

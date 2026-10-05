import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final scenario in [
    (participants: 2, threshold: 2),
    (participants: 3, threshold: 2),
  ]) {
    testWidgets(
      'worker completes and verifies ${scenario.threshold}-of-${scenario.participants} ROAST',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
        );
        await _runScenario(
          participants: scenario.participants,
          threshold: scenario.threshold,
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}

Future<void> _runScenario({
  required int participants,
  required int threshold,
}) async {
  // Host storage deserializes Frosty values, so both host and worker bindings
  // are intentionally initialized for this proxy-storage integration test.
  await NoosphereFlutter.initialize();
  final privateKeys = [
    for (var i = 1; i <= participants; i++)
      ECPrivateKey(Uint8List(32)..last = i),
  ];
  final ids = [
    for (var i = 1; i <= participants; i++) Identifier.fromUint16(i),
  ];
  final group = GroupConfig(
    id: 'flutter-worker-$threshold-of-$participants',
    participants: {
      for (var i = 0; i < participants; i++)
        ids[i]: ECCompressedPublicKey.fromPubkey(privateKeys[i].pubkey),
    },
  );
  final stores = [for (var i = 0; i < participants; i++) _FaultingStorage()];
  final worker = await NoosphereWorker.start();
  final events = worker.events;
  final commandTimes = <String, int>{};
  final frameTimesMicros = <int>[];
  void recordFrames(List<FrameTiming> timings) {
    frameTimesMicros.addAll([
      for (final timing in timings) timing.totalSpan.inMicroseconds,
    ]);
  }

  SchedulerBinding.instance.addTimingsCallback(recordFrames);
  final frameTicker = Timer.periodic(const Duration(milliseconds: 16), (_) {
    SchedulerBinding.instance.scheduleFrame();
  });

  Future<T> timed<T>(String name, Future<T> Function() command) async {
    final watch = Stopwatch()..start();
    try {
      return await command();
    } finally {
      commandTimes[name] = watch.elapsedMilliseconds;
    }
  }

  try {
    final reachableSnapshot = events
        .where((event) => event is WorkerSnapshotEvent)
        .cast<WorkerSnapshotEvent>()
        .map((event) => event.snapshot)
        .firstWhere(
          (snapshot) =>
              snapshot.setupId == 'signer-0' &&
              snapshot.coordinator?.ipAddrs.isNotEmpty == true,
        );
    var serverSnapshot = await worker.startSetup(
      setupId: 'signer-0',
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        getIrohSecretKey: freshTestIrohSecretKey(),
        serverPersistence: MemoryServerPersistence(),
        relay: IrohRelayConfig.disabled(),
      ),
    );
    if (serverSnapshot.coordinator!.ipAddrs.isEmpty) {
      serverSnapshot = await reachableSnapshot.timeout(
        const Duration(seconds: 15),
      );
    }
    final coordinator = serverSnapshot.coordinator!;
    final address = EndpointAddr(
      PublicKey.fromZ32(coordinator.id),
      ipAddrs: coordinator.ipAddrs,
    );
    for (var i = 0; i < participants; i++) {
      await worker.startSetup(
        setupId: 'signer-$i',
        client: nativeTestClientOptions(
          group: group,
          participant: ids[i],
          key: privateKeys[i],
          address: address,
          storage: stores[i],
        ),
      );
    }

    final dkgName = 'worker-$threshold-of-$participants';
    await timed(
      'requestDkgToCancel',
      () => worker.requestDkg(
        'signer-0',
        NewDkgDetails(
          name: dkgName,
          description: 'Stale worker DKG to cancel',
          threshold: threshold,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      ),
    );
    await timed('restartDkgCreator', () async {
      await worker.lockSigner('signer-0');
      await worker.startSetup(
        setupId: 'signer-0',
        client: nativeTestClientOptions(
          group: group,
          participant: ids.first,
          key: privateKeys.first,
          address: address,
          storage: stores.first,
        ),
      );
    });
    final staleDkg = (await worker.snapshot('signer-0')).dkgs
        .singleWhere((dkg) => dkg.name == dkgName && dkg.stage == 'waiting');
    await timed(
      'cancelAcceptedDkg',
      () => worker.rejectDkg('signer-0', staleDkg),
    );

    final pendingDkgs = [
      for (var i = 1; i < participants; i++)
        events
            .where((event) => event is WorkerDkgEvent)
            .cast<WorkerDkgEvent>()
            .firstWhere(
              (event) =>
                  event.setupId == 'signer-$i' &&
                  event.status.name == dkgName &&
                  event.status.description ==
                      'Native worker integration test' &&
                  !event.rejected,
            ),
    ];
    await timed(
      'requestDkg',
      () => worker.requestDkg(
        'signer-0',
        NewDkgDetails(
          name: dkgName,
          description: 'Native worker integration test',
          threshold: threshold,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      ),
    );
    final proposals = await Future.wait(pendingDkgs)
        .timeout(const Duration(seconds: 15));
    for (final proposal in proposals) {
      expect(proposal.status.stage, 'waiting');
    }
    final completedKeys = Future.wait([
      for (final store in stores)
        store.waitForKeyWithName(dkgName, participants),
    ]);
    final completedKeyEvents = [
      for (var i = 0; i < participants; i++)
        events
            .where((event) => event is WorkerKeyUpdatedEvent)
            .cast<WorkerKeyUpdatedEvent>()
            .firstWhere(
              (event) =>
                  event.setupId == 'signer-$i' && event.key.name == dkgName,
            ),
    ];
    for (var i = 1; i < participants; i++) {
      await timed(
        'acceptDkg-$i',
        () => worker.acceptDkg('signer-$i', proposals[i - 1].status),
      );
    }
    final frostKeys = await completedKeys.timeout(const Duration(minutes: 2));
    final keyEvents = await Future.wait(completedKeyEvents)
        .timeout(const Duration(seconds: 15));
    for (var i = 0; i < participants; i++) {
      expect(keyEvents[i].key.groupKeyHex, frostKeys[i].groupKey.hex);
    }

    final messages = [
      for (var input = 0; input < 32; input++)
        Uint8List(32)
          ..[30] = input
          ..last = 40 + participants + input,
    ];
    final details = SignaturesRequestDetails(
      requiredSigs: [
        for (final message in messages)
          SingleSignatureDetails(
            signDetails: SignDetails.keySpend(message: message),
            groupKey: frostKeys.first.groupKey,
            hdDerivation: const [],
          ),
      ],
      expiry: Expiry(const Duration(minutes: 3)),
    );
    final secondRequest = events
        .where((event) => event is WorkerSigningRequestEvent)
        .cast<WorkerSigningRequestEvent>()
        .firstWhere((event) => event.setupId == 'signer-1');
    final resultFutures = [
      for (var i = 0; i < threshold; i++)
        events
            .where((event) => event is WorkerSigningResultEvent)
            .cast<WorkerSigningResultEvent>()
            .firstWhere((event) => event.setupId == 'signer-$i'),
    ];
    await timed(
      'requestSignatures',
      () => worker.requestSignatures('signer-0', details),
    );
    final request = await secondRequest.timeout(const Duration(seconds: 15));
    expect(request.request.progress.threshold, threshold);
    expect(request.request.progress.contributingParticipants, [
      request.request.creator,
    ]);
    expect(request.request.progress.stage, 'collecting');
    final signingProgress = events
        .where((event) => event is WorkerSigningRequestEvent)
        .cast<WorkerSigningRequestEvent>()
        .firstWhere(
          (event) =>
              event.setupId == 'signer-0' &&
              event.request.decodeProposal().id == details.id &&
              event.request.progress.stage == 'signing',
        );
    stores[1].armSigningGate();
    final accepting = timed(
      'acceptSignatures',
      () => worker.acceptSignatures('signer-1', request.request),
    );
    await stores[1].signingGateEntered.timeout(const Duration(seconds: 15));
    stores[1].releaseSigningGate();
    await stores[1].signingGateReturned.timeout(const Duration(seconds: 15));
    // Let the host reply reach the worker first. Its next continuation enters
    // the synchronous Frosty batch before this command can be serviced.
    await Future<void>.delayed(Duration.zero);
    await timed(
      'controlledOverlapSnapshot',
      () => worker.snapshot('signer-${participants - 1}'),
    );
    await accepting;
    expect(
      (await signingProgress.timeout(const Duration(seconds: 15)))
          .request
          .progress
          .threshold,
      threshold,
    );
    final results = await Future.wait(resultFutures)
        .timeout(const Duration(minutes: 2));

    for (final result in results) {
      expect(result.signatures, hasLength(messages.length));
      for (var input = 0; input < messages.length; input++) {
        expect(
          SchnorrSignature(result.signatures[input]).verify(
            Taproot(internalKey: frostKeys.first.groupKey).tweakedKey,
            messages[input],
          ),
          isTrue,
        );
      }
    }

    const signedText = 'Message through the Flutter worker 🌍';
    final messageDetails = SignaturesRequestDetails.forMessage(
      text: signedText,
      groupKey: frostKeys.first.groupKey,
      expiry: Expiry(const Duration(minutes: 3)),
    );
    final messageRequestFuture = events
        .where((event) => event is WorkerSigningRequestEvent)
        .cast<WorkerSigningRequestEvent>()
        .firstWhere(
          (event) =>
              event.setupId == 'signer-1' &&
              event.request.decodeProposal().id == messageDetails.id,
        );
    final messageResultFutures = [
      for (var i = 0; i < threshold; i++)
        events
            .where((event) => event is WorkerSigningResultEvent)
            .cast<WorkerSigningResultEvent>()
            .firstWhere(
              (event) =>
                  event.setupId == 'signer-$i' &&
                  SignaturesRequestId.fromBytes(event.requestId) ==
                      messageDetails.id,
            ),
    ];
    await timed(
      'requestMessageSignature',
      () => worker.requestSignatures('signer-0', messageDetails),
    );
    final messageRequest = await messageRequestFuture.timeout(
      const Duration(seconds: 15),
    );
    final transportedMetadata =
        messageRequest.request.decodeProposal().metadata
            as MessageSignatureMetadata;
    expect(transportedMetadata.payload.text, signedText);
    await timed(
      'acceptMessageSignature',
      () => worker.acceptSignatures('signer-1', messageRequest.request),
    );
    final messageResults = await Future.wait(messageResultFutures)
        .timeout(const Duration(minutes: 2));
    for (final result in messageResults) {
      final signedMessage = result.toSignedMessage();
      expect(signedMessage.text, signedText);
      expect(signedMessage.verify(), isTrue);
      expect(
        SignedMessage.fromJsonString(signedMessage.toJsonString()).verify(),
        isTrue,
      );
    }

    debugPrint('worker $threshold-of-$participants command ms: $commandTimes');
    if (frameTimesMicros.isNotEmpty) {
      frameTimesMicros.sort();
      final p95 = frameTimesMicros[(frameTimesMicros.length * 0.95).floor()];
      debugPrint(
        'worker $threshold-of-$participants frame total us: '
        'count=${frameTimesMicros.length}, p95=$p95, '
        'max=${frameTimesMicros.last}',
      );
    } else {
      debugPrint('worker $threshold-of-$participants frame total us: count=0');
    }

    if (participants == 2) {
      for (final afterWrite in [false, true]) {
        final faultStore = stores[0];
        faultStore.failAfterWrite = afterWrite;
        final faultDetails = SignaturesRequestDetails(
          requiredSigs: [
            SingleSignatureDetails(
              signDetails: SignDetails.keySpend(
                message: Uint8List(32)..last = afterWrite ? 91 : 90,
              ),
              groupKey: frostKeys.first.groupKey,
              hdDerivation: const [],
            ),
          ],
          expiry: Expiry(const Duration(minutes: 3)),
        );
        await expectLater(
          worker.requestSignatures('signer-0', faultDetails),
          throwsA(isA<NoosphereWorkerException>()),
        );
        expect(
          faultStore.preparedSigOperations.containsKey(faultDetails.id),
          afterWrite,
        );
        expect(faultStore.sigNonces.containsKey(faultDetails.id), afterWrite);
        faultStore.failAfterWrite = null;
        final prepareCalls = faultStore.prepareCalls;
        await expectLater(
          worker.requestSignatures('signer-0', faultDetails),
          throwsA(isA<NoosphereWorkerException>()),
        );
        expect(faultStore.prepareCalls, prepareCalls);
      }
    }

    await worker.lockSigner('signer-0');
    final locked = await worker.snapshot('signer-0');
    expect(locked.signerRunning, isFalse);
    expect(locked.serverRunning, isTrue);
    await worker.requestDkg(
      'signer-1',
      NewDkgDetails(
        name: 'after-signer-lock',
        description: 'Coordinator remains available after local signer lock',
        threshold: threshold,
        expiry: Expiry(const Duration(hours: 1)),
      ),
    );
  } finally {
    frameTicker.cancel();
    SchedulerBinding.instance.removeTimingsCallback(recordFrames);
    await worker.close();
  }
}

final class _FaultingStorage extends InMemoryClientStorage {
  bool? failAfterWrite;
  int prepareCalls = 0;
  Completer<void>? _signingGateEntered;
  Completer<void>? _signingGateRelease;
  Completer<void>? _signingGateReturned;

  Future<void> get signingGateEntered => _signingGateEntered!.future;

  Future<void> get signingGateReturned => _signingGateReturned!.future;

  void armSigningGate() {
    _signingGateEntered = Completer<void>();
    _signingGateRelease = Completer<void>();
    _signingGateReturned = Completer<void>();
  }

  void releaseSigningGate() => _signingGateRelease!.complete();

  @override
  Future<void> removeRejectionOfSigsRequest(SignaturesRequestId id) async {
    final entered = _signingGateEntered;
    final release = _signingGateRelease;
    if (entered != null && release != null) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    await super.removeRejectionOfSigsRequest(id);
    final returned = _signingGateReturned;
    if (returned != null && !returned.isCompleted) returned.complete();
  }

  @override
  Future<void> prepareSignaturesOperation(
    PreparedSignaturesOperation operation,
    int capacity,
  ) async {
    prepareCalls++;
    if (failAfterWrite == false) throw StateError('Injected before commit.');
    await super.prepareSignaturesOperation(operation, capacity);
    if (failAfterWrite == true) throw StateError('Injected after commit.');
  }
}

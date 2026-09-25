import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

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
      identityStorageId: 'worker-native-$threshold-of-$participants',
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: group),
        identityStore: MemoryIdentityStore(),
        relay: IrohRelayConfig.disabled(),
      ),
    );
    if (serverSnapshot.coordinator!.ipAddrs.isEmpty) {
      serverSnapshot = await reachableSnapshot.timeout(
        const Duration(seconds: 15),
      );
    }
    final identityBackup = await worker.exportIrohServerIdentity('signer-0');
    expect(identityBackup, hasLength(32));
    final originalLastByte = identityBackup.last;
    identityBackup.last ^= 0xff;
    expect(
      (await worker.exportIrohServerIdentity('signer-0')).last,
      originalLastByte,
    );
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
      if (i != 0) {
        await expectLater(
          worker.exportIrohServerIdentity('signer-$i'),
          throwsA(isA<StateError>()),
        );
      }
    }

    final dkgName = 'worker-$threshold-of-$participants';
    final pendingDkgs = [
      for (var i = 1; i < participants; i++)
        events
            .where((event) => event is WorkerDkgEvent)
            .cast<WorkerDkgEvent>()
            .firstWhere(
              (event) =>
                  event.setupId == 'signer-$i' && event.status.name == dkgName,
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
    final completedKeys = Future.wait([
      for (final store in stores)
        store.waitForKeyWithName(dkgName, participants),
    ]);
    for (var i = 1; i < participants; i++) {
      await timed(
        'acceptDkg-$i',
        () => worker.acceptDkg('signer-$i', proposals[i - 1].status),
      );
    }
    final frostKeys = await completedKeys.timeout(const Duration(minutes: 2));

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

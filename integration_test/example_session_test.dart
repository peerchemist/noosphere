// The example app must not become a dependency of the published facade.
// ignore_for_file: avoid_relative_lib_imports

import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import '../example/lib/demo_worker.dart';
import '../example/lib/node_screen.dart';
import '../example/lib/proposal_widgets.dart';
import '../example/lib/session_controller.dart';

enum _Stage { factory, server, address, signer, snapshot, ready }

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(NoosphereFlutter.initialize);

  for (final stage in _Stage.values) {
    testWidgets('disposing the screen during $stage closes its session', (
      tester,
    ) async {
      final worker = _Worker(stage);
      final factory = Completer<DemoWorker>();
      final controller = DemoSessionController(
        startWorker: () =>
            stage == _Stage.factory ? factory.future : Future.value(worker),
      );
      if (stage == _Stage.snapshot) {
        controller.selectMachine(TestMachine.coordinator);
      }
      await tester.pumpWidget(
        MaterialApp(home: NodeScreen(controller: controller)),
      );
      final starting = controller.start('');
      await tester.pump();
      final callsBeforeDispose = worker.starts;
      await tester.pumpWidget(const SizedBox());
      if (stage == _Stage.factory) factory.complete(worker);
      worker.gate.complete();
      await tester.runAsync(() async {
        await starting;
        await controller.shutdown();
      });
      expect(worker.closes, 1);
      expect(worker.starts, callsBeforeDispose);
      expect(worker.stream.hasListener, isFalse);
      expect(tester.takeException(), isNull);
      await worker.stream.close();
    });
  }

  testWidgets(
    'participant switches isolate storage and capture the right key',
    (tester) async {
      final workers = <_Worker>[];
      final controller = DemoSessionController(
        startWorker: () async {
          final worker = _Worker(_Stage.ready);
          workers.add(worker);
          return worker;
        },
      );
      for (final machine in [TestMachine.a, TestMachine.b, TestMachine.a]) {
        controller.selectMachine(machine);
        await controller.start(_address().id);
        await controller.stop();
      }
      final clients = workers.map((worker) => worker.client!).toList();
      expect(clients[0].storage, same(clients[2].storage));
      expect(clients[0].storage, isNot(same(clients[1].storage)));
      expect(
        cl.bytesToHex((await clients[0].getPrivateKey(KeyPurpose.login)).data),
        '${'00' * 31}01',
      );
      expect(
        cl.bytesToHex((await clients[1].getPrivateKey(KeyPurpose.login)).data),
        '${'00' * 31}02',
      );
      controller.dispose();
      await controller.shutdown();
      for (final worker in workers) {
        await worker.stream.close();
      }
    },
  );

  testWidgets('historical completions verify derived and MAST-tweaked keys', (
    tester,
  ) async {
    final worker = _Worker(_Stage.ready);
    final controller = DemoSessionController(startWorker: () async => worker);
    await controller.start('');
    final root = cl.ECPrivateKey(Uint8List(32)..last = 7);
    var derived = root;
    var hd = HDKeyInfo.master;
    final path = [86, 1, 0, 0, 9];
    for (final index in path) {
      final (tweak, next) = hd.deriveTweakAndInfo(
        cl.ECCompressedPublicKey.fromPubkey(derived.pubkey),
        index,
      );
      derived = derived.tweak(tweak)!;
      hd = next;
    }
    final mast = Uint8List(32)..last = 3;
    final hash = Uint8List(32)..last = 42;
    final signingKey = derived.xonly.tweak(
      cl.Taproot.tweakHash(Uint8List.fromList([...derived.pubkey.x, ...mast])),
    )!;
    final proposal = SignaturesRequestDetails.allowNegativeExpiry(
      requiredSigs: [
        SingleSignatureDetails(
          signDetails: SignDetails.keySpend(message: hash, mastHash: mast),
          groupKey: cl.ECCompressedPublicKey.fromPubkey(root.pubkey),
          hdDerivation: path,
        ),
      ],
      expiry: Expiry(const Duration(seconds: -1)),
    );
    worker.stream.add(
      WorkerSigningResultEvent(
        'example',
        1,
        requestId: proposal.id.toBytes(),
        proposalBytes: proposal.toBytes(),
        signatures: [cl.SchnorrSignature.sign(signingKey, hash).data],
        creator: 'test',
      ),
    );
    expect(controller.signatureValid, isTrue);
    expect(controller.signedHash, cl.bytesToHex(hash));
    final pending = WorkerSigningRequest(
      id: proposal.id.toBytes(),
      proposalBytes: proposal.toBytes(),
      creator: 'test',
      expiry: proposal.expiry.time,
      status: 'waiting',
      progress: WorkerSigningProgress(
        threshold: 2,
        contributingParticipants: [],
        stage: 'collecting',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SigningProposalTile(
            proposal: pending,
            busy: false,
            onAccept: () => fail('Expired proposal accepted'),
          ),
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    controller.dispose();
    await controller.shutdown();
    await worker.stream.close();
  });
}

WorkerCoordinatorAddress _address() => WorkerCoordinatorAddress(
  id: PublicKey.fromHex('58${'66' * 31}').toZ32(),
  relayUrls: [],
  ipAddrs: ['127.0.0.1:12345'],
);
NoosphereWorkerSnapshot _snapshot() => NoosphereWorkerSnapshot(
  setupId: 'example',
  generation: 1,
  serverRunning: true,
  signerRunning: true,
  connected: true,
  coordinator: _address(),
  onlineParticipants: [],
  dkgs: [],
  signingRequests: [],
  keys: [],
);

final class _Worker(this.stage) implements DemoWorker {
  final _Stage stage;
  final gate = Completer<void>();
  final stream = StreamController<NoosphereWorkerEvent>.broadcast(sync: true);
  int starts = 0;
  int closes = 0;
  ClientNodeOptions? client;
  @override
  bool isClosed = false;
  @override
  Stream<NoosphereWorkerEvent> get events => stream.stream;
  @override
  Future<NoosphereWorkerSnapshot> startSetup({
    required String setupId,
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  }) async {
    starts++;
    if (server != null) {
      if (stage == _Stage.server) await gate.future;
      if (!isClosed && stage != _Stage.address) {
        stream.add(WorkerSnapshotEvent(_snapshot()));
      }
    }
    if (client != null) {
      this.client = client;
      if (stage == _Stage.signer) await gate.future;
    }
    return _snapshot();
  }

  @override
  Future<NoosphereWorkerSnapshot> snapshot(String setupId) async {
    if (stage == _Stage.snapshot) await gate.future;
    return _snapshot();
  }

  @override
  Future<void> close() async {
    closes++;
    isClosed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

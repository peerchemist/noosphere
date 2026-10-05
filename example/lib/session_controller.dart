import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

import 'demo_identity.dart';
import 'demo_worker.dart';
import 'diagnostics.dart';

enum TestMachine(final String label, final int participant) {
  a('Computer A · server + participant 1', 1),
  b('Computer B · participant 2', 2),
  coordinator('Coordinator only · no local signer', 1);

  bool get hostsServer => this != b;
  bool get runsSigner => this != coordinator;
}

final class DemoSessionController extends ChangeNotifier
    with WidgetsBindingObserver {
  DemoSessionController({this.startWorker = startDemoWorker}) {
    WidgetsBinding.instance.addObserver(this);
  }
  final Future<DemoWorker> Function() startWorker;
  final _identity = DemoIdentityMaterial.derive();
  final _serverPersistence = InMemoryServerPersistence();
  final _clientStores = <int, InMemoryClientStorage>{};
  List<ECPrivateKey> get _keys => _identity.participantKeys;

  late final GroupConfig _group = GroupConfig(
    id: 'noosphere-flutter-example',
    participants: {
      for (var i = 0; i < _keys.length; i++)
        Identifier.fromUint16(i + 1): ECCompressedPublicKey.fromPubkey(
          _keys[i].pubkey,
        ),
    },
  );

  TestMachine machine = TestMachine.a;
  DemoWorker? _worker;
  StreamSubscription<NoosphereWorkerEvent>? _events;
  NoosphereWorkerSnapshot? snapshot;
  String? publishedIrohId;
  String status = 'Stopped';
  String? error;
  String? signature;
  String? signedHash;
  bool? signatureValid;
  bool busy = false;

  bool get running => _worker != null;
  Identifier get _participantId =>
      _group.participants.keys.elementAt(machine.participant - 1);
  ECPrivateKey get _participantKey => _keys[machine.participant - 1];
  ECCompressedPublicKey get participantPublicKey =>
      ECCompressedPublicKey.fromPubkey(_participantKey.pubkey);
  String get participantDerivationPath =>
      demoParticipantDerivationPaths[machine.participant - 1];
  String get irohDerivationPath =>
      irohIdentityDerivationPath(demoIrohIdentityIndex);

  bool _disposed = false;
  bool _cancelStart = false;
  bool get _active => !_disposed;
  Future<void>? _starting;
  Future<void>? _shuttingDown;
  void _update(void Function() update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(shutdown());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) unawaited(shutdown());
  }

  Future<void> shutdown() => _shuttingDown ??= _shutdown();
  Future<void> _shutdown() async {
    _cancelStart = true;
    await _close(ignoreErrors: true);
    await _starting;
    await _close(ignoreErrors: true);
  }

  void selectMachine(TestMachine value) {
    if (running || busy) return;
    _update(() => machine = value);
  }

  Future<void> start(String coordinatorId) {
    if (_disposed || busy || running) return Future<void>.value();
    _shuttingDown = null;
    _cancelStart = false;
    return _starting = _start(coordinatorId);
  }

  Future<void> _start(String coordinatorId) async {
    if (!machine.hostsServer && coordinatorId.trim().isEmpty) {
      _update(() => error = 'Paste Computer A Iroh ID.');
      return;
    }

    _update(() {
      busy = true;
      error = null;
      status = 'Starting…';
      signature = null;
      signedHash = null;
      signatureValid = null;
    });

    try {
      final worker = await startWorker();
      if (!_active || _cancelStart) {
        await worker.close();
        return;
      }
      _worker = worker;
      _events = worker.events.listen(
        _onWorkerEvent,
        onError: (Object error) => _setError(error),
      );

      final EndpointAddr address;
      final EndpointId pinnedId;
      if (machine.hostsServer) {
        final reachableCoordinator = _waitForCoordinator(worker);
        await worker.startSetup(
          setupId: 'example',
          server: EmbeddedServerOptions(
            serverConfig: ServerConfig(group: _group),
            getIrohSecretKey: () => _identity.irohSecretKey,
            serverPersistence: _serverPersistence,
          ),
        );
        if (_disposed || _cancelStart) return;
        final coordinator = await reachableCoordinator;
        if (_disposed || _cancelStart) return;
        pinnedId = PublicKey.fromZ32(coordinator.id);
        address = EndpointAddr(
          pinnedId,
          relayUrls: [
            for (final url in coordinator.relayUrls) RelayUrl.parse(url),
          ],
          ipAddrs: coordinator.ipAddrs,
        );
        publishedIrohId = coordinator.id;
        logWorkerEndpoint(coordinator);
      } else {
        pinnedId = PublicKey.fromZ32(coordinatorId.trim());
        address = EndpointAddr(pinnedId);
      }

      logDemo(
        'ROAST participant ${machine.participant} public key: '
        '${participantPublicKey.hex}',
      );

      if (_disposed || _cancelStart) return;
      if (machine.runsSigner) {
        final participantKey = _participantKey;
        snapshot = await worker.startSetup(
          setupId: 'example',
          client: ClientNodeOptions(
            clientConfig: ClientConfig(group: _group, id: _participantId),
            bootstrapAddress: address,
            pinnedServerId: pinnedId,
            storage: _clientStores.putIfAbsent(
              machine.participant,
              InMemoryClientStorage.new,
            ),
            getPrivateKey: (_) async => participantKey,
          ),
        );
      } else {
        snapshot = await worker.snapshot('example');
      }
      if (!_active || _cancelStart) return;
      _update(() {
        busy = false;
        status = machine.runsSigner ? 'Connected' : 'Serving';
      });
    } catch (error, stackTrace) {
      logDemo('Start failed: $error\n$stackTrace');
      await _close(ignoreErrors: true);
      if (_active) {
        _update(() {
          busy = false;
          status = 'Stopped';
          this.error = '$error';
        });
      }
    }
  }

  void _onWorkerEvent(NoosphereWorkerEvent event) {
    if (event case WorkerSnapshotEvent()) {
      snapshot = event.snapshot;
      logWorkerSnapshot(event.snapshot);
    } else if (event case WorkerSigningResultEvent()) {
      logDemo('ROAST worker event: ${event.runtimeType}');
      final proposal = event.decodeProposal();
      if (proposal.requiredSigs.length == 1 && event.signatures.length == 1) {
        final details = proposal.requiredSigs.single;
        final result = SchnorrSignature(event.signatures.single);
        signature = hexBytes(event.signatures.single);
        signedHash = hexBytes(details.signDetails.message);
        final verificationKey = signatureVerificationKey(details);
        signatureValid = result.verify(
          verificationKey,
          details.signDetails.message,
        );
      }
    } else if (event case WorkerFailureEvent()) {
      logDemo('ROAST worker event: ${event.runtimeType}');
      error = event.message;
    } else {
      logDemo('ROAST worker event: ${event.runtimeType}');
      unawaited(_refreshSnapshot());
    }
    if (_active) _update(() {});
  }

  Future<void> _refreshSnapshot() async {
    final worker = _worker;
    if (worker == null || worker.isClosed) return;
    try {
      final snapshot = await worker.snapshot('example');
      if (_active) _update(() => this.snapshot = snapshot);
    } catch (error) {
      _setError(error);
    }
  }

  void _setError(Object error) {
    logDemo('Error: $error');
    if (_active) _update(() => this.error = '$error');
  }

  Future<void> _perform(
    String operationStatus,
    Future<void> Function(DemoWorker worker) operation,
  ) async {
    final worker = _worker;
    if (_disposed || busy || worker == null) return;
    _update(() {
      busy = true;
      error = null;
      status = operationStatus;
    });
    try {
      await operation(worker);
    } catch (error, stackTrace) {
      logDemo('$operationStatus failed: $error\n$stackTrace');
      this.error = '$error';
    } finally {
      if (_active) {
        _update(() {
          busy = false;
          status = 'Connected';
        });
      }
    }
  }

  Future<void> createDkg(String dkgName) => _perform('Creating 2-of-2 key…', (
    worker,
  ) {
    final snapshot = this.snapshot;
    if (snapshot == null ||
        snapshot.dkgs.isNotEmpty ||
        snapshot.keys.isNotEmpty) {
      throw StateError('A DKG is already active or the key already exists.');
    }
    final name = dkgName.trim();
    return worker.requestDkg(
      'example',
      NewDkgDetails(
        name: name,
        description: 'Two-computer Noosphere Flutter test',
        threshold: 2,
        expiry: Expiry(const Duration(hours: 1)),
      ),
    );
  });

  Future<void> requestSignature(String hashInput) => _perform(
    'Requesting signature…',
    (worker) {
      final snapshot = this.snapshot;
      if (snapshot == null || snapshot.keys.isEmpty) {
        throw StateError('Complete the DKG first.');
      }
      final key = snapshot.keys.first;
      return worker.requestSignatures(
        'example',
        SignaturesRequestDetails(
          requiredSigs: [
            SingleSignatureDetails(
              signDetails: SignDetails.keySpend(message: parseHash(hashInput)),
              groupKey: ECCompressedPublicKey.fromHex(key.groupKeyHex),
              hdDerivation: const [],
            ),
          ],
          expiry: Expiry(const Duration(minutes: 3)),
        ),
      );
    },
  );

  Future<void> stop() async {
    _update(() {
      busy = true;
      status = 'Stopping…';
    });
    try {
      await shutdown();
    } catch (error) {
      _setError(error);
    } finally {
      if (_active) {
        _update(() {
          busy = false;
          status = 'Stopped';
          publishedIrohId = null;
        });
      }
    }
  }

  Future<void>? _closing;
  Future<void> _close({bool ignoreErrors = false}) =>
      _closing ??= _closeSession(ignoreErrors: ignoreErrors).whenComplete(() {
        _closing = null;
      });

  Future<void> _closeSession({required bool ignoreErrors}) async {
    final waiter = _coordinator;
    _coordinator = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(StateError('Session closed during startup'));
    }
    await _coordinatorEvents?.cancel();
    _coordinatorEvents = null;
    try {
      await _events?.cancel();
      await _worker?.close().timeout(const Duration(seconds: 10));
    } catch (error) {
      if (!ignoreErrors) rethrow;
      logDemo('Close failed: $error');
    } finally {
      _events = null;
      snapshot = null;
      _worker = null;
    }
  }

  StreamSubscription<NoosphereWorkerEvent>? _coordinatorEvents;
  Completer<WorkerCoordinatorAddress>? _coordinator;
  Future<WorkerCoordinatorAddress> _waitForCoordinator(DemoWorker worker) {
    final done = _coordinator = Completer<WorkerCoordinatorAddress>();
    _coordinatorEvents = worker.events.listen((event) {
      if (event case WorkerSnapshotEvent(:final snapshot)) {
        final address = snapshot.coordinator;
        if (snapshot.setupId == 'example' &&
            address != null &&
            (address.ipAddrs.isNotEmpty || address.relayUrls.isNotEmpty) &&
            !done.isCompleted) {
          done.complete(address);
        }
      }
    });
    final result = done.future.timeout(const Duration(seconds: 15));
    unawaited(result.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    return result;
  }

  Future<void> acceptDkg(WorkerDkgStatus proposal) => _perform(
    'Accepting DKG…',
    (worker) => worker.acceptDkg('example', proposal),
  );
  Future<void> acceptSignatures(WorkerSigningRequest proposal) => _perform(
    'Accepting signature…',
    (worker) => worker.acceptSignatures('example', proposal),
  );
}

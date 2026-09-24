import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

Future<void> main() async {
  await NoosphereFlutter.initialize();
  runApp(const NoosphereExampleApp());
}

final class NoosphereExampleApp extends StatelessWidget {
  const NoosphereExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Noosphere 2-of-2 test',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: const NodeScreen(),
  );
}

enum TestMachine(final String label, final int participant) {
  a('Computer A · server + participant 1', 1),
  b('Computer B · participant 2', 2),
  coordinator('Coordinator only · no local signer', 1);

  bool get hostsServer => this != b;
  bool get runsSigner => this != coordinator;
}

final class NodeScreen extends StatefulWidget {
  const NodeScreen({super.key});

  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

final class _NodeScreenState extends State<NodeScreen> {
  final _irohId = TextEditingController();
  final _dkgName = TextEditingController(text: 'first-2of2');
  final _messageHash = TextEditingController(
    text: '0000000000000000000000000000000000000000000000000000000000000001',
  );
  final _identityStore = _MemoryIdentityStore();
  final _clientStorage = InMemoryClientStorage();
  final _keys = [
    ECPrivateKey(Uint8List(32)..last = 1),
    ECPrivateKey(Uint8List(32)..last = 2),
  ];

  late final GroupConfig _group = GroupConfig(
    id: 'noosphere-flutter-example',
    participants: {
      for (var i = 0; i < _keys.length; i++)
        Identifier.fromUint16(i + 1): ECCompressedPublicKey.fromPubkey(
          _keys[i].pubkey,
        ),
    },
  );

  TestMachine _machine = TestMachine.a;
  NoosphereWorker? _worker;
  NoosphereWorkerLifecycleObserver? _workerLifecycle;
  StreamSubscription<NoosphereWorkerEvent>? _events;
  NoosphereWorkerSnapshot? _snapshot;
  String? _publishedIrohId;
  String _status = 'Stopped';
  String? _error;
  String? _signature;
  String? _signedHash;
  bool? _signatureValid;
  bool _busy = false;

  bool get _running => _worker != null;
  Identifier get _participantId => Identifier.fromUint16(_machine.participant);
  ECPrivateKey get _participantKey => _keys[_machine.participant - 1];
  ECCompressedPublicKey get _participantPublicKey =>
      ECCompressedPublicKey.fromPubkey(_participantKey.pubkey);

  @override
  void dispose() {
    _workerLifecycle?.detach();
    unawaited(_events?.cancel());
    unawaited(_worker?.close());
    for (final controller in [_irohId, _dkgName, _messageHash]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (!_machine.hostsServer && _irohId.text.trim().isEmpty) {
      setState(() => _error = 'Paste Computer A Iroh ID.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = 'Starting…';
      _signature = null;
      _signedHash = null;
      _signatureValid = null;
    });

    try {
      final worker = await NoosphereWorker.start();
      _worker = worker;
      _workerLifecycle = NoosphereWorkerLifecycleObserver(worker)..attach();
      _events = worker.events.listen(
        _onWorkerEvent,
        onError: (Object error) => _setError(error),
      );

      final EndpointAddr address;
      final EndpointId pinnedId;
      if (_machine.hostsServer) {
        final serverSnapshot = await worker.startSetup(
          setupId: 'example',
          server: EmbeddedServerOptions(
            serverConfig: ServerConfig(group: _group),
            identityStore: _identityStore,
          ),
          identityStorageId: 'noosphere-example-coordinator',
        );
        final coordinator = serverSnapshot.coordinator!;
        pinnedId = PublicKey.fromZ32(coordinator.id);
        address = EndpointAddr(pinnedId);
        _publishedIrohId = coordinator.id;
        _logWorkerEndpoint(coordinator);
      } else {
        pinnedId = PublicKey.fromZ32(_irohId.text.trim());
        address = EndpointAddr(pinnedId);
      }

      _log(
        'ROAST participant ${_machine.participant} public key: '
        '${_participantPublicKey.hex}',
      );

      if (_machine.runsSigner) {
        _snapshot = await worker.startSetup(
          setupId: 'example',
          client: ClientNodeOptions(
            clientConfig: ClientConfig(group: _group, id: _participantId),
            bootstrapAddress: address,
            pinnedServerId: pinnedId,
            storage: _clientStorage,
            getPrivateKey: (_) async => _participantKey,
          ),
        );
      } else {
        _snapshot = await worker.snapshot('example');
      }
      setState(() {
        _busy = false;
        _status = _machine.runsSigner ? 'Connected' : 'Serving';
      });
    } catch (error, stackTrace) {
      _log('Start failed: $error\n$stackTrace');
      await _close(ignoreErrors: true);
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Stopped';
          _error = '$error';
        });
      }
    }
  }

  void _onWorkerEvent(NoosphereWorkerEvent event) {
    _log('ROAST worker event: ${event.runtimeType}');
    if (event case WorkerSnapshotEvent()) {
      _snapshot = event.snapshot;
    } else if (event case WorkerSigningResultEvent()) {
      final proposal = SignaturesRequestDetails.fromBytes(event.proposalBytes);
      if (proposal.requiredSigs.length == 1 && event.signatures.length == 1) {
        final details = proposal.requiredSigs.single;
        final result = SchnorrSignature(event.signatures.single);
        _signature = _hex(event.signatures.single);
        _signedHash = _hex(details.signDetails.message);
        _signatureValid = result.verify(
          details.groupKey,
          details.signDetails.message,
        );
      }
    } else if (event case WorkerFailureEvent()) {
      _error = event.message;
    } else {
      unawaited(_refreshSnapshot());
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshSnapshot() async {
    final worker = _worker;
    if (worker == null || worker.isClosed) return;
    try {
      final snapshot = await worker.snapshot('example');
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      _setError(error);
    }
  }

  void _setError(Object error) {
    _log('Error: $error');
    if (mounted) setState(() => _error = '$error');
  }

  Future<void> _perform(
    String status,
    Future<void> Function(NoosphereWorker worker) operation,
  ) async {
    final worker = _worker;
    if (worker == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = status;
    });
    try {
      await operation(worker);
    } catch (error, stackTrace) {
      _log('$status failed: $error\n$stackTrace');
      _error = '$error';
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Connected';
        });
      }
    }
  }

  Future<void> _createDkg() => _perform('Creating 2-of-2 key…', (worker) {
    final name = _dkgName.text.trim();
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

  Future<void> _requestSignature() =>
      _perform('Requesting signature…', (worker) {
        final snapshot = _snapshot;
        if (snapshot == null || snapshot.keys.isEmpty) {
          throw StateError('Complete the DKG first.');
        }
        final key = snapshot.keys.first;
        return worker.requestSignatures(
          'example',
          SignaturesRequestDetails(
            requiredSigs: [
              SingleSignatureDetails(
                signDetails: SignDetails.scriptSpend(
                  message: _parseHash(_messageHash.text),
                ),
                groupKey: ECCompressedPublicKey.fromHex(key.groupKeyHex),
                hdDerivation: const [],
              ),
            ],
            expiry: Expiry(const Duration(minutes: 3)),
          ),
        );
      });

  Future<void> _stop() async {
    setState(() {
      _busy = true;
      _status = 'Stopping…';
    });
    try {
      await _close();
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Stopped';
          _publishedIrohId = null;
        });
      }
    }
  }

  Future<void> _close({bool ignoreErrors = false}) async {
    _workerLifecycle?.detach();
    try {
      await _events?.cancel();
      await _worker?.close().timeout(const Duration(seconds: 10));
    } catch (error) {
      if (!ignoreErrors) rethrow;
      _log('Close failed: $error');
    } finally {
      _events = null;
      _snapshot = null;
      _worker = null;
      _workerLifecycle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Noosphere 2-of-2 test')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'TEST ONLY: deterministic keys and in-memory state.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TestMachine>(
            initialValue: _machine,
            decoration: const InputDecoration(labelText: 'This instance'),
            items: [
              for (final machine in TestMachine.values)
                DropdownMenuItem(value: machine, child: Text(machine.label)),
            ],
            onChanged: _running
                ? null
                : (machine) =>
                      setState(() => _machine = machine ?? TestMachine.a),
          ),
          const SizedBox(height: 8),
          if (_machine.runsSigner)
            SelectableText(
              'ROAST participant ${_machine.participant} public key: '
              '${_participantPublicKey.hex}',
            ),
          if (!_machine.hostsServer) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _irohId,
              enabled: !_running,
              decoration: const InputDecoration(
                labelText: 'Computer A Iroh ID',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: _busy || _running ? null : _start,
                child: const Text('Start'),
              ),
              OutlinedButton(
                onPressed: _busy || !_running ? null : _stop,
                child: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('State: $_status'),
          if (_publishedIrohId case final id?) SelectableText('Iroh ID: $id'),
          if (snapshot != null && snapshot.signerRunning) ...[
            Text(
              'Participant ${_machine.participant}; '
              'online peers: ${snapshot.onlineParticipants.length}',
            ),
            const Divider(height: 32),
            TextField(
              controller: _dkgName,
              decoration: const InputDecoration(labelText: 'DKG name'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy ? null : _createDkg,
              child: const Text('Create 2-of-2 key'),
            ),
            for (final dkg in snapshot.dkgs.where(
              (dkg) => dkg.stage == 'waiting',
            ))
              ListTile(
                title: Text('Pending DKG: ${dkg.name}'),
                trailing: FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(
                          'Accepting DKG…',
                          (worker) => worker.acceptDkg('example', dkg),
                        ),
                  child: const Text('Accept DKG'),
                ),
              ),
            for (final dkg in snapshot.dkgs.where(
              (dkg) => dkg.stage != 'waiting',
            ))
              Text(
                '${dkg.name}: ${dkg.stage}, '
                '${dkg.completedParticipants.length}/2',
              ),
            for (final key in snapshot.keys)
              SelectableText('Group key: ${key.groupKeyHex}'),
            const Divider(height: 32),
            TextField(
              controller: _messageHash,
              decoration: const InputDecoration(
                labelText: '32-byte hash (64 hex characters)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy || snapshot.keys.isEmpty
                  ? null
                  : _requestSignature,
              child: const Text('Request 2-of-2 signature'),
            ),
            for (final request in snapshot.signingRequests)
              ListTile(
                title: Text(
                  'Signature request: '
                  '${_hex(request.decodeProposal().requiredSigs.single.signDetails.message)}',
                ),
                subtitle: Text(request.status),
                trailing: request.status == 'waiting'
                    ? FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _perform(
                                'Accepting signature…',
                                (worker) =>
                                    worker.acceptSignatures('example', request),
                              ),
                        child: const Text('Accept signature'),
                      )
                    : null,
              ),
            if (_signature case final signature?) ...[
              SelectableText('Signed hash: $_signedHash'),
              SelectableText('Schnorr signature: $signature'),
              Text('Signature valid: $_signatureValid'),
            ],
          ],
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

final class _MemoryIdentityStore implements ServerIdentityStore {
  Uint8List? _secret;

  @override
  Future<Uint8List?> read() async =>
      _secret == null ? null : Uint8List.fromList(_secret!);

  @override
  Future<void> write(Uint8List secret) async {
    _secret = Uint8List.fromList(secret);
    _log('Stored the test server identity in memory.');
  }
}

void _logWorkerEndpoint(WorkerCoordinatorAddress address) => _log(
  'Iroh ID: ${address.id}\n'
  'Iroh IPs: ${address.ipAddrs}\n'
  'Iroh relays: ${address.relayUrls}',
);

void _log(String message) => stdout.writeln('[noosphere] $message');

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List _parseHash(String value) {
  final hex = value.trim();
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
    throw const FormatException(
      'Message hash must be exactly 64 hex characters.',
    );
  }
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

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
  b('Computer B · participant 2', 2);

  bool get hostsServer => this == a;
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
  NoosphereNode? _serverNode;
  NoosphereNode? _clientNode;
  NoosphereLifecycleObserver? _serverLifecycle;
  NoosphereLifecycleObserver? _clientLifecycle;
  StreamSubscription<Client>? _sessions;
  StreamSubscription<ClientEvent>? _events;
  Client? _client;
  EndpointId? _publishedIrohId;
  String _status = 'Stopped';
  String? _error;
  String? _signature;
  String? _signedHash;
  bool? _signatureValid;
  bool _busy = false;

  bool get _running => _clientNode != null || _serverNode != null;
  Identifier get _participantId => Identifier.fromUint16(_machine.participant);
  ECPrivateKey get _participantKey => _keys[_machine.participant - 1];
  ECCompressedPublicKey get _participantPublicKey =>
      ECCompressedPublicKey.fromPubkey(_participantKey.pubkey);

  @override
  void dispose() {
    _serverLifecycle?.detach();
    _clientLifecycle?.detach();
    unawaited(_sessions?.cancel());
    unawaited(_events?.cancel());
    unawaited(_clientNode?.close());
    unawaited(_serverNode?.close());
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
      final EndpointAddr address;
      final EndpointId pinnedId;
      if (_machine.hostsServer) {
        _serverNode = await NoosphereNode.start(
          server: EmbeddedServerOptions(
            serverConfig: ServerConfig(group: _group),
            identityStore: _identityStore,
          ),
        );
        _serverLifecycle = NoosphereLifecycleObserver(_serverNode!)..attach();
        address = await _reachableAddress(_serverNode!);
        pinnedId = address.id;
        _publishedIrohId = pinnedId;
        _logIrohEndpoint(address);
      } else {
        pinnedId = PublicKey.fromZ32(_irohId.text.trim());
        address = EndpointAddr(pinnedId);
      }

      _log(
        'ROAST participant ${_machine.participant} public key: '
        '${_participantPublicKey.hex}',
      );

      _clientNode = await NoosphereNode.start(
        client: ClientNodeOptions(
          clientConfig: ClientConfig(group: _group, id: _participantId),
          bootstrapAddress: address,
          pinnedServerId: pinnedId,
          storage: InMemoryClientStorage(),
          getPrivateKey: (_) async => _participantKey,
        ),
      );
      _clientLifecycle = NoosphereLifecycleObserver(_clientNode!)..attach();

      final reconnecting = _clientNode!.client!;
      _useClient(reconnecting.current);
      _sessions = reconnecting.sessions.listen(
        _useClient,
        onError: (Object error) => _setError(error),
      );
      setState(() {
        _busy = false;
        _status = 'Connected';
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

  Future<EndpointAddr> _reachableAddress(NoosphereNode node) async {
    final server = node.server!;
    final current = server.address;
    if (current.ipAddrs.isNotEmpty || current.relayUrls.isNotEmpty) {
      return current;
    }
    try {
      return await server.endpoint
          .watchAddr()
          .firstWhere(
            (address) =>
                address.ipAddrs.isNotEmpty || address.relayUrls.isNotEmpty,
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      return server.address;
    }
  }

  void _useClient(Client client) {
    unawaited(_events?.cancel());
    _client = client;
    _events = client.events.listen((event) {
      _log('ROAST event: ${event.runtimeType}');
      if (event case SignaturesCompleteClientEvent()) {
        final details = event.details.requiredSigs.single;
        final result = event.signatures.single;
        _signature = _hex(result.data);
        _signedHash = _hex(details.signDetails.message);
        _signatureValid = result.verify(
          details.groupKey,
          details.signDetails.message,
        );
      }
      if (mounted) setState(() {});
    }, onError: (Object error) => _setError(error));
    if (mounted) setState(() {});
  }

  void _setError(Object error) {
    _log('Error: $error');
    if (mounted) setState(() => _error = '$error');
  }

  Future<void> _perform(
    String status,
    Future<void> Function(Client client) operation,
  ) async {
    final client = _client;
    if (client == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = status;
    });
    try {
      await operation(client);
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

  Future<void> _createDkg() => _perform('Creating 2-of-2 key…', (client) {
    final name = _dkgName.text.trim();
    return client.requestDkg(
      NewDkgDetails(
        name: name,
        description: 'Two-computer Noosphere Flutter test',
        threshold: 2,
        expiry: Expiry(const Duration(hours: 1)),
      ),
    );
  });

  Future<void> _requestSignature() =>
      _perform('Requesting signature…', (client) {
        if (client.keys.isEmpty) {
          throw StateError('Complete the DKG first.');
        }
        final key = client.keys.values.first;
        return client.requestSignatures(
          SignaturesRequestDetails(
            requiredSigs: [
              SingleSignatureDetails(
                signDetails: SignDetails.scriptSpend(
                  message: _parseHash(_messageHash.text),
                ),
                groupKey: key.groupKey,
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
    _serverLifecycle?.detach();
    _clientLifecycle?.detach();
    try {
      await _sessions?.cancel();
      await _events?.cancel();
      try {
        await _clientNode?.close().timeout(const Duration(seconds: 5));
      } finally {
        await _serverNode?.close().timeout(const Duration(seconds: 5));
      }
    } catch (error) {
      if (!ignoreErrors) rethrow;
      _log('Close failed: $error');
    } finally {
      _sessions = null;
      _events = null;
      _client = null;
      _clientNode = null;
      _serverNode = null;
      _clientLifecycle = null;
      _serverLifecycle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
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
          if (_publishedIrohId case final id?)
            SelectableText('Iroh ID: ${id.toZ32()}'),
          if (client != null) ...[
            Text(
              'Participant ${_machine.participant}; '
              'online peers: ${client.onlineParticipants.length}',
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
            for (final dkg in client.dkgRequests)
              ListTile(
                title: Text('Pending DKG: ${dkg.details.name}'),
                trailing: FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(
                          'Accepting DKG…',
                          (client) => client.acceptDkg(dkg.details.name),
                        ),
                  child: const Text('Accept DKG'),
                ),
              ),
            for (final dkg in client.acceptedDkgs)
              Text(
                '${dkg.details.name}: ${dkg.stage.name}, '
                '${dkg.completed.length}/2',
              ),
            for (final key in client.keys.values)
              SelectableText('Group key: ${key.groupKey.hex}'),
            const Divider(height: 32),
            TextField(
              controller: _messageHash,
              decoration: const InputDecoration(
                labelText: '32-byte hash (64 hex characters)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy || client.keys.isEmpty
                  ? null
                  : _requestSignature,
              child: const Text('Request 2-of-2 signature'),
            ),
            for (final request in client.signaturesRequests)
              ListTile(
                title: Text(
                  'Signature request: '
                  '${_hex(request.details.requiredSigs.single.signDetails.message)}',
                ),
                subtitle: Text(request.status.name),
                trailing: request.status == SignaturesRequestStatus.waiting
                    ? FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _perform(
                                'Accepting signature…',
                                (client) => client.acceptSignaturesRequest(
                                  request.details.id,
                                ),
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

void _logIrohEndpoint(EndpointAddr address) => _log(
  'Iroh ID: ${address.id.toZ32()}\n'
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

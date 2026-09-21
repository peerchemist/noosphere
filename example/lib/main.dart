import 'dart:async';
import 'dart:convert';
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
    title: 'Noosphere ROAST',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: const NodeScreen(),
  );
}

enum NodeRole(final String label) {
  client('Client only'),
  server('Embedded server only'),
  both('Both roles');

  bool get hasServer => this == server || this == both;
  bool get hasClient => this == client || this == both;
}

final class NodeScreen extends StatefulWidget {
  const NodeScreen({super.key});

  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

final class _NodeScreenState extends State<NodeScreen> {
  final _bootstrapController = TextEditingController();
  final _pinnedIdController = TextEditingController();
  final _identityStore = _MemoryIdentityStore();
  final ECPrivateKey _participantKey = ECPrivateKey(Uint8List(32)..last = 1);

  late final GroupConfig _group = GroupConfig(
    id: 'noosphere-flutter-example',
    participants: {
      Identifier.fromUint16(1): ECCompressedPublicKey.fromPubkey(
        _participantKey.pubkey,
      ),
      Identifier.fromUint16(2): ECCompressedPublicKey.fromPubkey(
        ECPrivateKey(Uint8List(32)..last = 2).pubkey,
      ),
    },
  );

  NodeRole _role = NodeRole.client;
  NoosphereNode? _node;
  NoosphereLifecycleObserver? _lifecycle;
  StreamSubscription<Client>? _sessionsSubscription;
  StreamSubscription<ClientEvent>? _eventsSubscription;
  Client? _displayedClient;
  String _status = 'Stopped';
  String? _error;
  int _eventCount = 0;
  bool _busy = false;

  @override
  void dispose() {
    _lifecycle?.detach();
    unawaited(_sessionsSubscription?.cancel());
    unawaited(_eventsSubscription?.cancel());
    unawaited(_node?.close());
    _bootstrapController.dispose();
    _pinnedIdController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _log('Starting node with role: ${_role.name}');
    _logSecret('ROAST participant private key', _participantKey.data);
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Starting…';
    });

    try {
      final serverOptions = _role.hasServer
          ? EmbeddedServerOptions(
              serverConfig: ServerConfig(group: _group),
              identityStore: _identityStore,
            )
          : null;
      final clientOptions = _role.hasClient ? _clientOptions() : null;
      final node = await NoosphereNode.start(
        server: serverOptions,
        client: clientOptions,
      );
      final lifecycle = NoosphereLifecycleObserver(node)..attach();
      _node = node;
      _lifecycle = lifecycle;

      final address = node.serverAddress;
      if (address != null) {
        _log(
          'Iroh ID: ${address.id.toZ32()}\n'
          'Iroh address: ${base64Encode(address.encode())}\n'
          'Iroh IPs: ${address.ipAddrs}\n'
          'Iroh relays: ${address.relayUrls}',
        );
      }

      final reconnecting = node.client;
      if (reconnecting != null) {
        _replaceDisplayedClient(reconnecting.current);
        _sessionsSubscription = reconnecting.sessions.listen(
          _replaceDisplayedClient,
          onError: (Object error) {
            if (mounted) setState(() => _error = '$error');
          },
        );
      }

      if (mounted) {
        setState(() {
          _status = reconnecting == null ? 'Serving' : 'Connected';
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _status = 'Stopped';
          _busy = false;
        });
      }
    }
  }

  ClientNodeOptions _clientOptions() {
    if (_bootstrapController.text.trim().isEmpty ||
        _pinnedIdController.text.trim().isEmpty) {
      throw const FormatException(
        'Client roles require an independently trusted server ID and '
        'bootstrap address.',
      );
    }
    _log('Iroh bootstrap: ${_bootstrapController.text.trim()}');
    return ClientNodeOptions(
      clientConfig: ClientConfig(group: _group, id: Identifier.fromUint16(1)),
      bootstrapAddress: EndpointAddr.decode(
        base64Decode(_bootstrapController.text.trim()),
      ),
      pinnedServerId: PublicKey.fromZ32(_pinnedIdController.text.trim()),
      storage: InMemoryClientStorage(),
      getPrivateKey: (_) async => _participantKey,
    );
  }

  void _replaceDisplayedClient(Client client) {
    _log('ROAST session: ${identityHashCode(client)}');
    unawaited(_eventsSubscription?.cancel());
    _eventsSubscription = client.events.listen(
      (event) {
        _log('ROAST event: ${event.runtimeType} ($event)');
        if (mounted) setState(() => _eventCount++);
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = '$error');
      },
    );
    if (mounted) {
      setState(() {
        _displayedClient = client;
        _status = 'Connected';
      });
    }
  }

  Future<void> _stop() async {
    final node = _node;
    if (node == null) return;
    setState(() {
      _busy = true;
      _status = 'Stopping…';
    });
    _lifecycle?.detach();
    await _sessionsSubscription?.cancel();
    await _eventsSubscription?.cancel();
    try {
      await node.close().timeout(const Duration(seconds: 5));
    } finally {
      if (mounted) {
        setState(() {
          _node = null;
          _lifecycle = null;
          _displayedClient = null;
          _status = 'Stopped';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;
    final endpointId = node?.serverId?.toZ32();
    final address = node?.serverAddress;
    return Scaffold(
      appBar: AppBar(title: const Text('Noosphere ROAST desktop example')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Text(
              'DEMO ONLY: client state and the embedded-server identity are '
              'kept in memory. They are lost when this process exits. Use '
              'transactional durable client storage and OS secure storage in '
              'production.',
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<NodeRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Roles'),
            items: [
              for (final role in NodeRole.values)
                DropdownMenuItem(value: role, child: Text(role.label)),
            ],
            onChanged: node == null
                ? (role) => setState(() => _role = role ?? _role)
                : null,
          ),
          if (_role.hasClient) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pinnedIdController,
              enabled: node == null,
              decoration: const InputDecoration(
                labelText: 'Trusted server endpoint ID (z-base-32)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bootstrapController,
              enabled: node == null,
              decoration: const InputDecoration(
                labelText: 'Bootstrap address (base64)',
                helperText: 'Both-role mode uses a dedicated client endpoint.',
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton(
                onPressed: _busy || node != null ? null : _start,
                child: const Text('Start'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _busy || node == null ? null : _stop,
                child: const Text('Logout / shut down'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('State: $_status'),
          if (endpointId != null)
            SelectableText('Server endpoint ID: $endpointId'),
          if (address != null)
            SelectableText(
              'Bootstrap address: ${base64Encode(address.encode())}',
            ),
          if (_displayedClient case final client?)
            Text('Client session: ${identityHashCode(client)}'),
          if (_role.hasClient) Text('Client events received: $_eventCount'),
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 20),
          const Text(
            'An embedded server is reachable only while this desktop process '
            'is alive. Window focus changes do not stop it.',
          ),
        ],
      ),
    );
  }
}

final class _MemoryIdentityStore implements ServerIdentityStore {
  Uint8List? _secret;

  @override
  Future<Uint8List?> read() async {
    if (_secret != null) _logSecret('Iroh server private key', _secret!);
    return _secret == null ? null : Uint8List.fromList(_secret!);
  }

  @override
  Future<void> write(Uint8List secret) async {
    _secret = Uint8List.fromList(secret);
    _logSecret('Iroh server private key', secret);
  }
}

void _log(String message) => stdout.writeln('[noosphere] $message');

void _logSecret(String name, Iterable<int> bytes) =>
    stderr.writeln('[noosphere][SECRET] $name: ${_hex(bytes)}');

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

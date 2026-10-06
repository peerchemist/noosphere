part of '../worker_runtime.dart';

typedef WorkerEventSink = void Function(NoosphereWorkerEvent event);

final class WorkerSetupRuntime {
  WorkerSetupRuntime({
    required this.setupId,
    required this.generation,
    required this.host,
    required this.emit,
    this.nodeFactory = startWorkerNode,
  });

  final String setupId;
  final int generation;
  final WorkerHost host;
  final WorkerNodeFactory nodeFactory;
  final WorkerEventSink emit;
  WorkerNode? _serverNode;
  WorkerNode? _clientNode;
  Client? _client;
  ClientNodeOptions? _clientOptions;
  String? _participant;
  StreamSubscription<Client>? _sessions;
  final _events = SessionDelivery<ClientEvent>();
  Timer? _serverAddressPoll;
  EndpointAddr? _serverAddress;
  final _serial = SerialExecutor();

  bool get hasRoles => _serverNode != null || _clientNode != null;

  Future<void> start({
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  }) => _synchronized(() async {
    if (server == null && client == null) {
      throw ArgumentError('At least one worker role is required.');
    }
    final startedServer = server != null && _serverNode == null;
    if (server != null && _serverNode != null) {
      throw StateError('Server role is already running.');
    }
    if (client != null && _clientNode != null) {
      throw StateError('Signer role is already running.');
    }

    try {
      if (server != null) {
        final node = await nodeFactory(server: server);
        _serverNode = node;
        _serverAddress = node.serverAddress;
        unawaited(
          node.serverDone!.then(
            (termination) => _serverTerminated(node, termination),
          ),
        );
        // Iroh's reactive-stream cancellation registry is process-wide while
        // Dart library statics are isolate-local. Polling the cheap address
        // snapshot keeps workers on the published Iroh API and avoids sharing
        // stream tokens across Dart isolates.
        _serverAddressPoll = Timer.periodic(
          const Duration(milliseconds: 100),
          (_) => _refreshServerAddress(node),
        );
      }
      if (client != null) {
        await _startSigner(client);
      }
      _emitSnapshot();
    } catch (error, stackTrace) {
      Object? cleanupError;
      try {
        if (client != null) await _stopSigner();
      } catch (failure) {
        cleanupError = failure;
      }
      try {
        if (startedServer) await _stopServer();
      } catch (failure) {
        cleanupError ??= failure;
      }
      if (cleanupError != null) {
        throw const NoosphereWorkerException(
          'startup_cleanup_failed',
          'Startup failed and role cleanup is incomplete. Stop the setup or close the worker before retrying.',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  });

  Future<void> _startSigner(
    ClientNodeOptions options, {
    bool replacement = false,
  }) async {
    _participant = options.clientConfig.id.toString();
    final localServer = _serverNode;
    WorkerNode? localNode;
    if (localServer case final LocalCoordinatorWorkerNode local) {
      localNode = await local.tryStartLocalClient(options);
    }
    final node = localNode ?? await nodeFactory(client: options);
    _clientNode = node;
    _clientOptions = options;
    await _attachClient(node.client!.current, replacement: replacement);
    _sessions = node.client!.sessions.listen(
      (client) => unawaited(
        _synchronized(() async {
          if (identical(_clientNode, node)) {
            await _attachClient(client, replacement: true);
          }
        }).catchError((Object error) => _failure('reconnect', error, true)),
      ),
      onError: (Object error) => _failure('reconnect', error, true),
    );
  }

  Future<void> _attachClient(Client client, {required bool replacement}) async {
    _client = client;
    await _events.attach(
      client.events,
      event: _onClientEvent,
      error: (error) => _failure('session', error, true),
      snapshot: _emitSnapshot,
      replaced: replacement
          ? () => emit(WorkerSessionReplacedEvent(setupId, generation))
          : null,
    );
  }

  Future<coinlib.ECPrivateKey> _getPrivateKey(KeyPurpose purpose) async {
    final bytes = await host.request(setupId, ProviderOperation.getPrivateKey, {
      'purpose': purpose.index,
      'participant': _participant,
    });
    return coinlib.ECPrivateKey(asBytes(bytes));
  }

  Future<Object?> requestDkg(NewDkgDetails details) =>
      _withClient((client) => client.requestDkg(details));

  Future<Object?> updateSignerAddress(EndpointAddr address) =>
      _synchronized(() async {
        final options = _clientOptions;
        final client = _clientNode?.client;
        if (options == null || client == null) {
          throw StateError('Signer is not running.');
        }
        if (address.id != options.pinnedServerId) {
          throw ArgumentError('Coordinator ID does not match the pinned ID.');
        }
        final updated = options.withCoordinator(address);
        client.updateTransportConfig(updated.toTransportConfig());
        _clientOptions = updated;
        return null;
      });

  Future<Object?> respondDkg({
    required String name,
    required Uint8List proposalBytes,
    required bool accept,
  }) => _withClient((client) async {
    final candidates = accept
        ? client.dkgRequests
        : [...client.dkgRequests, ...client.acceptedDkgs];
    final current = candidates.where((dkg) => dkg.details.name == name);
    if (current.isEmpty ||
        !_bytesEqual(current.single.details.toBytes(), proposalBytes)) {
      throw StateError('DKG proposal changed or is no longer pending.');
    }
    if (accept) {
      await client.acceptDkg(name);
    } else {
      await client.rejectDkg(name);
    }
  });

  Future<Object?> requestSignatures(SignaturesRequestDetails details) =>
      _withClient((client) => client.requestSignatures(details));

  Future<Object?> respondSignatures({
    required SignaturesRequestId id,
    required Uint8List proposalBytes,
    required bool accept,
  }) => _withClient((client) async {
    final current = client.signaturesRequests.where(
      (request) => request.details.id == id,
    );
    if (current.isEmpty ||
        !_bytesEqual(current.single.details.toBytes(), proposalBytes)) {
      throw StateError('Signing proposal changed or is no longer pending.');
    }
    if (accept) {
      await client.acceptSignaturesRequest(id);
    } else {
      await client.rejectSignaturesRequest(id);
    }
  });

  Future<Object?> _withClient(Future<void> Function(Client client) operation) =>
      _synchronized(() async {
        final client = _client;
        if (client == null || _clientNode?.client?.isConnected != true) {
          throw StateError('Signer is not connected.');
        }
        await operation(client);
        _emitSnapshot();
        return null;
      });

  Future<Object?> stopRoles(NoosphereWorkerRoles roles) =>
      _synchronized(() async {
        Object? failure;
        try {
          if (roles != NoosphereWorkerRoles.server) await _stopSigner();
        } catch (error) {
          failure = error;
        }
        try {
          if (roles != NoosphereWorkerRoles.signer) await _stopServer();
        } catch (error) {
          failure ??= error;
        }
        _emitSnapshot();
        if (failure != null) throw failure;
        return null;
      });

  Future<NoosphereWorkerSnapshot> switchCoordinator(EndpointAddr address) =>
      _synchronized(() async {
        final previous = _clientOptions;
        if (previous == null) throw StateError('Signer is not configured.');
        await _stopSigner();
        _emitSnapshot();
        final state = await previous.storage.loadState();
        if (state.preparedOperations.isNotEmpty ||
            state.sigNonces.values.any(
              (nonces) => nonces.expiry.time.isAfter(DateTime.now()),
            )) {
          throw const NoosphereWorkerException(
            'pending_signing_operations',
            'Reconcile pending signing operations before switching the coordinator.',
          );
        }
        await host.request(
          setupId,
          ProviderOperation.persistCoordinator,
          const {},
        );
        final updated = previous.withCoordinator(address);
        try {
          await _startSigner(updated, replacement: true);
        } catch (_) {
          await _stopSigner();
          // Retain only the committed selection for an explicit retry.
          _clientOptions = updated;
          rethrow;
        }
        return snapshot();
      });

  Future<void> _stopSigner() async {
    final node = _clientNode;
    _client = null;
    _clientOptions = null;
    _participant = null;
    Object? failure;
    try {
      await _sessions?.cancel();
    } catch (error) {
      failure = error;
    }
    _sessions = null;
    try {
      await _events.cancel();
    } catch (error) {
      failure ??= error;
    }
    try {
      await node?.close();
      _clientNode = null;
    } catch (error) {
      failure ??= error;
    }
    if (failure != null) throw failure;
  }

  Future<void> _stopServer() async {
    final node = _serverNode;
    _serverAddress = null;
    _serverAddressPoll?.cancel();
    _serverAddressPoll = null;
    await node?.close();
    _serverNode = null;
  }

  Future<void> _serverTerminated(
    WorkerNode node,
    ServerRuntimeTermination termination,
  ) => _synchronized(() async {
    if (!identical(_serverNode, node)) return;
    Object? cleanupError;
    try {
      await _stopServer();
    } catch (error) {
      cleanupError = error;
    }
    _emitSnapshot();
    _failure(
      'serve',
      termination.error ??
          cleanupError ??
          StateError('Server stopped unexpectedly.'),
      false,
    );
  });

  void _refreshServerAddress(WorkerNode node) {
    if (!identical(_serverNode, node)) return;
    try {
      final address = node.serverAddress;
      if (address == null || _sameAddress(_serverAddress, address)) return;
      _serverAddress = address;
      _emitSnapshot();
    } catch (error) {
      _serverAddressPoll?.cancel();
      _serverAddressPoll = null;
      _failure('serverAddress', error, false);
    }
  }

  Future<void> close() => _synchronized(() async {
    Object? firstError;
    try {
      await _stopSigner();
    } catch (error) {
      firstError = error;
    }
    try {
      await _stopServer();
    } catch (error) {
      firstError ??= error;
    }
    if (firstError != null) throw firstError;
  });

  Future<T> _synchronized<T>(Future<T> Function() operation) =>
      _serial.run(operation);

  late final _mapper = WorkerDtoMapper(setupId, generation, emit);
  NoosphereWorkerSnapshot snapshot() => _mapper.snapshot(
    client: _client,
    serverRunning: _serverNode?.serverRunning == true,
    signerRunning: _clientNode != null,
    connected: _clientNode?.client?.isConnected == true,
    serverAddress: _serverAddress,
  );

  void _onClientEvent(ClientEvent event) =>
      _mapper.event(event, client: _client);

  void _emitSnapshot() => emit(WorkerSnapshotEvent(snapshot()));

  void _failure(String operation, Object error, bool interrupted) => emit(
    WorkerFailureEvent(
      setupId,
      generation,
      operation: operation,
      message: error is String ? error : _safeError(error),
      interrupted: interrupted,
    ),
  );
}

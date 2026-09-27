part of '../worker_runtime.dart';

typedef _Emit = void Function(NoosphereWorkerEvent event);

final class _SetupRuntime {
  _SetupRuntime({
    required this.setupId,
    required this.generation,
    required this.host,
    required this.emit,
  });

  final String setupId;
  final int generation;
  final _HostBridge host;
  final _Emit emit;
  NoosphereNode? _serverNode;
  NoosphereNode? _clientNode;
  Client? _client;
  ClientNodeOptions? _clientOptions;
  String? _participant;
  StreamSubscription<Client>? _sessions;
  StreamSubscription<ClientEvent>? _events;
  Timer? _serverAddressPoll;
  EndpointAddr? _serverAddress;
  final _serial = SerialExecutor();

  bool get hasRoles => _serverNode != null || _clientNode != null;

  Future<void> start({
    required Map<Object?, Object?>? serverMessage,
    required Map<Object?, Object?>? clientMessage,
  }) => _synchronized(() async {
    if (serverMessage == null && clientMessage == null) {
      throw ArgumentError('At least one worker role is required.');
    }
    final startedServer = serverMessage != null && _serverNode == null;
    if (serverMessage != null && _serverNode != null) {
      throw StateError('Server role is already running.');
    }
    if (clientMessage != null && _clientNode != null) {
      throw StateError('Signer role is already running.');
    }

    try {
      if (serverMessage != null) {
        final options = decodeServerOptions(
          serverMessage,
          _RemoteIdentityStore(host, setupId),
          _RemoteServerPersistence(host, setupId),
          _RemoteRoomPersistence(host, setupId),
        );
        final node = await NoosphereNode.startInitialized(server: options);
        _serverNode = node;
        _serverAddress = node.server!.address;
        // Iroh's reactive-stream cancellation registry is process-wide while
        // Dart library statics are isolate-local. Polling the cheap address
        // snapshot keeps workers on the published Iroh API and avoids sharing
        // stream tokens with direct-node isolates.
        _serverAddressPoll = Timer.periodic(
          const Duration(milliseconds: 100),
          (_) => _refreshServerAddress(node),
        );
      }
      if (clientMessage != null) {
        final options = decodeClientOptions(
          clientMessage,
          _RemoteClientStorage(host, setupId),
          (purpose) => _getPrivateKey(purpose),
        );
        _participant = options.clientConfig.id.toString();
        final node = await NoosphereNode.startInitialized(client: options);
        _clientNode = node;
        _clientOptions = options;
        await _attachClient(node.client!.current, replacement: false);
        _sessions = node.client!.sessions.listen(
          (client) => unawaited(
            _synchronized(() => _attachClient(client, replacement: true)),
          ),
          onError: (Object error) => _failure('reconnect', error, true),
        );
      }
      _emitSnapshot();
    } catch (_) {
      if (clientMessage != null && _clientNode != null) {
        await _stopSigner();
      } else if (clientMessage != null) {
        _participant = null;
      }
      if (startedServer && _serverNode != null) {
        await _stopServer();
      }
      rethrow;
    }
  });

  Future<void> _attachClient(Client client, {required bool replacement}) async {
    await _events?.cancel();
    _client = client;
    _events = client.events.listen(
      _onClientEvent,
      onError: (Object error) => _failure('session', error, true),
    );
    if (replacement) {
      emit(WorkerSessionReplacedEvent(setupId, generation));
    }
    _emitSnapshot();
  }

  Future<coinlib.ECPrivateKey> _getPrivateKey(KeyPurpose purpose) async {
    final bytes = await host.request(setupId, 'getPrivateKey', {
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
        final updated = ClientNodeOptions(
          clientConfig: options.clientConfig,
          bootstrapAddress: address,
          pinnedServerId: options.pinnedServerId,
          storage: options.storage,
          getPrivateKey: options.getPrivateKey,
          relay: options.relay,
          alpn: options.alpn,
          connectTimeout: options.connectTimeout,
          authTimeout: options.authTimeout,
          rpcTimeout: options.rpcTimeout,
          maxEnvelopeLength: options.maxEnvelopeLength,
          maxConcurrentStreams: options.maxConcurrentStreams,
          reconnect: options.reconnect,
        );
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
        if (roles != NoosphereWorkerRoles.server) await _stopSigner();
        if (roles != NoosphereWorkerRoles.signer) await _stopServer();
        _emitSnapshot();
        return null;
      });

  Future<void> _stopSigner() async {
    final node = _clientNode;
    _clientNode = null;
    _client = null;
    _clientOptions = null;
    _participant = null;
    await _sessions?.cancel();
    await _events?.cancel();
    _sessions = null;
    _events = null;
    await node?.close();
  }

  Future<void> _stopServer() async {
    final node = _serverNode;
    _serverNode = null;
    _serverAddress = null;
    _serverAddressPoll?.cancel();
    _serverAddressPoll = null;
    await node?.close();
  }

  void _refreshServerAddress(NoosphereNode node) {
    if (!identical(_serverNode, node)) return;
    try {
      final address = node.server!.address;
      if (_sameAddress(_serverAddress, address)) return;
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

  NoosphereWorkerSnapshot snapshot() {
    final client = _client;
    final server = _serverNode?.server;
    final serverAddress = _serverAddress ?? server?.address;
    return NoosphereWorkerSnapshot(
      setupId: setupId,
      generation: generation,
      serverRunning: server != null,
      signerRunning: _clientNode != null,
      connected: _clientNode?.client?.isConnected == true,
      coordinator: server == null || serverAddress == null
          ? null
          : WorkerCoordinatorAddress(
              id: server.id.toZ32(),
              relayUrls: [for (final url in serverAddress.relayUrls) url.value],
              ipAddrs: serverAddress.ipAddrs,
            ),
      onlineParticipants: client == null
          ? const []
          : [for (final id in client.onlineParticipants) id.toString()],
      dkgs: client == null
          ? const []
          : [
              for (final dkg in client.dkgRequests)
                _dkgStatus(dkg, stage: 'waiting'),
              for (final dkg in client.acceptedDkgs) _dkgStatus(dkg),
            ],
      signingRequests: client == null
          ? const []
          : [
              for (final request in client.signaturesRequests)
                _signing(request),
            ],
      keys: client == null
          ? const []
          : [for (final key in client.keys.values) _key(key)],
    );
  }

  WorkerDkgStatus _dkgStatus(DkgInProgress progress, {String? stage}) =>
      WorkerDkgStatus(
        name: progress.details.name,
        description: progress.details.description,
        threshold: progress.details.threshold,
        expiry: progress.expiry.time,
        creator: progress.creator.toString(),
        stage: stage ?? progress.stage.name,
        completedParticipants: [
          for (final id in progress.completed) id.toString(),
        ],
        proposalBytes: progress.details.toBytes(),
      );

  WorkerSigningRequest _signing(SignaturesRequest request) =>
      WorkerSigningRequest(
        id: request.details.id.toBytes(),
        proposalBytes: request.details.toBytes(),
        creator: request.creator.toString(),
        expiry: request.expiry.time,
        status: request.status.name,
      );

  WorkerKeyInfo _key(FrostKeyWithDetails key) => WorkerKeyInfo(
    groupKeyHex: key.groupKey.hex,
    name: key.name,
    description: key.description,
  );

  void _onClientEvent(ClientEvent event) {
    switch (event) {
      case ParticipantStatusClientEvent():
        emit(
          WorkerParticipantEvent(
            setupId,
            generation,
            participant: event.id.toString(),
            online: event.loggedIn,
          ),
        );
      case UpdatedDkgClientEvent():
        final waitingForLocalApproval =
            _client?.dkgRequests.any(
              (dkg) => dkg.details.name == event.progress.details.name,
            ) ==
            true;
        emit(
          WorkerDkgEvent(
            setupId,
            generation,
            status: _dkgStatus(
              event.progress,
              stage: waitingForLocalApproval ? 'waiting' : null,
            ),
          ),
        );
      case RejectedDkgClientEvent():
        emit(
          WorkerDkgEvent(
            setupId,
            generation,
            status: WorkerDkgStatus(
              name: event.details.name,
              description: event.details.description,
              threshold: event.details.threshold,
              expiry: event.details.expiry.time,
              creator: event.participant?.toString() ?? '',
              stage: 'rejected',
              completedParticipants: const [],
              proposalBytes: event.details.toBytes(),
            ),
            rejected: true,
            failure: event.fault.name,
          ),
        );
      case SignaturesRequestClientEvent():
        emit(
          WorkerSigningRequestEvent(
            setupId,
            generation,
            request: _signing(event.request),
          ),
        );
      case SignaturesFailureClientEvent():
        _failure('signatures', 'Signing request failed.', false);
      case SignaturesExpiryClientEvent():
        _failure('signatures', 'Signing request expired.', false);
      case SignaturesCompleteClientEvent():
        emit(
          WorkerSigningResultEvent(
            setupId,
            generation,
            requestId: event.details.id.toBytes(),
            proposalBytes: event.details.toBytes(),
            creator: event.creator.toString(),
            signatures: [
              for (final signature in event.signatures) signature.data,
            ],
          ),
        );
      case SecretShareClientEvent():
        emit(
          WorkerKeyUpdatedEvent(
            setupId,
            generation,
            key: _key(event.keyDetails),
          ),
        );
    }
  }

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

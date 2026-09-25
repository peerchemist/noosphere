import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:iroh_flutter/iroh_flutter.dart' show EndpointAddr;
import 'package:meta/meta.dart';
import 'package:noosphere_server/noosphere_server.dart';

import 'initialization.dart';
import 'iroh_node.dart';
import 'server_identity_store.dart';
import 'worker_models.dart';
import 'worker_protocol.dart';

@pragma('vm:entry-point')
@RecordUse()
Future<void> runNoosphereWorker(Map<Object?, Object?> bootstrap) async {
  final hostPort = bootstrap['hostPort']! as SendPort;
  final generation = bootstrap['generation']! as int;
  final maxMessageBytes = bootstrap['maxMessageBytes']! as int;
  final maxOutstandingHostRequests =
      bootstrap['maxOutstandingHostRequests']! as int;
  final skipInitialization = bootstrap['skipInitialization'] == true;
  final receivePort = ReceivePort('Noosphere worker $generation');

  try {
    if (!skipInitialization) await NoosphereFlutter.initializeNative();
    final runtime = _WorkerRuntime(
      generation: generation,
      hostPort: hostPort,
      receivePort: receivePort,
      maxMessageBytes: maxMessageBytes,
      maxOutstandingHostRequests: maxOutstandingHostRequests,
    );
    hostPort.send({
      'version': workerProtocolVersion,
      'generation': generation,
      'type': 'ready',
      'port': receivePort.sendPort,
    });
    await runtime.run();
  } catch (error) {
    hostPort.send({
      'version': workerProtocolVersion,
      'generation': generation,
      'type': 'startupError',
      'code': _errorCode(error),
      'message': _safeError(error),
    });
    receivePort.close();
  }
}

final class _WorkerRuntime {
  _WorkerRuntime({
    required this.generation,
    required this.hostPort,
    required this.receivePort,
    required this.maxMessageBytes,
    required int maxOutstandingHostRequests,
  }) : _host = _HostBridge(
         hostPort,
         generation,
         maxMessageBytes,
         maxOutstandingHostRequests,
       );

  final int generation;
  final SendPort hostPort;
  final ReceivePort receivePort;
  final int maxMessageBytes;
  final _setups = <String, _SetupRuntime>{};
  final _done = Completer<void>();
  final _HostBridge _host;
  bool _closing = false;

  Future<void> run() async {
    receivePort.listen((raw) {
      if (raw is! Map) return;
      final message = raw.cast<Object?, Object?>();
      if (message['generation'] != generation ||
          message['version'] != workerProtocolVersion) {
        return;
      }
      if (message['type'] == 'hostReply') {
        _host.complete(message);
        return;
      }
      unawaited(_handleCommand(message));
    });
    await _done.future;
  }

  Future<void> _handleCommand(Map<Object?, Object?> message) async {
    final id = message['commandId'];
    if (id is! int || message['type'] != 'command') return;
    if (approximateMessageBytes(message) > maxMessageBytes) {
      _replyError(id, 'message_too_large', 'Command exceeds worker limit.');
      return;
    }
    if (_closing && message['operation'] != 'close') {
      _replyError(id, 'worker_closing', 'Worker is closing.');
      return;
    }

    try {
      final operation = message['operation']! as String;
      final setupId = message['setupId'] as String?;
      final payload = message['payload'] as Map<Object?, Object?>? ?? const {};
      final Object? result;
      switch (operation) {
        case 'startSetup':
          result = await _startSetup(setupId!, payload);
        case 'stopRoles':
          result = await _setup(setupId!)
              .stopRoles(NoosphereWorkerRoles.values[payload['roles']! as int]);
          if (!_setup(setupId).hasRoles) _setups.remove(setupId);
        case 'snapshot':
          result = _setup(setupId!).snapshot();
        case 'requestDkg':
          result = await _setup(
            setupId!,
          ).requestDkg(NewDkgDetails.fromBytes(asBytes(payload['proposal'])));
        case 'acceptDkg':
          result = await _setup(setupId!).respondDkg(
            name: payload['name']! as String,
            proposalBytes: asBytes(payload['proposal']),
            accept: true,
          );
        case 'rejectDkg':
          result = await _setup(setupId!).respondDkg(
            name: payload['name']! as String,
            proposalBytes: asBytes(payload['proposal']),
            accept: false,
          );
        case 'requestSignatures':
          result = await _setup(setupId!).requestSignatures(
            SignaturesRequestDetails.fromBytes(asBytes(payload['proposal'])),
          );
        case 'acceptSignatures':
          result = await _setup(setupId!).respondSignatures(
            id: SignaturesRequestId.fromBytes(asBytes(payload['id'])),
            proposalBytes: asBytes(payload['proposal']),
            accept: true,
          );
        case 'rejectSignatures':
          result = await _setup(setupId!).respondSignatures(
            id: SignaturesRequestId.fromBytes(asBytes(payload['id'])),
            proposalBytes: asBytes(payload['proposal']),
            accept: false,
          );
        case 'close':
          result = await _close();
        default:
          throw ArgumentError.value(operation, 'operation', 'unknown command');
      }
      _reply(id, result);
      if (operation == 'close') {
        receivePort.close();
        if (!_done.isCompleted) _done.complete();
      }
    } catch (error) {
      _replyError(id, _errorCode(error), _safeError(error));
    }
  }

  _SetupRuntime _setup(String id) {
    final setup = _setups[id];
    if (setup == null) throw StateError('Unknown setup.');
    return setup;
  }

  Future<Object?> _startSetup(
    String setupId,
    Map<Object?, Object?> payload,
  ) async {
    final setup = _setups.putIfAbsent(
      setupId,
      () => _SetupRuntime(
        setupId: setupId,
        generation: generation,
        host: _host,
        emit: _emit,
      ),
    );
    try {
      await setup.start(
        serverMessage: payload['server'] as Map<Object?, Object?>?,
        clientMessage: payload['client'] as Map<Object?, Object?>?,
      );
      return setup.snapshot();
    } catch (_) {
      if (!setup.hasRoles) _setups.remove(setupId);
      rethrow;
    }
  }

  Future<Object?> _close() async {
    if (_closing) return null;
    _closing = true;
    Object? firstError;
    for (final setup in _setups.values.toList().reversed) {
      try {
        await setup.close();
      } catch (error) {
        firstError ??= error;
      }
    }
    _setups.clear();
    _host.close();
    if (firstError != null) throw firstError;
    return null;
  }

  void _emit(NoosphereWorkerEvent event) {
    final message = <String, Object?>{
      'version': workerProtocolVersion,
      'generation': generation,
      'type': 'event',
      'event': event,
    };
    if (approximateMessageBytes(message) <= maxMessageBytes) {
      hostPort.send(message);
    } else {
      hostPort.send({
        'version': workerProtocolVersion,
        'generation': generation,
        'type': 'event',
        'event': WorkerFailureEvent(
          event.setupId,
          generation,
          operation: 'event',
          message: 'Worker event exceeded the configured message limit.',
        ),
      });
    }
  }

  void _reply(int id, Object? result) {
    final message = <String, Object?>{
      'version': workerProtocolVersion,
      'generation': generation,
      'type': 'reply',
      'commandId': id,
      'ok': true,
      'result': result,
    };
    if (approximateMessageBytes(message) > maxMessageBytes) {
      _replyError(id, 'message_too_large', 'Reply exceeds worker limit.');
    } else {
      hostPort.send(message);
    }
  }

  void _replyError(int id, String code, String message) => hostPort.send({
    'version': workerProtocolVersion,
    'generation': generation,
    'type': 'reply',
    'commandId': id,
    'ok': false,
    'code': code,
    'message': message,
  });
}

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
  String? _participant;
  StreamSubscription<Client>? _sessions;
  StreamSubscription<ClientEvent>? _events;
  StreamSubscription<EndpointAddr>? _serverAddresses;
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
        );
        final node = await NoosphereNode.startInitialized(server: options);
        _serverNode = node;
        _serverAddress = node.server!.address;
        _serverAddresses = node.server!.endpoint.watchAddr().listen((address) {
          _serverAddress = address;
          _emitSnapshot();
        }, onError: (Object error) => _failure('serverAddress', error, false));
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

  Future<Object?> respondDkg({
    required String name,
    required Uint8List proposalBytes,
    required bool accept,
  }) => _withClient((client) async {
    final current = client.dkgRequests.where((dkg) => dkg.details.name == name);
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
    await _serverAddresses?.cancel();
    _serverAddresses = null;
    await node?.close();
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
        emit(
          WorkerDkgEvent(
            setupId,
            generation,
            status: _dkgStatus(event.progress),
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

final class _HostBridge {
  _HostBridge(
    this.port,
    this.generation,
    this.maxMessageBytes,
    this.maxOutstandingRequests,
  );

  final SendPort port;
  final int generation;
  final int maxMessageBytes;
  final int maxOutstandingRequests;
  final _pending = <int, Completer<Object?>>{};
  int _nextId = 1;
  bool _closed = false;

  Future<Object?> request(
    String setupId,
    String operation,
    Map<String, Object?> payload,
  ) {
    if (_closed) throw StateError('Host bridge is closed.');
    if (_pending.length >= maxOutstandingRequests) {
      throw StateError('Too many host requests are outstanding.');
    }
    final id = _nextId++;
    final message = <String, Object?>{
      'version': workerProtocolVersion,
      'generation': generation,
      'type': 'hostRequest',
      'hostRequestId': id,
      'setupId': setupId,
      'operation': operation,
      'payload': payload,
    };
    if (approximateMessageBytes(message) > maxMessageBytes) {
      throw StateError('Host request exceeds worker message limit.');
    }
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send(message);
    return completer.future;
  }

  void complete(Map<Object?, Object?> message) {
    final id = message['hostRequestId'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (message['ok'] == true) {
      completer.complete(message['result']);
    } else {
      completer.completeError(
        NoosphereWorkerException(
          message['code'] as String? ?? 'host_failure',
          message['message'] as String? ?? 'Host operation failed.',
        ),
      );
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final completer in _pending.values) {
      completer.completeError(
        const NoosphereWorkerException(
          'worker_closing',
          'Worker closed during a host operation.',
        ),
      );
    }
    _pending.clear();
  }
}

final class _RemoteIdentityStore(this.host, this.setupId)
    implements ServerIdentityStore {
  final _HostBridge host;
  final String setupId;

  @override
  Future<Uint8List?> read() async {
    final result = await host.request(setupId, 'identity.read', const {});
    return result == null ? null : asBytes(result);
  }

  @override
  Future<void> write(Uint8List secret) =>
      host.request(setupId, 'identity.write', {'secret': secret}).then((_) {});
}

final class _RemoteClientStorage(this.host, this.setupId)
    implements ClientStorageInterface {
  final _HostBridge host;
  final String setupId;

  @override
  Future<void> addOrReplaceFrostKey(FrostKeyWithDetails newKey) => host
      .request(setupId, 'storage.addKey', {'key': newKey.toBytes()})
      .then((_) {});

  @override
  Future<void> addSignaturesNonces(
    SignaturesRequestId id,
    SignaturesNonces nonces,
    int capacity,
  ) => host
      .request(setupId, 'storage.addNonces', {
        'id': id.toBytes(),
        'nonces': encodeSignaturesNonces(nonces),
        'capacity': capacity,
      })
      .then((_) {});

  @override
  Future<void> prepareSignaturesOperation(
    PreparedSignaturesOperation operation,
    int capacity,
  ) => host
      .request(setupId, 'storage.prepareSignatures', {
        'operation': operation.toBytes(),
        'capacity': capacity,
      })
      .then((_) {});

  @override
  Future<void> completeSignaturesOperation(SignaturesRequestId id) => host
      .request(setupId, 'storage.completeSignatures', {'id': id.toBytes()})
      .then((_) {});

  @override
  Future<void> addRejectedSigsRequest(
    SignaturesRequestId id,
    FinalExpirable expirable,
  ) => host
      .request(setupId, 'storage.addRejection', {
        'id': id.toBytes(),
        'expiryMicros': expirable.expiry.time.microsecondsSinceEpoch,
      })
      .then((_) {});

  @override
  Future<void> removeRejectionOfSigsRequest(SignaturesRequestId id) => host
      .request(setupId, 'storage.removeRejection', {'id': id.toBytes()})
      .then((_) {});

  @override
  Future<void> removeSigsRequest(SignaturesRequestId id) => host
      .request(setupId, 'storage.removeSignatures', {'id': id.toBytes()})
      .then((_) {});

  @override
  Future<Set<FrostKeyWithDetails>> loadKeys() async {
    final values = await host.request(setupId, 'storage.loadKeys', const {});
    return {
      for (final value in values! as List)
        FrostKeyWithDetails.fromBytes(asBytes(value)),
    };
  }

  @override
  Future<Map<SignaturesRequestId, SignaturesNonces>> loadSigNonces() async {
    final values = await host.request(setupId, 'storage.loadNonces', const {});
    return {
      for (final value in values! as List)
        SignaturesRequestId.fromBytes(
          asBytes((value as Map<Object?, Object?>)['id']),
        ): decodeSignaturesNonces(
          value['nonces']! as Map<Object?, Object?>,
        ),
    };
  }

  @override
  Future<Map<SignaturesRequestId, PreparedSignaturesOperation>>
  loadPreparedSignaturesOperations() async {
    final values = await host.request(
      setupId,
      'storage.loadPreparedSignatures',
      const {},
    );
    final operations = [
      for (final value in values! as List)
        PreparedSignaturesOperation.fromBytes(asBytes(value)),
    ];
    return {for (final operation in operations) operation.id: operation};
  }

  @override
  Future<Map<SignaturesRequestId, FinalExpirable>>
  loadRejectedSigsRequests() async {
    final values = await host.request(
      setupId,
      'storage.loadRejections',
      const {},
    );
    return {
      for (final value in values! as List)
        SignaturesRequestId.fromBytes(
          asBytes((value as Map<Object?, Object?>)['id']),
        ): FinalExpirable(
          Expiry.fromTime(
            DateTime.fromMicrosecondsSinceEpoch(value['expiryMicros']! as int),
          ),
        ),
    };
  }
}

bool _bytesEqual(Uint8List first, Uint8List second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

String _errorCode(Object error) => switch (error) {
  ArgumentError() => 'invalid_argument',
  StateError() => 'invalid_state',
  TimeoutException() => 'timeout',
  _ => 'operation_failed',
};

String _safeError(Object error) {
  if (error is NoosphereWorkerException) return error.message;
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Invalid argument.';
  }
  if (error is StateError) return error.message;
  if (error is TimeoutException) return 'Operation timed out.';
  return 'Noosphere operation failed (${error.runtimeType}).';
}

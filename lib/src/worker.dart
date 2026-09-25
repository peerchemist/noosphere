import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:noosphere_server/noosphere_server.dart';

import 'client_options.dart';
import 'initialization.dart';
import 'server_identity_store.dart';
import 'server_options.dart';
import 'worker_models.dart';
import 'worker_protocol.dart';
import 'worker_runtime.dart';

/// Long-lived isolate that owns one or more Noosphere ROAST setups.
///
/// Protocol/crypto objects never cross the isolate boundary. Application-owned
/// storage, key custody, and identity providers remain on the host isolate and
/// are invoked through correlated requests.
final class NoosphereWorker {
  NoosphereWorker._({
    required this.generation,
    required this.maxOutstandingCommands,
    required this.maxMessageBytes,
    required this.hostOperationTimeout,
    required this.shutdownTimeout,
    required this._usesNativeRuntime,
    required this._messages,
    required this._errors,
    required this._exits,
  });

  static int _nextGeneration = 1;
  static bool _nativeRestartUnsafe = false;

  static Future<NoosphereWorker> start({
    Duration startupTimeout = const Duration(seconds: 30),
    Duration hostOperationTimeout = const Duration(seconds: 30),
    Duration shutdownTimeout = const Duration(seconds: 5),
    int maxOutstandingCommands = 64,
    int maxMessageBytes = defaultWorkerMaxMessageBytes,
  }) => _start(
    startupTimeout: startupTimeout,
    hostOperationTimeout: hostOperationTimeout,
    shutdownTimeout: shutdownTimeout,
    maxOutstandingCommands: maxOutstandingCommands,
    maxMessageBytes: maxMessageBytes,
    skipInitialization: false,
  );

  @visibleForTesting
  static Future<NoosphereWorker> startForTesting({
    Duration startupTimeout = const Duration(seconds: 5),
    Duration hostOperationTimeout = const Duration(seconds: 5),
    Duration shutdownTimeout = const Duration(seconds: 2),
    int maxOutstandingCommands = 64,
    int maxMessageBytes = defaultWorkerMaxMessageBytes,
  }) => _start(
    startupTimeout: startupTimeout,
    hostOperationTimeout: hostOperationTimeout,
    shutdownTimeout: shutdownTimeout,
    maxOutstandingCommands: maxOutstandingCommands,
    maxMessageBytes: maxMessageBytes,
    skipInitialization: true,
  );

  static Future<NoosphereWorker> _start({
    required Duration startupTimeout,
    required Duration hostOperationTimeout,
    required Duration shutdownTimeout,
    required int maxOutstandingCommands,
    required int maxMessageBytes,
    required bool skipInitialization,
  }) async {
    if (maxOutstandingCommands < 1) {
      throw RangeError.value(maxOutstandingCommands, 'maxOutstandingCommands');
    }
    if (maxMessageBytes < 1024) {
      throw RangeError.value(maxMessageBytes, 'maxMessageBytes');
    }
    if (!skipInitialization && _nativeRestartUnsafe) {
      throw const NoosphereWorkerException(
        'unsafe_restart',
        'A previous worker required forced or unexpected termination; '
            'restart the application before starting another native worker.',
      );
    }
    await NoosphereFlutter.prepareRootIsolate();

    final generation = _nextGeneration++;
    final messages = ReceivePort('Noosphere host $generation');
    final errors = ReceivePort('Noosphere errors $generation');
    final exits = ReceivePort('Noosphere exit $generation');
    final worker = NoosphereWorker._(
      generation: generation,
      maxOutstandingCommands: maxOutstandingCommands,
      maxMessageBytes: maxMessageBytes,
      hostOperationTimeout: hostOperationTimeout,
      shutdownTimeout: shutdownTimeout,
      usesNativeRuntime: !skipInitialization,
      messages: messages,
      errors: errors,
      exits: exits,
    );
    worker._listen();
    try {
      worker._isolate = await Isolate.spawn<Map<Object?, Object?>>(
        runNoosphereWorker,
        {
          'hostPort': messages.sendPort,
          'generation': generation,
          'maxMessageBytes': maxMessageBytes,
          'maxOutstandingHostRequests': maxOutstandingCommands,
          'skipInitialization': skipInitialization,
        },
        debugName: 'NoosphereWorker#$generation',
        errorsAreFatal: true,
        onError: errors.sendPort,
        onExit: exits.sendPort,
      );
      await worker._ready.future.timeout(startupTimeout);
      return worker;
    } catch (error, stackTrace) {
      worker._isolate?.kill(priority: Isolate.immediate);
      await worker._disposePorts();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  final int generation;
  final int maxOutstandingCommands;
  final int maxMessageBytes;
  final Duration hostOperationTimeout;
  final Duration shutdownTimeout;
  final bool _usesNativeRuntime;
  final ReceivePort _messages;
  final ReceivePort _errors;
  final ReceivePort _exits;
  final _ready = Completer<void>();
  final _exited = Completer<void>();
  final _events = StreamController<NoosphereWorkerEvent>.broadcast();
  final _pending = <int, Completer<Object?>>{};
  final _setups = <String, _HostSetup>{};
  Isolate? _isolate;
  SendPort? _workerPort;
  StreamSubscription<Object?>? _messageSubscription;
  StreamSubscription<Object?>? _errorSubscription;
  StreamSubscription<Object?>? _exitSubscription;
  int _nextCommandId = 1;
  bool _closing = false;
  bool _closed = false;
  Future<void>? _closeFuture;

  /// Broadcast public events. The worker sends a snapshot before subsequent
  /// events for every initial or replacement client session.
  Stream<NoosphereWorkerEvent> get events => _events.stream;

  bool get isClosed => _closed;

  Future<NoosphereWorkerSnapshot> startSetup({
    required String setupId,
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
    String? identityStorageId,
  }) async {
    _validateSetupId(setupId);
    if (server == null && client == null) {
      throw ArgumentError('At least one worker role is required.');
    }

    final setup = _setups.putIfAbsent(setupId, _HostSetup.new);
    final previousProviders = setup.providers;
    setup.bind(
      setupId: setupId,
      server: server,
      client: client,
      identityStorageId: identityStorageId,
    );

    try {
      final result = await _invoke(
        'startSetup',
        setupId: setupId,
        payload: {
          'server': server == null ? null : encodeServerOptions(server),
          'client': client == null ? null : encodeClientOptions(client),
        },
      );
      return result! as NoosphereWorkerSnapshot;
    } catch (_) {
      setup.providers = previousProviders;
      if (!setup.hasProviders) _setups.remove(setupId);
      rethrow;
    }
  }

  Future<void> stopSetup(
    String setupId, {
    NoosphereWorkerRoles roles = NoosphereWorkerRoles.both,
  }) async {
    await _invoke(
      'stopRoles',
      setupId: setupId,
      payload: {'roles': roles.index},
    );
    final setup = _setups[setupId];
    if (setup == null) return;
    setup.unbind(roles);
    if (!setup.hasProviders) _setups.remove(setupId);
  }

  /// Locks only the local signer; a server role in the same setup keeps
  /// coordinating other participants.
  Future<void> lockSigner(String setupId) =>
      stopSetup(setupId, roles: NoosphereWorkerRoles.signer);

  Future<NoosphereWorkerSnapshot> snapshot(String setupId) async {
    final result = await _invoke('snapshot', setupId: setupId);
    return result! as NoosphereWorkerSnapshot;
  }

  Future<void> requestDkg(String setupId, NewDkgDetails proposal) => _invoke(
    'requestDkg',
    setupId: setupId,
    payload: {'proposal': proposal.toBytes()},
  ).then((_) {});

  Future<void> acceptDkg(String setupId, WorkerDkgStatus proposal) => _invoke(
    'acceptDkg',
    setupId: setupId,
    payload: {'name': proposal.name, 'proposal': proposal.proposalBytes},
  ).then((_) {});

  Future<void> rejectDkg(String setupId, WorkerDkgStatus proposal) => _invoke(
    'rejectDkg',
    setupId: setupId,
    payload: {'name': proposal.name, 'proposal': proposal.proposalBytes},
  ).then((_) {});

  Future<void> requestSignatures(
    String setupId,
    SignaturesRequestDetails proposal,
  ) => _invoke(
    'requestSignatures',
    setupId: setupId,
    payload: {'proposal': proposal.toBytes()},
  ).then((_) {});

  Future<void> acceptSignatures(
    String setupId,
    WorkerSigningRequest proposal,
  ) => _invoke(
    'acceptSignatures',
    setupId: setupId,
    payload: {'id': proposal.id, 'proposal': proposal.proposalBytes},
  ).then((_) {});

  Future<void> rejectSignatures(
    String setupId,
    WorkerSigningRequest proposal,
  ) => _invoke(
    'rejectSignatures',
    setupId: setupId,
    payload: {'id': proposal.id, 'proposal': proposal.proposalBytes},
  ).then((_) {});

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closing = true;
    try {
      await _invoke('close', allowWhileClosing: true).timeout(shutdownTimeout);
      await _exited.future.timeout(shutdownTimeout);
    } on TimeoutException {
      if (_usesNativeRuntime) _nativeRestartUnsafe = true;
      _isolate?.kill(priority: Isolate.immediate);
      await _exited.future.timeout(shutdownTimeout, onTimeout: () {});
    } finally {
      _finishExit(
        const NoosphereWorkerException('worker_closed', 'Worker is closed.'),
        interrupted: false,
      );
      await _disposePorts();
    }
  }

  Future<Object?> _invoke(
    String operation, {
    String? setupId,
    Map<String, Object?> payload = const {},
    bool allowWhileClosing = false,
  }) {
    if (_closed || (_closing && !allowWhileClosing)) {
      throw const NoosphereWorkerException(
        'worker_closed',
        'Worker is not accepting commands.',
      );
    }
    final port = _workerPort;
    if (port == null) {
      throw const NoosphereWorkerException(
        'worker_not_ready',
        'Worker is not ready.',
      );
    }
    if (_pending.length >= maxOutstandingCommands) {
      throw const NoosphereWorkerException(
        'too_many_commands',
        'Too many worker commands are outstanding.',
      );
    }
    final id = _nextCommandId++;
    final message = <String, Object?>{
      'version': workerProtocolVersion,
      'generation': generation,
      'type': 'command',
      'commandId': id,
      'operation': operation,
      'setupId': setupId,
      'payload': payload,
    };
    if (approximateMessageBytes(message) > maxMessageBytes) {
      throw const NoosphereWorkerException(
        'message_too_large',
        'Command exceeds the configured message limit.',
      );
    }
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send(message);
    return completer.future;
  }

  void _listen() {
    _messageSubscription = _messages.listen(_onMessage);
    _errorSubscription = _errors.listen((Object? error) {
      _finishExit(
        const NoosphereWorkerException(
          'worker_crashed',
          'Worker isolate terminated unexpectedly.',
        ),
        interrupted: true,
      );
    });
    _exitSubscription = _exits.listen((_) {
      if (!_exited.isCompleted) _exited.complete();
      if (!_closed && !_closing) {
        _finishExit(
          const NoosphereWorkerException(
            'worker_exited',
            'Worker exited unexpectedly.',
          ),
          interrupted: true,
        );
      }
    });
  }

  void _onMessage(Object? raw) {
    if (raw is! Map) return;
    final message = raw.cast<Object?, Object?>();
    if (message['generation'] != generation ||
        message['version'] != workerProtocolVersion) {
      return;
    }
    switch (message['type']) {
      case 'ready':
        if (_ready.isCompleted) return;
        _workerPort = message['port']! as SendPort;
        _ready.complete();
      case 'startupError':
        final error = NoosphereWorkerException(
          message['code'] as String? ?? 'startup_failed',
          message['message'] as String? ?? 'Worker startup failed.',
        );
        if (!_ready.isCompleted) _ready.completeError(error);
      case 'reply':
        _completeCommand(message);
      case 'event':
        _emitEvent(message);
      case 'hostRequest':
        unawaited(_handleHostRequest(message));
    }
  }

  void _completeCommand(Map<Object?, Object?> message) {
    final id = message['commandId'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (message['ok'] == true) {
      completer.complete(message['result']);
    } else {
      completer.completeError(
        NoosphereWorkerException(
          message['code'] as String? ?? 'command_failed',
          message['message'] as String? ?? 'Worker command failed.',
        ),
      );
    }
  }

  Future<void> _handleHostRequest(Map<Object?, Object?> message) async {
    final port = _workerPort;
    final requestId = message['hostRequestId'];
    if (port == null || requestId is! int || _closed) return;
    Object? result;
    Object? failure;
    try {
      if (approximateMessageBytes(message) > maxMessageBytes) {
        throw StateError('Host request exceeds configured message limit.');
      }
      final setupId = message['setupId']! as String;
      final setup = _setups[setupId];
      if (setup == null) throw StateError('Unknown setup.');
      result = await setup
          .dispatch(
            message['operation']! as String,
            message['payload']! as Map<Object?, Object?>,
          )
          .timeout(hostOperationTimeout);
    } catch (error) {
      failure = error;
    }
    var reply = <String, Object?>{
      'version': workerProtocolVersion,
      'generation': generation,
      'type': 'hostReply',
      'hostRequestId': requestId,
      'ok': failure == null,
      if (failure == null) 'result': result,
      if (failure != null) 'code': _hostErrorCode(failure),
      if (failure != null) 'message': _safeHostFailure(failure),
    };
    if (approximateMessageBytes(reply) > maxMessageBytes) {
      reply = {
        'version': workerProtocolVersion,
        'generation': generation,
        'type': 'hostReply',
        'hostRequestId': requestId,
        'ok': false,
        'code': 'message_too_large',
        'message': 'Host reply exceeds the configured message limit.',
      };
    }
    port.send(reply);
  }

  void _emitEvent(Map<Object?, Object?> message) {
    if (_events.isClosed ||
        approximateMessageBytes(message) > maxMessageBytes) {
      return;
    }
    final event = message['event'];
    if (event is NoosphereWorkerEvent && event.generation == generation) {
      _events.add(event);
    }
  }

  void _finishExit(Object error, {required bool interrupted}) {
    if (_closed) return;
    if (interrupted && _usesNativeRuntime) _nativeRestartUnsafe = true;
    _closed = true;
    _workerPort = null;
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final completer in _pending.values) {
      completer.completeError(error);
    }
    _pending.clear();
    if (interrupted && !_events.isClosed) {
      for (final setupId in _setups.keys) {
        _events.add(
          WorkerFailureEvent(
            setupId,
            generation,
            operation: 'worker',
            message: 'Worker exited; in-flight mutations were not replayed.',
            interrupted: true,
          ),
        );
      }
    }
    _setups.clear();
    if (!_events.isClosed) unawaited(_events.close());
  }

  Future<void> _disposePorts() async {
    await _messageSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _exitSubscription?.cancel();
    _messages.close();
    _errors.close();
    _exits.close();
  }
}

typedef _HostProviders = ({
  ServerIdentityStore? identityStore,
  String? identityStorageId,
  ClientStorageInterface? storage,
  GetPrivateKey? getPrivateKey,
  String? participant,
});

final class _HostSetup {
  ServerIdentityStore? identityStore;
  String? identityStorageId;
  ClientStorageInterface? storage;
  GetPrivateKey? getPrivateKey;
  String? participant;
  final _storageSerial = SerialExecutor();

  bool get hasProviders =>
      identityStore != null || storage != null || getPrivateKey != null;

  _HostProviders get providers => (
    identityStore: identityStore,
    identityStorageId: identityStorageId,
    storage: storage,
    getPrivateKey: getPrivateKey,
    participant: participant,
  );

  set providers(_HostProviders value) {
    identityStore = value.identityStore;
    identityStorageId = value.identityStorageId;
    storage = value.storage;
    getPrivateKey = value.getPrivateKey;
    participant = value.participant;
  }

  void bind({
    required String setupId,
    required EmbeddedServerOptions? server,
    required ClientNodeOptions? client,
    required String? identityStorageId,
  }) {
    if (server != null) {
      this.identityStorageId = identityStorageId ?? setupId;
      identityStore = server.identityStore;
    }
    if (client != null) {
      storage = client.storage;
      getPrivateKey = client.getPrivateKey;
      participant = client.clientConfig.id.toString();
    }
  }

  void unbind(NoosphereWorkerRoles roles) {
    if (roles != NoosphereWorkerRoles.server) {
      storage = null;
      getPrivateKey = null;
      participant = null;
    }
    if (roles != NoosphereWorkerRoles.signer) {
      identityStore = null;
      identityStorageId = null;
    }
  }

  Future<Object?> dispatch(
    String operation,
    Map<Object?, Object?> payload,
  ) async {
    switch (operation) {
      case 'identity.read':
        final store = identityStore;
        final id = identityStorageId;
        if (store == null || id == null) throw StateError('No identity store.');
        return _IdentityRegistry.loadOrCreate(id, store);
      case 'identity.write':
        final store = identityStore;
        if (store == null) throw StateError('No identity store.');
        await store.write(asBytes(payload['secret']));
        return null;
      case 'getPrivateKey':
        final provider = getPrivateKey;
        if (provider == null) throw StateError('Signer is locked.');
        if (payload['participant'] != participant) {
          throw StateError('Key request participant does not match setup.');
        }
        final key = await provider(
          KeyPurpose.values[payload['purpose']! as int],
        );
        return key.data;
      default:
        return _serializeStorage(() => _dispatchStorage(operation, payload));
    }
  }

  Future<T> _serializeStorage<T>(Future<T> Function() operation) =>
      _storageSerial.run(operation);

  Future<Object?> _dispatchStorage(
    String operation,
    Map<Object?, Object?> payload,
  ) async {
    final store = storage;
    if (store == null) throw StateError('Signer storage is unavailable.');
    final id = payload['id'] == null
        ? null
        : SignaturesRequestId.fromBytes(asBytes(payload['id']));
    switch (operation) {
      case 'storage.addKey':
        await store.addOrReplaceFrostKey(
          FrostKeyWithDetails.fromBytes(asBytes(payload['key'])),
        );
      case 'storage.addNonces':
        await store.addSignaturesNonces(
          id!,
          decodeSignaturesNonces(payload['nonces']! as Map<Object?, Object?>),
          payload['capacity']! as int,
        );
      case 'storage.prepareSignatures':
        await store.prepareSignaturesOperation(
          PreparedSignaturesOperation.fromBytes(asBytes(payload['operation'])),
          payload['capacity']! as int,
        );
      case 'storage.completeSignatures':
        await store.completeSignaturesOperation(id!);
      case 'storage.addRejection':
        await store.addRejectedSigsRequest(
          id!,
          FinalExpirable(
            Expiry.fromTime(
              DateTime.fromMicrosecondsSinceEpoch(
                payload['expiryMicros']! as int,
              ),
            ),
          ),
        );
      case 'storage.removeRejection':
        await store.removeRejectionOfSigsRequest(id!);
      case 'storage.removeSignatures':
        await store.removeSigsRequest(id!);
      case 'storage.loadKeys':
        return [for (final key in await store.loadKeys()) key.toBytes()];
      case 'storage.loadNonces':
        return [
          for (final entry in (await store.loadSigNonces()).entries)
            {
              'id': entry.key.toBytes(),
              'nonces': encodeSignaturesNonces(entry.value),
            },
        ];
      case 'storage.loadPreparedSignatures':
        return [
          for (final operation
              in (await store.loadPreparedSignaturesOperations()).values)
            operation.toBytes(),
        ];
      case 'storage.loadRejections':
        return [
          for (final entry in (await store.loadRejectedSigsRequests()).entries)
            {
              'id': entry.key.toBytes(),
              'expiryMicros': entry.value.expiry.time.microsecondsSinceEpoch,
            },
        ];
      default:
        throw ArgumentError.value(
          operation,
          'operation',
          'unknown host request',
        );
    }
    return null;
  }
}

abstract final class _IdentityRegistry {
  static final _loads = <String, Future<Uint8List>>{};

  static Future<Uint8List> loadOrCreate(
    String storageId,
    ServerIdentityStore store,
  ) => _loads.putIfAbsent(storageId, () => _loadOrCreate(store));

  static Future<Uint8List> _loadOrCreate(ServerIdentityStore store) async {
    final stored = await store.read();
    if (stored != null) {
      if (stored.length != 32) {
        throw FormatException(
          'Stored Iroh server identity must contain exactly 32 bytes.',
        );
      }
      return Uint8List.fromList(stored);
    }
    final random = Random.secure();
    final generated = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await store.write(generated);
    return generated;
  }
}

void _validateSetupId(String value) {
  if (value.isEmpty || value.length > 128) {
    throw ArgumentError.value(
      value,
      'setupId',
      'must contain 1-128 characters',
    );
  }
}

String _hostErrorCode(Object error) => switch (error) {
  TimeoutException() => 'host_timeout',
  StateError() => 'host_state',
  ArgumentError() => 'host_argument',
  _ => 'host_failure',
};

String _safeHostFailure(Object error) => switch (error) {
  TimeoutException() =>
    'Host provider timed out; durable outcome may be unknown.',
  _ =>
    'Host provider failed (${error.runtimeType}); durable outcome may be unknown.',
};

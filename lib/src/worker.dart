import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart' show EndpointAddr;
import 'package:meta/meta.dart';
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_server/noosphere_server.dart'
    show RoomPersistence, ServerPersistence, ServerStateSnapshot;

import 'client_options.dart';
import 'initialization.dart';
import 'server_identity_store.dart';
import 'server_options.dart';
import 'worker_models.dart';
import 'worker_protocol.dart';
import 'worker_runtime.dart';

part 'worker/worker_host_setup.dart';

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
    required this._testing,
    required this._testHostOperation,
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
    testing: false,
  );

  @visibleForTesting
  static Future<NoosphereWorker> startNativeForTesting({
    Duration startupTimeout = const Duration(seconds: 30),
    Duration shutdownTimeout = const Duration(seconds: 2),
  }) => _start(
    startupTimeout: startupTimeout,
    hostOperationTimeout: const Duration(seconds: 5),
    shutdownTimeout: shutdownTimeout,
    maxOutstandingCommands: 64,
    maxMessageBytes: defaultWorkerMaxMessageBytes,
    skipInitialization: false,
    testing: true,
  );

  @visibleForTesting
  static Future<NoosphereWorker> startForTesting({
    Duration startupTimeout = const Duration(seconds: 5),
    Duration hostOperationTimeout = const Duration(seconds: 5),
    Duration shutdownTimeout = const Duration(seconds: 2),
    int maxOutstandingCommands = 64,
    int maxMessageBytes = defaultWorkerMaxMessageBytes,
    Map<String, ServerIdentityStore?> identityStores = const {},
    Map<String, RoomPersistence> roomPersistences = const {},
    Map<String, ClientStorageInterface> clientStorages = const {},
    Future<Object?> Function()? hostOperation,
    bool failStartup = false,
  }) async {
    final worker = await _start(
      startupTimeout: startupTimeout,
      hostOperationTimeout: hostOperationTimeout,
      shutdownTimeout: shutdownTimeout,
      maxOutstandingCommands: maxOutstandingCommands,
      maxMessageBytes: maxMessageBytes,
      skipInitialization: true,
      testing: true,
      testHostOperation: hostOperation,
      failStartup: failStartup,
    );
    for (final entry in identityStores.entries) {
      final setup = worker._setups.putIfAbsent(entry.key, _HostSetup.new);
      final store = entry.value;
      if (store != null) {
        setup.identityStore = store;
        await setup.loadOrCreateIdentity();
      }
    }
    for (final entry in roomPersistences.entries) {
      worker._setups.putIfAbsent(entry.key, _HostSetup.new).roomPersistence =
          entry.value;
    }
    for (final entry in clientStorages.entries) {
      worker._setups.putIfAbsent(entry.key, _HostSetup.new).storage =
          entry.value;
    }
    return worker;
  }

  static Future<NoosphereWorker> _start({
    required Duration startupTimeout,
    required Duration hostOperationTimeout,
    required Duration shutdownTimeout,
    required int maxOutstandingCommands,
    required int maxMessageBytes,
    required bool skipInitialization,
    required bool testing,
    Future<Object?> Function()? testHostOperation,
    bool failStartup = false,
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
    if (!skipInitialization && _nextGeneration > 0x7fffffff) {
      throw StateError('Worker generation space is exhausted.');
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
      testing: testing,
      testHostOperation: testHostOperation,
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
          'testing': testing,
          'failStartup': failStartup,
        },
        debugName: 'NoosphereWorker#$generation',
        errorsAreFatal: true,
        onError: errors.sendPort,
        onExit: exits.sendPort,
      );
      await worker._ready.future.timeout(startupTimeout);
      return worker;
    } catch (error, stackTrace) {
      // Native initialization or startup may already have created process-wide
      // tasks. Killing the isolate cannot establish that they were released.
      if (!skipInitialization && worker._isolate != null) {
        _nativeRestartUnsafe = true;
      }
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
  final bool _testing;
  final Future<Object?> Function()? _testHostOperation;
  final ReceivePort _messages;
  final ReceivePort _errors;
  final ReceivePort _exits;
  final _ready = Completer<void>();
  final _exited = Completer<void>();
  final _events = StreamController<NoosphereWorkerEvent>.broadcast();
  final _pending = <int, Completer<Object?>>{};
  final _setups = <String, _HostSetup>{};
  final _lifecycleSetups = <String>{};
  Isolate? _isolate;
  SendPort? _workerPort;
  StreamSubscription<Object?>? _messageSubscription;
  StreamSubscription<Object?>? _errorSubscription;
  StreamSubscription<Object?>? _exitSubscription;
  int _nextCommandId = 1;
  bool _closing = false;
  bool _closed = false;
  Future<void>? _closeFuture;
  Future<void>? _disposeFuture;

  /// Broadcast public events. The worker sends a snapshot before subsequent
  /// events for every initial or replacement client session.
  Stream<NoosphereWorkerEvent> get events => _events.stream;

  bool get isClosed => _closed;

  /// Interrupts the test isolate to exercise pending-command cleanup.
  @visibleForTesting
  void debugKillForTesting() {
    if (!_testing) throw StateError('Only testing workers may be killed.');
    _isolate?.kill(priority: Isolate.immediate);
  }

  /// Starts a command that intentionally waits until the test isolate exits.
  @visibleForTesting
  Future<void> debugPendingCommandForTesting() {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    return _invoke('testPending').then((_) {});
  }

  /// Invokes the injected host provider through the real correlated bridge.
  @visibleForTesting
  Future<Object?> debugHostRequestForTesting() {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    return _invoke('testHost');
  }

  /// Exercises the room adapter over the actual worker/host boundary.
  @visibleForTesting
  Future<Map<String, Uint8List>> debugLoadRoomsForTesting(
    String setupId,
  ) async {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    final records = await _invoke('testRoomLoad', setupId: setupId);
    return {
      for (final entry in (records! as Map).entries)
        entry.key as String: asBytes(entry.value),
    };
  }

  @visibleForTesting
  Future<void> debugWriteRoomForTesting(
    String setupId,
    String roomId,
    Uint8List state,
  ) async {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    await _invoke(
      'testRoomWrite',
      setupId: setupId,
      payload: {'roomId': roomId, 'state': Uint8List.fromList(state)},
    );
  }

  /// Exercises durable client storage over the worker boundary in unit tests.
  @visibleForTesting
  Future<Object?> debugClientStorageForTesting(
    String setupId, {
    Uint8List? rejectRequestId,
  }) {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    return _invoke(
      'testClientStorage',
      setupId: setupId,
      payload: {'rejectRequestId': rejectRequestId},
    );
  }

  /// Starts roles. Concurrent lifecycle calls for this setup fail with
  /// `setup_busy`; await completion before starting, stopping or switching it.
  Future<NoosphereWorkerSnapshot> startSetup({
    required String setupId,
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  }) => _withSetupLifecycle(setupId, () async {
    _validateSetupId(setupId);
    if (server == null && client == null) {
      throw ArgumentError('At least one worker role is required.');
    }

    final setup = _setups.putIfAbsent(setupId, _HostSetup.new);
    // Check live roles before replacing host providers. The isolate rejecting
    // a duplicate start is too late: a live role may request storage meanwhile.
    if (setup.hasProviders) {
      final current = await snapshot(setupId);
      if ((server != null && current.serverRunning) ||
          (client != null && current.signerRunning)) {
        throw StateError('Requested role is already running.');
      }
    }
    final previousProviders = setup.providers;
    setup.bind(server: server, client: client);

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
  });

  Future<void> stopSetup(
    String setupId, {
    NoosphereWorkerRoles roles = NoosphereWorkerRoles.both,
  }) => _withSetupLifecycle(setupId, () async {
    await _invoke(
      'stopRoles',
      setupId: setupId,
      payload: {'roles': roles.index},
    );
    final setup = _setups[setupId];
    if (setup == null) return;
    setup.unbind(roles);
    if (!setup.hasProviders) _setups.remove(setupId);
  });

  /// Locks only the local signer; a server role in the same setup keeps
  /// coordinating other participants.
  Future<void> lockSigner(String setupId) =>
      stopSetup(setupId, roles: NoosphereWorkerRoles.signer);

  /// Updates the reconnect hint without changing the pinned coordinator ID.
  Future<void> updateSignerAddress(String setupId, EndpointAddr address) =>
      _invoke(
        'updateSignerAddress',
        setupId: setupId,
        payload: {'address': encodeEndpointAddress(address)},
      ).then((_) {});

  /// Switches this setup's signer to a coordinator already approved by the app.
  ///
  /// Serializes with lifecycle and signing operations for this setup, stops the
  /// old session, checks local pending signing state, awaits durable [persist],
  /// then connects with the new pin. The destination must serve the same group.
  /// Participant identity, FROST keys, client storage and any embedded server
  /// role are retained.
  ///
  /// This sequence is not atomic. Pending signing state or a persistence failure
  /// leaves the signer stopped. A timed-out [persist] may still commit: wait for
  /// or reconcile that write before restarting from the app's stored selection.
  /// A connection failure after persistence retains the new configuration for
  /// an explicit retry. There is no automatic rollback or mutation replay.
  /// [persist] must not re-enter lifecycle or signing commands for this setup.
  ///
  /// Success confirms only this signer's connection, not other participants'
  /// approval or availability. This does not migrate rooms, invitations, server
  /// state, group membership or funds.
  Future<NoosphereWorkerSnapshot> switchCoordinator(
    String setupId, {
    required EndpointAddr newCoordinator,
    required Future<void> Function(EndpointAddr) persist,
  }) => _withSetupLifecycle(setupId, () async {
    final setup = _setups[setupId];
    if (setup?.storage == null || setup!.persistCoordinator != null) {
      throw StateError('Signer is unavailable or a switch is in progress.');
    }
    setup.persistCoordinator = () => persist(newCoordinator);
    try {
      return (await _invoke(
            'switchCoordinator',
            setupId: setupId,
            payload: {'address': encodeEndpointAddress(newCoordinator)},
          ))!
          as NoosphereWorkerSnapshot;
    } finally {
      setup.persistCoordinator = null;
    }
  });

  Future<T> _withSetupLifecycle<T>(
    String setupId,
    Future<T> Function() operation,
  ) async {
    if (!_lifecycleSetups.add(setupId)) {
      throw const NoosphereWorkerException(
        'setup_busy',
        'A lifecycle operation is already running for this setup.',
      );
    }
    try {
      return await operation();
    } finally {
      _lifecycleSetups.remove(setupId);
    }
  }

  Future<NoosphereWorkerSnapshot> snapshot(String setupId) async {
    final result = await _invoke('snapshot', setupId: setupId);
    return result! as NoosphereWorkerSnapshot;
  }

  /// Exports an embedded server setup's raw 32-byte Iroh secret key.
  ///
  /// The result is a secret key, not the public endpoint ID. Encrypt the
  /// backup and never log it. A fresh defensive copy is returned, but Dart
  /// managed memory cannot guarantee reliable zeroization. Restore it with
  /// [restoreStoredIrohServerIdentity] before starting the replacement setup.
  ///
  /// The secret remains on the host isolate. Throws [StateError] if [setupId]
  /// is unknown or does not currently have an embedded server role.
  Future<Uint8List> exportIrohServerIdentity(String setupId) async {
    final setup = _setups[setupId];
    if (setup == null) {
      throw StateError('Cannot export identity for unknown setup "$setupId".');
    }
    final store = setup.identityStore;
    if (store == null) {
      throw StateError(
        'Cannot export an Iroh server identity from setup "$setupId" '
        'because it has no embedded server role.',
      );
    }
    return exportStoredIrohServerIdentity(store);
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
    if (_closed) {
      await _disposePorts();
      return;
    }
    _closing = true;
    var graceful = false;
    try {
      await _invoke('close', allowWhileClosing: true).timeout(shutdownTimeout);
      await _exited.future.timeout(shutdownTimeout);
      graceful = true;
    } catch (_) {
      // A failed close reply is as uncertain as a timeout: the worker may
      // still own sockets or native tasks.
    } finally {
      if (!graceful) {
        if (_usesNativeRuntime) _nativeRestartUnsafe = true;
        _isolate?.kill(priority: Isolate.immediate);
        await _exited.future.timeout(shutdownTimeout, onTimeout: () {});
      }
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
      if (_testing && message['operation'] == 'testHost') {
        final provider = _testHostOperation;
        if (provider == null) throw StateError('No test host provider.');
        result = await provider().timeout(hostOperationTimeout);
      } else {
        final setup = _setups[setupId];
        if (setup == null) throw StateError('Unknown setup.');
        result = await setup
            .dispatch(
              message['operation']! as String,
              message['payload']! as Map<Object?, Object?>,
            )
            .timeout(hostOperationTimeout);
      }
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
    unawaited(_disposePorts());
  }

  Future<void> _disposePorts() => _disposeFuture ??= _cancelPorts();

  Future<void> _cancelPorts() async {
    await _messageSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _exitSubscription?.cancel();
    _messages.close();
    _errors.close();
    _exits.close();
  }
}

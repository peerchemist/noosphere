import 'dart:async';
import 'dart:isolate';

import '../initialization.dart';
import '../worker_models.dart';
import '../worker_protocol.dart';
import '../worker_runtime.dart';
import 'provider_registry.dart';

final class WorkerCommandChannel {
  WorkerCommandChannel._({
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

  static Future<WorkerCommandChannel> open({
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
    final worker = WorkerCommandChannel._(
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
  late final registry = HostProviderRegistry(
    (operation, {setupId, payload = const {}}) =>
        invoke(operation, setupId: setupId, payload: payload),
  );
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

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    if (_closed) {
      await _disposePorts();
      return;
    }
    _closing = true;
    var graceful = false;
    try {
      await invoke(
        WorkerOperation.close,
        allowWhileClosing: true,
      ).timeout(shutdownTimeout);
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

  void killForTesting() {
    if (!_testing) throw StateError('Only testing workers may be killed.');
    _isolate?.kill(priority: Isolate.immediate);
  }

  Future<Object?> invoke(
    WorkerOperation operation, {
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
    final message = WorkerCommand(
      generation,
      id,
      operation,
      setupId: setupId,
      payload: payload,
    );
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
    if (raw is! WorkerMessage || raw.generation != generation) return;
    switch (raw) {
      case WorkerReady():
        if (_ready.isCompleted) return;
        _workerPort = raw.port;
        _ready.complete();
      case WorkerStartupFailure():
        if (!_ready.isCompleted) _ready.completeError(raw.failure);
      case WorkerReply():
        final completer = _pending.remove(raw.id);
        if (completer == null) return;
        if (raw.failure case final failure?) {
          completer.completeError(failure);
        } else {
          completer.complete(raw.result);
        }
      case WorkerEventMessage():
        if (!_events.isClosed &&
            raw.event.generation == generation &&
            approximateMessageBytes(raw) <= maxMessageBytes) {
          _events.add(raw.event);
        }
      case ProviderRequest():
        unawaited(_handleHostRequest(raw));
      default:
        break;
    }
  }

  Future<void> _handleHostRequest(ProviderRequest message) async {
    final port = _workerPort;
    final requestId = message.id;
    if (port == null || _closed) return;
    Object? result;
    Object? failure;
    try {
      if (approximateMessageBytes(message) > maxMessageBytes) {
        throw StateError('Host request exceeds configured message limit.');
      }
      final setupId = message.setupId;
      if (_testing && message.operation == ProviderOperation.testHost) {
        final provider = _testHostOperation;
        if (provider == null) throw StateError('No test host provider.');
        result = await provider().timeout(hostOperationTimeout);
      } else {
        result = await registry
            .dispatch(setupId, message.operation, message.fields.values)
            .timeout(hostOperationTimeout);
      }
    } catch (error) {
      failure = error;
    }
    var reply = failure == null
        ? ProviderReply.success(generation, requestId, result)
        : ProviderReply.failure(
            generation,
            requestId,
            NoosphereWorkerException(
              _hostErrorCode(failure),
              _safeHostFailure(failure),
            ),
          );
    if (approximateMessageBytes(reply) > maxMessageBytes) {
      reply = ProviderReply.failure(
        generation,
        requestId,
        const NoosphereWorkerException(
          'message_too_large',
          'Host reply exceeds the configured message limit.',
        ),
      );
    }
    port.send(reply);
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
      for (final setupId in registry.setupIds) {
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
    registry.clear();
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

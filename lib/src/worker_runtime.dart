import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:iroh_flutter/iroh_flutter.dart' show EndpointAddr;
import 'package:meta/meta.dart';
import 'package:noosphere_client/iroh_transport.dart'
    show IrohProtocolException;
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_server/noosphere_server.dart'
    show RoomPersistence, ServerPersistence, ServerStateSnapshot;

import 'client_options.dart';
import 'initialization.dart';
import 'iroh_node.dart';
import 'server_identity_store.dart';
import 'worker_models.dart';
import 'worker_protocol.dart';

part 'worker/worker_setup_runtime.dart';
part 'worker/worker_host_bridge.dart';
part 'worker/worker_remote_storage.dart';

@pragma('vm:entry-point')
@RecordUse()
Future<void> runNoosphereWorker(Map<Object?, Object?> bootstrap) async {
  final hostPort = bootstrap['hostPort']! as SendPort;
  final generation = bootstrap['generation']! as int;
  final maxMessageBytes = bootstrap['maxMessageBytes']! as int;
  final maxOutstandingHostRequests =
      bootstrap['maxOutstandingHostRequests']! as int;
  final skipInitialization = bootstrap['skipInitialization'] == true;
  final testing = bootstrap['testing'] == true;
  final receivePort = ReceivePort('Noosphere worker $generation');

  try {
    if (bootstrap['failStartup'] == true && testing) {
      throw StateError('Injected private startup detail.');
    }
    if (!skipInitialization) {
      await NoosphereFlutter.initializeNative();
    }
    final runtime = _WorkerRuntime(
      generation: generation,
      hostPort: hostPort,
      receivePort: receivePort,
      maxMessageBytes: maxMessageBytes,
      maxOutstandingHostRequests: maxOutstandingHostRequests,
      testing: testing,
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
    required this.testing,
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
  final bool testing;
  final _setups = <String, _SetupRuntime>{};
  final _activeCommands = <Future<void>>{};
  final _done = Completer<void>();
  final _HostBridge _host;
  final _testRoomStores = <String, _RemoteRoomPersistence>{};
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
      final command = _handleCommand(message);
      if (message['type'] == 'command' && message['operation'] != 'close') {
        _activeCommands.add(command);
        command.whenComplete(() => _activeCommands.remove(command));
      }
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
        case 'rotateCoordinator':
          result = await _setup(setupId!).rotateCoordinator(
            decodeEndpointAddress(payload['address']! as Map<Object?, Object?>),
          );
        case 'updateSignerAddress':
          result = await _setup(setupId!).updateSignerAddress(
            decodeEndpointAddress(payload['address']! as Map<Object?, Object?>),
          );
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
        case 'testPending':
          if (!testing) throw StateError('Test command is unavailable.');
          await Completer<void>().future;
          result = null;
        case 'testRoomLoad':
          if (!testing) throw StateError('Test command is unavailable.');
          result = await _testRoomStores
              .putIfAbsent(
                setupId!,
                () => _RemoteRoomPersistence(_host, setupId),
              )
              .loadAll();
        case 'testRoomWrite':
          if (!testing) throw StateError('Test command is unavailable.');
          await _testRoomStores
              .putIfAbsent(
                setupId!,
                () => _RemoteRoomPersistence(_host, setupId),
              )
              .write(payload['roomId']! as String, asBytes(payload['state']));
          result = null;
        case 'testHost':
          if (!testing) throw StateError('Test command is unavailable.');
          result = await _host.request('', 'testHost', const {});
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
    // Commands already accepted may still be waiting on the host. Let them
    // finish before closing the nodes they use. The host enforces the bounded
    // fallback when a provider never replies.
    await Future.wait(_activeCommands.toList());
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

bool _bytesEqual(Uint8List first, Uint8List second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

bool _sameAddress(EndpointAddr? first, EndpointAddr second) {
  if (first == null || first.id != second.id) return false;
  return _sameList(
        [for (final url in first.relayUrls) url.value],
        [for (final url in second.relayUrls) url.value],
      ) &&
      _sameList(first.ipAddrs, second.ipAddrs);
}

bool _sameList<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

String _errorCode(Object error) => switch (error) {
  NoosphereWorkerException(:final code) => code,
  IrohProtocolException() => 'iroh_protocol_error',
  ArgumentError() => 'invalid_argument',
  StateError() => 'invalid_state',
  TimeoutException() => 'timeout',
  _ => 'operation_failed',
};

String _safeError(Object error) {
  if (error is NoosphereWorkerException) return error.message;
  if (error is IrohProtocolException) {
    return 'Iroh protocol error: ${error.message}';
  }
  if (error is ArgumentError) return 'Invalid argument.';
  if (error is StateError) return 'Operation could not be completed.';
  if (error is TimeoutException) return 'Operation timed out.';
  return 'Noosphere operation failed (${error.runtimeType}).';
}

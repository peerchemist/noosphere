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
import 'server_options.dart';
import 'worker/dto_mapper.dart';
import 'worker/node_factory.dart';
import 'worker/session_delivery.dart';
import 'worker_models.dart';
import 'worker_protocol.dart';

part 'worker/worker_host_bridge.dart';
part 'worker/worker_remote_storage.dart';
part 'worker/worker_setup_runtime.dart';

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
    hostPort.send(WorkerReady(generation, receivePort.sendPort));
    await runtime.run();
  } catch (error) {
    hostPort.send(
      WorkerStartupFailure(
        generation,
        NoosphereWorkerException(_errorCode(error), _safeError(error)),
      ),
    );
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
  final _setups = <String, WorkerSetupRuntime>{};
  final _activeCommands = <Future<void>>{};
  final _done = Completer<void>();
  final _HostBridge _host;
  final _testRoomStores = <String, _RemoteRoomPersistence>{};
  bool _closing = false;

  Future<void> run() async {
    receivePort.listen((raw) {
      if (raw is! WorkerMessage || raw.generation != generation) return;
      if (raw is ProviderReply) {
        _host.complete(raw);
        return;
      }
      if (raw is! WorkerCommand) return;
      final message = raw;
      final command = _handleCommand(message);
      if (message.operation != WorkerOperation.close) {
        _activeCommands.add(command);
        command.whenComplete(() => _activeCommands.remove(command));
      }
    });
    await _done.future;
  }

  Future<void> _handleCommand(WorkerCommand message) async {
    final id = message.id;
    if (approximateMessageBytes(message) > maxMessageBytes) {
      _replyError(id, 'message_too_large', 'Command exceeds worker limit.');
      return;
    }
    if (_closing && message.operation != WorkerOperation.close) {
      _replyError(id, 'worker_closing', 'Worker is closing.');
      return;
    }

    try {
      final operation = message.operation;
      final setupId = message.setupId;
      final payload = message.fields;
      final Object? result;
      switch (operation) {
        case WorkerOperation.startSetup:
          result = await _startSetup(setupId!, payload.values);
        case WorkerOperation.stopRoles:
          result = await _setup(setupId!)
              .stopRoles(NoosphereWorkerRoles.values[payload.integer('roles')]);
          if (!_setup(setupId).hasRoles) _setups.remove(setupId);
        case WorkerOperation.snapshot:
          result = _setup(setupId!).snapshot();
        case WorkerOperation.switchCoordinator:
          result = await _setup(setupId!)
              .switchCoordinator(decodeEndpointAddress(payload.map('address')));
        case WorkerOperation.updateSignerAddress:
          result = await _setup(
            setupId!,
          ).updateSignerAddress(decodeEndpointAddress(payload.map('address')));
        case WorkerOperation.requestDkg:
          result = await _setup(setupId!)
              .requestDkg(NewDkgDetails.fromBytes(payload.bytes('proposal')));
        case WorkerOperation.acceptDkg:
          result = await _setup(setupId!).respondDkg(
            name: payload.string('name'),
            proposalBytes: payload.bytes('proposal'),
            accept: true,
          );
        case WorkerOperation.rejectDkg:
          result = await _setup(setupId!).respondDkg(
            name: payload.string('name'),
            proposalBytes: payload.bytes('proposal'),
            accept: false,
          );
        case WorkerOperation.requestSignatures:
          result = await _setup(setupId!).requestSignatures(
            SignaturesRequestDetails.fromBytes(payload.bytes('proposal')),
          );
        case WorkerOperation.acceptSignatures:
          result = await _setup(setupId!).respondSignatures(
            id: SignaturesRequestId.fromBytes(payload.bytes('id')),
            proposalBytes: payload.bytes('proposal'),
            accept: true,
          );
        case WorkerOperation.rejectSignatures:
          result = await _setup(setupId!).respondSignatures(
            id: SignaturesRequestId.fromBytes(payload.bytes('id')),
            proposalBytes: payload.bytes('proposal'),
            accept: false,
          );
        case WorkerOperation.close:
          result = await _close();
        case WorkerOperation.testStopServing:
          if (!testing) throw StateError('Test command is unavailable.');
          await _setup(setupId!)._serverNode!.stopServingForTesting();
          result = null;
        case WorkerOperation.testPending:
          if (!testing) throw StateError('Test command is unavailable.');
          await Completer<void>().future;
          result = null;
        case WorkerOperation.testRoomLoad:
          if (!testing) throw StateError('Test command is unavailable.');
          result = await _testRoomStores
              .putIfAbsent(
                setupId!,
                () => _RemoteRoomPersistence(_host, setupId),
              )
              .loadAll();
        case WorkerOperation.testRoomWrite:
          if (!testing) throw StateError('Test command is unavailable.');
          await _testRoomStores
              .putIfAbsent(
                setupId!,
                () => _RemoteRoomPersistence(_host, setupId),
              )
              .write(payload.string('roomId'), payload.bytes('state'));
          result = null;
        case WorkerOperation.testHost:
          if (!testing) throw StateError('Test command is unavailable.');
          result = await _host.request(
            '',
            ProviderOperation.testHost,
            const {},
          );
        case WorkerOperation.testClientStorage:
          if (!testing) throw StateError('Test command is unavailable.');
          final storage = _RemoteClientStorage(_host, setupId!);
          final requestId = payload.optional<Uint8List>('rejectRequestId');
          if (requestId != null) {
            await storage.addRejectedSigsRequest(
              SignaturesRequestId.fromBytes(asBytes(requestId)),
              FinalExpirable(Expiry(const Duration(hours: 1))),
            );
            result = null;
          } else {
            result = [
              for (final id
                  in (await storage.loadState()).rejectedRequests.keys)
                id.toBytes(),
            ];
          }
      }
      _reply(id, result, startedSetup: operation == WorkerOperation.startSetup);
      if (operation == WorkerOperation.close) {
        receivePort.close();
        if (!_done.isCompleted) _done.complete();
      }
    } catch (error) {
      _replyError(id, _errorCode(error), _safeError(error));
    }
  }

  WorkerSetupRuntime _setup(String id) {
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
      () => WorkerSetupRuntime(
        setupId: setupId,
        generation: generation,
        host: _host,
        emit: _emit,
      ),
    );
    try {
      final fields = MessageFields(payload.cast<String, Object?>());
      final server = fields.optional<Map<String, Object?>>('server');
      final client = fields.optional<Map<String, Object?>>('client');
      await setup.start(
        server: server == null
            ? null
            : decodeServerOptions(
                server,
                _RemoteIdentityStore(_host, setupId),
                _RemoteServerPersistence(_host, setupId),
                _RemoteRoomPersistence(_host, setupId),
              ),
        client: client == null
            ? null
            : decodeClientOptions(
                client,
                _RemoteClientStorage(_host, setupId),
                setup._getPrivateKey,
              ),
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
    final message = WorkerEventMessage(generation, event);
    if (approximateMessageBytes(message) <= maxMessageBytes) {
      hostPort.send(message);
    } else {
      hostPort.send(
        WorkerEventMessage(
          generation,
          WorkerFailureEvent(
            event.setupId,
            generation,
            operation: 'event',
            message: 'Worker event exceeded the configured message limit.',
          ),
        ),
      );
    }
  }

  void _reply(int id, Object? result, {bool startedSetup = false}) {
    final message = WorkerReply.success(generation, id, result);
    if (approximateMessageBytes(message) > maxMessageBytes) {
      _replyError(
        id,
        startedSetup ? 'start_result_too_large' : 'message_too_large',
        startedSetup
            ? 'Roles started, but the snapshot exceeds the worker limit. '
                  'Providers remain bound; stop the setup before retrying.'
            : 'Reply exceeds worker limit.',
      );
    } else {
      hostPort.send(message);
    }
  }

  void _replyError(int id, String code, String message) => hostPort.send(
    WorkerReply.failure(
      generation,
      id,
      NoosphereWorkerException(code, message),
    ),
  );
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

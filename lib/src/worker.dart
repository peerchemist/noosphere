import 'dart:async';
import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart' show EndpointAddr;
import 'package:meta/meta.dart';
import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_server/noosphere_server.dart' show RoomPersistence;

import 'client_options.dart';
import 'server_options.dart';
import 'worker/command_channel.dart';
import 'worker_models.dart';
import 'worker_protocol.dart';

/// Public facade for an isolate-owned collection of ROAST setups.
final class NoosphereWorker {
  NoosphereWorker._(this._channel, {required this._testing});
  final WorkerCommandChannel _channel;
  final bool _testing;
  int get generation => _channel.generation;
  int get maxOutstandingCommands => _channel.maxOutstandingCommands;
  int get maxMessageBytes => _channel.maxMessageBytes;
  Duration get hostOperationTimeout => _channel.hostOperationTimeout;
  Duration get shutdownTimeout => _channel.shutdownTimeout;
  bool get isClosed => _channel.isClosed;
  Stream<NoosphereWorkerEvent> get events => _channel.events;
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
    int maxMessageBytes = defaultWorkerMaxMessageBytes,
    Duration shutdownTimeout = const Duration(seconds: 2),
  }) => _start(
    startupTimeout: startupTimeout,
    hostOperationTimeout: const Duration(seconds: 5),
    shutdownTimeout: shutdownTimeout,
    maxOutstandingCommands: 64,
    maxMessageBytes: maxMessageBytes,
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
    for (final entry in roomPersistences.entries) {
      worker._channel.registry.setup(entry.key).roomPersistence = entry.value;
    }
    for (final entry in clientStorages.entries) {
      worker._channel.registry.setup(entry.key).storage = entry.value;
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
  }) async => NoosphereWorker._(
    await WorkerCommandChannel.open(
      startupTimeout: startupTimeout,
      hostOperationTimeout: hostOperationTimeout,
      shutdownTimeout: shutdownTimeout,
      maxOutstandingCommands: maxOutstandingCommands,
      maxMessageBytes: maxMessageBytes,
      skipInitialization: skipInitialization,
      testing: testing,
      testHostOperation: testHostOperation,
      failStartup: failStartup,
    ),
    testing: testing,
  );

  Future<Object?> _invoke(
    WorkerOperation operation, {
    String? setupId,
    Map<String, Object?> payload = const {},
  }) => _channel.invoke(operation, setupId: setupId, payload: payload);

  /// Interrupts the test isolate to exercise pending-command cleanup.
  @visibleForTesting
  void debugKillForTesting() {
    if (!_testing) throw StateError('Only testing workers may be killed.');
    _channel.killForTesting();
  }

  /// Starts a command that intentionally waits until the test isolate exits.
  @visibleForTesting
  Future<void> debugPendingCommandForTesting() {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    return _invoke(WorkerOperation.testPending).then((_) {});
  }

  /// Invokes the injected host provider through the real correlated bridge.
  @visibleForTesting
  Future<Object?> debugHostRequestForTesting() {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    return _invoke(WorkerOperation.testHost);
  }

  /// Exercises the room adapter over the actual worker/host boundary.
  @visibleForTesting
  Future<Map<String, Uint8List>> debugLoadRoomsForTesting(
    String setupId,
  ) async {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    final records = await _invoke(
      WorkerOperation.testRoomLoad,
      setupId: setupId,
    );
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
      WorkerOperation.testRoomWrite,
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
      WorkerOperation.testClientStorage,
      setupId: setupId,
      payload: {'rejectRequestId': rejectRequestId},
    );
  }

  /// Ends the serving loop without stopping its setup, to exercise health
  /// reporting independently of the normal lifecycle command.
  @visibleForTesting
  Future<void> debugStopServingForTesting(String setupId) {
    if (!_testing) {
      throw StateError('Only testing workers support this command.');
    }
    return _invoke(
      WorkerOperation.testStopServing,
      setupId: setupId,
    ).then((_) {});
  }

  /// Starts roles. Concurrent lifecycle calls for this setup fail with
  /// `setup_busy`; await completion before starting, stopping or switching it.
  /// A `start_result_too_large` error means the roles DID start, but their
  /// snapshot could not be delivered. Providers remain bound. Use [stopSetup]
  /// before retrying with a worker configured for larger messages. A role whose
  /// serving loop failed also remains bound until [stopSetup] acknowledges its
  /// cleanup, even when a snapshot reports `serverRunning: false`.
  Future<NoosphereWorkerSnapshot> startSetup({
    required String setupId,
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  }) => _channel.registry.startSetup(
    setupId: setupId,
    server: server,
    client: client,
  );

  Future<void> stopSetup(
    String setupId, {
    NoosphereWorkerRoles roles = NoosphereWorkerRoles.both,
  }) => _channel.registry.stopSetup(setupId, roles: roles);

  /// Locks only the local signer; a server role in the same setup keeps
  /// coordinating other participants.
  Future<void> lockSigner(String setupId) =>
      stopSetup(setupId, roles: NoosphereWorkerRoles.signer);

  /// Updates the reconnect hint without changing the pinned coordinator ID.
  Future<void> updateSignerAddress(String setupId, EndpointAddr address) =>
      _invoke(
        WorkerOperation.updateSignerAddress,
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
  /// Before restarting with [startSetup] after a failed switch, acknowledge
  /// cleanup with [lockSigner] and reconcile the app's durable selection.
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
  }) => _channel.registry.switchCoordinator(
    setupId,
    newCoordinator: newCoordinator,
    persist: persist,
  );

  Future<NoosphereWorkerSnapshot> snapshot(String setupId) async {
    final result = await _invoke(WorkerOperation.snapshot, setupId: setupId);
    return result! as NoosphereWorkerSnapshot;
  }

  Future<void> requestDkg(String setupId, NewDkgDetails proposal) => _invoke(
    WorkerOperation.requestDkg,
    setupId: setupId,
    payload: {'proposal': proposal.toBytes()},
  ).then((_) {});

  Future<void> acceptDkg(String setupId, WorkerDkgStatus proposal) => _invoke(
    WorkerOperation.acceptDkg,
    setupId: setupId,
    payload: {'name': proposal.name, 'proposal': proposal.proposalBytes},
  ).then((_) {});

  Future<void> rejectDkg(String setupId, WorkerDkgStatus proposal) => _invoke(
    WorkerOperation.rejectDkg,
    setupId: setupId,
    payload: {'name': proposal.name, 'proposal': proposal.proposalBytes},
  ).then((_) {});

  Future<void> requestSignatures(
    String setupId,
    SignaturesRequestDetails proposal,
  ) => _invoke(
    WorkerOperation.requestSignatures,
    setupId: setupId,
    payload: {'proposal': proposal.toBytes()},
  ).then((_) {});

  Future<void> acceptSignatures(
    String setupId,
    WorkerSigningRequest proposal,
  ) => _invoke(
    WorkerOperation.acceptSignatures,
    setupId: setupId,
    payload: {'id': proposal.id, 'proposal': proposal.proposalBytes},
  ).then((_) {});

  Future<void> rejectSignatures(
    String setupId,
    WorkerSigningRequest proposal,
  ) => _invoke(
    WorkerOperation.rejectSignatures,
    setupId: setupId,
    payload: {'id': proposal.id, 'proposal': proposal.proposalBytes},
  ).then((_) {});

  Future<void> close() => _channel.close();
}

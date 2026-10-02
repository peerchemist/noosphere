import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart' show EndpointAddr;

import '../client_options.dart';
import '../server_identity_store.dart';
import '../server_options.dart';
import '../worker_models.dart';
import '../worker_protocol.dart';
import 'worker_host_setup.dart';

/// The host reserves providers until the runtime acknowledges role cleanup.
/// Health and provider ownership are deliberately independent.
enum HostRolePhase { idle, starting, active, stopping, cleanupRequired }

typedef InvokeWorker = Future<Object?> Function(
  WorkerOperation operation, {
  String? setupId,
  Map<String, Object?> payload,
});

final class HostProviderRegistry {
  HostProviderRegistry(this.invoke);
  final InvokeWorker invoke;
  final _setups = <String, HostSetup>{};
  final _lifecycleSetups = <String>{};
  final _phases = <String, Map<NoosphereWorkerRoles, HostRolePhase>>{};
  Iterable<String> get setupIds => _setups.keys;
  HostSetup setup(String id) => _setups.putIfAbsent(id, HostSetup.new);
  HostRolePhase phase(String id, NoosphereWorkerRoles role) =>
      _phases[id]?[role] ?? HostRolePhase.idle;
  void _phase(String id, NoosphereWorkerRoles role, HostRolePhase phase) {
    final phases = _phases.putIfAbsent(id, () => {});
    for (final r in [
      NoosphereWorkerRoles.server,
      NoosphereWorkerRoles.signer,
    ]) {
      if (role == NoosphereWorkerRoles.both || r == role) phases[r] = phase;
    }
  }

  void clear() {
    _setups.clear();
    _phases.clear();
  }

  Future<Object?> dispatch(
    String id,
    ProviderOperation operation,
    Map<String, Object?> payload,
  ) {
    final setup = _setups[id];
    if (setup == null) throw StateError('Unknown setup.');
    return setup.dispatch(operation, payload);
  }

  Future<NoosphereWorkerSnapshot> startSetup({
    required String setupId,
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  }) => _withSetupLifecycle(setupId, () async {
    _validateSetupId(setupId);
    if (server == null && client == null) {
      throw ArgumentError('At least one worker role is required.');
    }

    final setup = _setups.putIfAbsent(setupId, HostSetup.new);
    // A bound role owns its providers until stopSetup acknowledges cleanup.
    // Serving health alone cannot release that ownership: a failed serve loop
    // may still be flushing persistence, and a snapshot may be too large.
    if ((server != null && setup.identityStore != null) ||
        (client != null && setup.storage != null)) {
      throw StateError(
        'Requested role is already bound; stop it before restarting.',
      );
    }
    final previousProviders = setup.providers;
    setup.bind(server: server, client: client);
    final roles = server == null
        ? NoosphereWorkerRoles.signer
        : client == null
        ? NoosphereWorkerRoles.server
        : NoosphereWorkerRoles.both;
    _phase(setupId, roles, HostRolePhase.starting);

    try {
      final result = await invoke(
        WorkerOperation.startSetup,
        setupId: setupId,
        payload: {
          'server': server == null ? null : encodeServerOptions(server),
          'client': client == null ? null : encodeClientOptions(client),
        },
      );
      _phase(setupId, roles, HostRolePhase.active);
      return result! as NoosphereWorkerSnapshot;
    } catch (error) {
      // Startup committed successfully. Keep the providers serving those roles
      // even when the full result cannot cross the isolate boundary.
      if (error is NoosphereWorkerException &&
          error.code == 'start_result_too_large') {
        _phase(setupId, roles, HostRolePhase.active);
        rethrow;
      }
      if (error is NoosphereWorkerException &&
          error.code == 'startup_cleanup_failed') {
        _phase(setupId, roles, HostRolePhase.cleanupRequired);
        rethrow;
      }
      _phase(setupId, roles, HostRolePhase.idle);
      setup.providers = previousProviders;
      if (!setup.hasProviders) {
        _setups.remove(setupId);
        _phases.remove(setupId);
      }
      rethrow;
    }
  });

  Future<void> stopSetup(
    String setupId, {
    NoosphereWorkerRoles roles = NoosphereWorkerRoles.both,
  }) => _withSetupLifecycle(setupId, () async {
    _phase(setupId, roles, HostRolePhase.stopping);
    try {
      await invoke(
        WorkerOperation.stopRoles,
        setupId: setupId,
        payload: {'roles': roles.index},
      );
    } catch (_) {
      _phase(setupId, roles, HostRolePhase.cleanupRequired);
      rethrow;
    }
    _phase(setupId, roles, HostRolePhase.idle);
    final setup = _setups[setupId];
    if (setup == null) {
      _phases.remove(setupId);
      return;
    }
    setup.unbind(roles);
    if (!setup.hasProviders) {
      _setups.remove(setupId);
      _phases.remove(setupId);
    }
  });

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
    _phase(setupId, NoosphereWorkerRoles.signer, HostRolePhase.stopping);
    try {
      final result =
          (await invoke(
                WorkerOperation.switchCoordinator,
                setupId: setupId,
                payload: {'address': encodeEndpointAddress(newCoordinator)},
              ))!
              as NoosphereWorkerSnapshot;
      _phase(setupId, NoosphereWorkerRoles.signer, HostRolePhase.active);
      return result;
    } catch (_) {
      _phase(
        setupId,
        NoosphereWorkerRoles.signer,
        HostRolePhase.cleanupRequired,
      );
      rethrow;
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

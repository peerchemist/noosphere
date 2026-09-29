part of '../worker.dart';

typedef _HostProviders = ({
  ServerIdentityStore? identityStore,
  ServerPersistence? serverPersistence,
  ClientStorageInterface? storage,
  RoomPersistence? roomPersistence,
  GetPrivateKey? getPrivateKey,
  String? participant,
});

// A timed-out provider call is still running even after its worker closes.
// Keep room reads/writes ordered for the same host provider across setup and
// worker lifetimes, so a replacement cannot load ahead of an old commit.
final _roomPersistenceQueues = Expando<SerialExecutor>(
  'Room persistence queues',
);
final _serverPersistenceQueues = Expando<SerialExecutor>(
  'Server persistence queues',
);

final class _HostSetup {
  ServerIdentityStore? identityStore;
  ServerPersistence? serverPersistence;
  Future<Uint8List>? _identity;
  ServerIdentityStore? _identityProvider;
  ClientStorageInterface? storage;
  RoomPersistence? roomPersistence;
  GetPrivateKey? getPrivateKey;
  String? participant;
  Future<void> Function()? persistCoordinator;
  final _storageSerial = SerialExecutor();

  bool get hasProviders =>
      identityStore != null ||
      serverPersistence != null ||
      storage != null ||
      roomPersistence != null ||
      getPrivateKey != null;

  _HostProviders get providers => (
    identityStore: identityStore,
    serverPersistence: serverPersistence,
    storage: storage,
    roomPersistence: roomPersistence,
    getPrivateKey: getPrivateKey,
    participant: participant,
  );

  set providers(_HostProviders value) {
    identityStore = value.identityStore;
    serverPersistence = value.serverPersistence;
    if (!identical(_identityProvider, identityStore)) {
      _identity = null;
      _identityProvider = null;
    }
    storage = value.storage;
    roomPersistence = value.roomPersistence;
    getPrivateKey = value.getPrivateKey;
    participant = value.participant;
  }

  void bind({
    required EmbeddedServerOptions? server,
    required ClientNodeOptions? client,
  }) {
    if (server != null) {
      if (!identical(identityStore, server.identityStore)) {
        _identity = null;
        _identityProvider = null;
      }
      identityStore = server.identityStore;
      serverPersistence = server.serverPersistence;
      roomPersistence = server.roomPersistence;
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
      serverPersistence = null;
      roomPersistence = null;
      _identity = null;
      _identityProvider = null;
    }
  }

  Future<Object?> dispatch(
    String operation,
    Map<Object?, Object?> payload,
  ) async {
    switch (operation) {
      case 'coordinator.persist':
        final persist = persistCoordinator;
        if (persist == null) {
          throw StateError('No coordinator switch pending.');
        }
        return _serializeStorage(() async {
          await persist();
          return null;
        });
      case 'identity.read':
        return loadOrCreateIdentity();
      case 'identity.write':
        final store = identityStore;
        if (store == null) throw StateError('No identity store.');
        await store.write(asBytes(payload['secret']));
        return null;
      case 'rooms.loadAll':
      case 'rooms.write':
        final rooms = roomPersistence;
        if (rooms == null) throw StateError('No room persistence provider.');
        final queue = _roomPersistenceQueues[rooms] ??= SerialExecutor();
        return queue.run(
          () => _serializeStorage(() async {
            if (operation == 'rooms.loadAll') {
              return {
                for (final entry in (await rooms.loadAll()).entries)
                  entry.key: Uint8List.fromList(entry.value),
              };
            }
            await rooms.write(
              payload['roomId']! as String,
              asBytes(payload['state']),
            );
            return null;
          }),
        );
      case 'server.load':
      case 'server.write':
        final server = serverPersistence;
        if (server == null) {
          throw StateError('No server persistence provider.');
        }
        final queue = _serverPersistenceQueues[server] ??= SerialExecutor();
        return queue.run(
          () => _serializeStorage(() async {
            final groupId = payload['groupId']! as String;
            if (operation == 'server.load') {
              return (await server.load(groupId))?.toBytes();
            }
            await server.write(
              groupId,
              ServerStateSnapshot.fromBytes(asBytes(payload['state'])),
            );
            return null;
          }),
        );
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

  Future<Uint8List> loadOrCreateIdentity() {
    final store = identityStore;
    if (store == null) throw StateError('No identity store.');
    if (!identical(_identityProvider, store)) {
      _identityProvider = store;
      _identity = null;
    }
    return _identity ??= loadOrCreateServerIdentity(store)
        .then((key) => Uint8List.fromList(key.toBytes()));
  }

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
      case 'storage.loadState':
        final snapshot = await store.loadState();
        return {
          'keys': [for (final key in snapshot.keys) key.toBytes()],
          'nonces': [
            for (final entry in snapshot.sigNonces.entries)
              {
                'id': entry.key.toBytes(),
                'nonces': encodeSignaturesNonces(entry.value),
              },
          ],
          'prepared': [
            for (final operation in snapshot.preparedOperations.values)
              operation.toBytes(),
          ],
          'rejected': [
            for (final entry in snapshot.rejectedRequests.entries)
              {
                'id': entry.key.toBytes(),
                'expiryMicros': entry.value.expiry.time.microsecondsSinceEpoch,
              },
          ],
        };
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

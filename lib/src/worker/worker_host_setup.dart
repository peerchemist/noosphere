import 'dart:async';
import 'dart:typed_data';

import 'package:noosphere_client/noosphere_client.dart';
import 'package:noosphere_server/noosphere_server.dart'
    show RoomPersistence, ServerPersistence, ServerStateSnapshot;

import '../client_options.dart';
import '../server_options.dart';
import '../worker_models.dart';
import '../worker_protocol.dart';

typedef HostProviders = ({
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
final _clientStorageQueues = Expando<SerialExecutor>('Client storage queues');

final class HostSetup {
  ServerPersistence? serverPersistence;
  ClientStorageInterface? storage;
  RoomPersistence? roomPersistence;
  GetPrivateKey? getPrivateKey;
  String? participant;
  Future<void> Function()? persistCoordinator;
  final _storageSerial = SerialExecutor();

  bool get hasProviders =>
      serverPersistence != null ||
      storage != null ||
      roomPersistence != null ||
      getPrivateKey != null;

  HostProviders get providers => (
    serverPersistence: serverPersistence,
    storage: storage,
    roomPersistence: roomPersistence,
    getPrivateKey: getPrivateKey,
    participant: participant,
  );

  set providers(HostProviders value) {
    serverPersistence = value.serverPersistence;
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
      serverPersistence = null;
      roomPersistence = null;
    }
  }

  Future<Object?> dispatch(
    ProviderOperation operation,
    Map<Object?, Object?> payload,
  ) async {
    switch (operation) {
      case ProviderOperation.persistCoordinator:
        final persist = persistCoordinator;
        if (persist == null) {
          throw StateError('No coordinator switch pending.');
        }
        return _serializeStorage(() async {
          await persist();
          return null;
        });
      case ProviderOperation.loadRooms:
      case ProviderOperation.writeRoom:
        final rooms = roomPersistence;
        if (rooms == null) throw StateError('No room persistence provider.');
        final queue = _roomPersistenceQueues[rooms] ??= SerialExecutor();
        return queue.run(
          () => _serializeStorage(() async {
            if (operation == ProviderOperation.loadRooms) {
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
      case ProviderOperation.loadServer:
      case ProviderOperation.writeServer:
        final server = serverPersistence;
        if (server == null) {
          throw StateError('No server persistence provider.');
        }
        final queue = _serverPersistenceQueues[server] ??= SerialExecutor();
        return queue.run(
          () => _serializeStorage(() async {
            final groupId = payload['groupId']! as String;
            if (operation == ProviderOperation.loadServer) {
              return (await server.load(groupId))?.toBytes();
            }
            await server.write(
              groupId,
              ServerStateSnapshot.fromBytes(asBytes(payload['state'])),
            );
            return null;
          }),
        );
      case ProviderOperation.getPrivateKey:
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
        // Capture the provider now: a timed-out request may remain queued
        // after this setup is stopped or rebound. A replacement using the same
        // provider must wait for the old durable write before loading nonces.
        final store = storage;
        if (store == null) throw StateError('Signer storage is unavailable.');
        final queue = _clientStorageQueues[store] ??= SerialExecutor();
        return queue.run(
          () => _serializeStorage(
            () => _dispatchStorage(store, operation, payload),
          ),
        );
    }
  }

  Future<T> _serializeStorage<T>(Future<T> Function() operation) =>
      _storageSerial.run(operation);

  Future<Object?> _dispatchStorage(
    ClientStorageInterface store,
    ProviderOperation operation,
    Map<Object?, Object?> payload,
  ) async {
    final id = payload['id'] == null
        ? null
        : SignaturesRequestId.fromBytes(asBytes(payload['id']));
    switch (operation) {
      case ProviderOperation.loadState:
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
      case ProviderOperation.addKey:
        await store.addOrReplaceFrostKey(
          FrostKeyWithDetails.fromBytes(asBytes(payload['key'])),
        );
      case ProviderOperation.addNonces:
        await store.addSignaturesNonces(
          id!,
          decodeSignaturesNonces(payload['nonces']! as Map<Object?, Object?>),
          payload['capacity']! as int,
        );
      case ProviderOperation.prepareSignatures:
        await store.prepareSignaturesOperation(
          PreparedSignaturesOperation.fromBytes(asBytes(payload['operation'])),
          payload['capacity']! as int,
        );
      case ProviderOperation.completeSignatures:
        await store.completeSignaturesOperation(id!);
      case ProviderOperation.addRejection:
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
      case ProviderOperation.removeRejection:
        await store.removeRejectionOfSigsRequest(id!);
      case ProviderOperation.removeSignatures:
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

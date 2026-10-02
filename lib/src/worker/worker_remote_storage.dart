part of '../worker_runtime.dart';

final class _RemoteRoomPersistence(this.host, this.setupId)
    implements RoomPersistence {
  final _HostBridge host;
  final String setupId;

  @override
  Future<Map<String, Uint8List>> loadAll() async {
    final records = await host.request(setupId, 'rooms.loadAll', const {});
    return {
      for (final entry in (records! as Map).entries)
        entry.key as String: asBytes(entry.value),
    };
  }

  @override
  Future<void> write(String roomId, Uint8List state) => host
      .request(setupId, 'rooms.write', {
        'roomId': roomId,
        'state': Uint8List.fromList(state),
      })
      .then((_) {});
}

final class _RemoteServerPersistence(this.host, this.setupId)
    implements ServerPersistence {
  final _HostBridge host;
  final String setupId;

  @override
  Future<ServerStateSnapshot?> load(String groupId) async {
    final value = await host.request(setupId, 'server.load', {
      'groupId': groupId,
    });
    return value == null ? null : ServerStateSnapshot.fromBytes(asBytes(value));
  }

  @override
  Future<void> write(String groupId, ServerStateSnapshot state) => host
      .request(setupId, 'server.write', {
        'groupId': groupId,
        'state': state.toBytes(),
      })
      .then((_) {});
}

final class _RemoteIdentityStore(this.host, this.setupId)
    implements ServerIdentityStore {
  final _HostBridge host;
  final String setupId;

  @override
  Future<Uint8List> read() async {
    final result = await host.request(setupId, 'identity.read', const {});
    return asBytes(result);
  }

  @override
  Future<void> write(Uint8List secret) => throw UnsupportedError(
    'The host owns identity creation and restoration.',
  );
}

final class _RemoteClientStorage(this.host, this.setupId)
    implements ClientStorageInterface {
  final _HostBridge host;
  final String setupId;

  @override
  Future<ClientStorageSnapshot> loadState() async {
    final value = await host.request(setupId, 'storage.loadState', const {});
    final snapshot = value! as Map<Object?, Object?>;
    final keys = {
      for (final bytes in snapshot['keys']! as List)
        FrostKeyWithDetails.fromBytes(asBytes(bytes)),
    };
    final nonces = {
      for (final raw in snapshot['nonces']! as List)
        SignaturesRequestId.fromBytes(
          asBytes((raw as Map<Object?, Object?>)['id']),
        ): decodeSignaturesNonces(
          raw['nonces']! as Map<Object?, Object?>,
        ),
    };
    final operations = [
      for (final bytes in snapshot['prepared']! as List)
        PreparedSignaturesOperation.fromBytes(asBytes(bytes)),
    ];
    final rejected = {
      for (final raw in snapshot['rejected']! as List)
        SignaturesRequestId.fromBytes(
          asBytes((raw as Map<Object?, Object?>)['id']),
        ): FinalExpirable(
          Expiry.fromTime(
            DateTime.fromMicrosecondsSinceEpoch(raw['expiryMicros']! as int),
          ),
        ),
    };
    return ClientStorageSnapshot(
      keys: keys,
      sigNonces: nonces,
      preparedOperations: {
        for (final operation in operations) operation.id: operation,
      },
      rejectedRequests: rejected,
    );
  }

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
}

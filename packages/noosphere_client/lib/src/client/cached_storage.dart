import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere/api/types/cancelled_signatures_request.dart';
import 'package:noosphere/api/types/dkg_ack_request.dart';
import 'package:noosphere/api/types/expirable.dart';
import 'package:noosphere/api/types/expiry.dart';
import 'package:noosphere/api/types/signatures_request_details.dart';
import 'package:noosphere/api/types/signed_dkg_ack.dart';
import 'package:noosphere/common/expirable_map.dart';
import 'package:noosphere_client/src/client/frost_key_with_details.dart';
import 'package:noosphere_client/src/client/storage_interface.dart';

class ClientCachedStorage {
  final ClientStorageInterface _underlying;
  final Map<cl.ECCompressedPublicKey, FrostKeyWithDetails> keys;
  final ExpirableMap<SignaturesRequestId, SignaturesNonces> sigNonces;
  final ExpirableMap<SignaturesRequestId, PreparedSignaturesOperation>
  preparedSigOperations;
  final ExpirableMap<SignaturesRequestId, FinalExpirable> sigsRejected;
  final ExpirableMap<SignaturesRequestId, CancelledSignaturesRequest>
  cancelledRequests;
  bool _writeOutcomeUnknown = false;

  void requireReady() {
    if (_writeOutcomeUnknown) {
      throw StateError(
        'Client cancellation persistence outcome is unknown; reload storage',
      );
    }
  }

  Future<void> cancelSignaturesRequest(
    CancelledSignaturesRequest tombstone,
  ) async {
    requireReady();
    try {
      await _underlying.cancelSignaturesRequest(
        tombstone.requestId,
        tombstone.expiry,
      );
    } catch (_) {
      _writeOutcomeUnknown = true;
      rethrow;
    }
    sigNonces.remove(tombstone.requestId);
    preparedSigOperations.remove(tombstone.requestId);
    sigsRejected.remove(tombstone.requestId);
    cancelledRequests[tombstone.requestId] = tombstone;
  }

  Future<void> pruneCancelledSignaturesRequests() async {
    requireReady();
    await _underlying.pruneCancelledSignaturesRequests();
    cancelledRequests.removeExpired();
  }

  ClientCachedStorage._(
    this._underlying,
    this.keys,
    this.sigNonces,
    this.preparedSigOperations,
    this.sigsRejected,
    this.cancelledRequests,
  );

  static Future<ClientCachedStorage> load(ClientStorageInterface store) async {
    await store.pruneCancelledSignaturesRequests();
    final snapshot = await store.loadState();
    for (final entry in snapshot.cancelledRequests.entries) {
      if (entry.key != entry.value.requestId ||
          snapshot.sigNonces.containsKey(entry.key) ||
          snapshot.preparedOperations.containsKey(entry.key) ||
          snapshot.rejectedRequests.containsKey(entry.key)) {
        throw StateError('Cancellation tombstone coexists with signing state');
      }
    }
    return ClientCachedStorage._(
      store,
      {for (final key in snapshot.keys) key.groupKey: key},
      ExpirableMap.of(snapshot.sigNonces),
      ExpirableMap.of(snapshot.preparedOperations),
      ExpirableMap.of(snapshot.rejectedRequests),
      ExpirableMap.of(snapshot.cancelledRequests),
    );
  }

  Future<void> addOrReplaceFrostKey(FrostKeyWithDetails key) async {
    await _underlying.addOrReplaceFrostKey(key);
    keys[key.groupKey] = key;
  }

  Future<void> prepareSignaturesOperation({
    required PreparedSignaturesOperation operation,
    required int capacity,
  }) async {
    final id = operation.id;
    requireReady();
    if (cancelledRequests.containsKey(id)) {
      throw StateError('Signatures request was cancelled');
    }
    try {
      await _underlying.prepareSignaturesOperation(operation, capacity);
    } catch (_) {
      // A provider may have committed before reporting failure or timing out.
      // Keep this request blocked in the current session until durable state
      // is loaded again; no RPC follows a failed prepare call.
      preparedSigOperations[id] = operation;
      rethrow;
    }
    final updated = Map<int, SigningNonces>.of(sigNonces[id]?.map ?? {});
    updated.addEntries(operation.nextNonces.map.entries);
    sigNonces[id] = SignaturesNonces(updated, operation.expiry);
    preparedSigOperations[id] = operation;
  }

  Future<void> completeSignaturesOperation(SignaturesRequestId id) async {
    await _underlying.completeSignaturesOperation(id);
    preparedSigOperations.remove(id);
  }

  Set<SignedDkgAck> getAcksForRequest(DkgAckRequest request) =>
      keys[request.groupPublicKey]?.acks
          .where((ack) => request.ids.contains(ack.signer))
          .toSet() ??
      {};

  Set<DkgAckRequest> getAckRequestsForMissing(Set<Identifier> ids)
  // Get ids that do not already have ACKs and get the group key
  => keys.values
      .map(
        (key) => (
          ids.where((id) => !key.acks.any((ack) => ack.signer == id)).toSet(),
          key.groupKey,
        ),
      )
      // Ignore keys where there are no missing ids
      .where((tuple) => tuple.$1.isNotEmpty)
      // Create DkgAckRequests for IDs and group key
      .map((tuple) => DkgAckRequest(ids: tuple.$1, groupPublicKey: tuple.$2))
      .toSet();

  Future<void> addSignaturesNonces({
    required SignaturesRequestId id,
    required SignaturesNonces nonces,
    required int capacity,
  }) async {
    requireReady();
    if (cancelledRequests.containsKey(id)) {
      throw StateError('Signatures request was cancelled');
    }
    await _underlying.addSignaturesNonces(id, nonces, capacity);
    if (sigNonces.containsKey(id)) {
      final previous = sigNonces[id]!;
      sigNonces[id] = SignaturesNonces({
        ...previous.map,
        ...nonces.map,
      }, previous.expiry);
    } else {
      sigNonces[id] = nonces;
    }
  }

  Future<void> addRejectedSigsRequest(
    SignaturesRequestId id,
    Expiry expiry,
  ) async {
    final expirable = FinalExpirable(expiry);
    await _underlying.addRejectedSigsRequest(id, expirable);
    sigsRejected[id] = expirable;
  }

  Future<void> removeRejectionOfSigsRequest(SignaturesRequestId id) async {
    await _underlying.removeRejectionOfSigsRequest(id);
    sigsRejected.remove(id);
  }

  Future<void> removeSigsRequest(SignaturesRequestId id) async {
    await _underlying.removeSigsRequest(id);
    sigNonces.remove(id);
    preparedSigOperations.remove(id);
    sigsRejected.remove(id);
  }
}

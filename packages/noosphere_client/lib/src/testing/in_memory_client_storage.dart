import 'dart:async';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:collection/collection.dart';
import 'package:noosphere/api/types/expirable.dart';
import 'package:noosphere/api/types/signatures_request_details.dart';
import 'package:noosphere_client/src/client/storage_interface.dart';
import 'package:frosty/frosty.dart';

import '../client/frost_key_with_details.dart';

class KeyToComplete {
  final int expAcks;
  final completer = Completer<FrostKeyWithDetails>();
  KeyToComplete(this.expAcks);
}

/// Non-durable client storage for tests and examples only.
class InMemoryClientStorage implements ClientStorageInterface {
  final Map<cl.ECPublicKey, FrostKeyWithDetails> keys = {};
  final Map<SignaturesRequestId, SignaturesNonces> sigNonces = {};
  final Map<SignaturesRequestId, PreparedSignaturesOperation>
  preparedSigOperations = {};
  final Map<SignaturesRequestId, FinalExpirable> sigsRejected = {};

  final Map<String, KeyToComplete> keyCompleters = {};

  void _maybeCompleteKey(FrostKeyWithDetails key) {
    final toComplete = keyCompleters[key.name];
    if (toComplete == null) return;

    if (key.acceptedAcks >= toComplete.expAcks) {
      toComplete.completer.complete(key);
      keyCompleters.remove(key.name);
    }
  }

  @override
  Future<void> addOrReplaceFrostKey(FrostKeyWithDetails newKey) async {
    keys[newKey.groupKey] = newKey;
    _maybeCompleteKey(newKey);
  }

  @override
  Future<ClientStorageSnapshot> loadState() async => ClientStorageSnapshot(
    keys: keys.values,
    sigNonces: sigNonces,
    preparedOperations: preparedSigOperations,
    rejectedRequests: sigsRejected,
  );

  @override
  Future<void> addRejectedSigsRequest(
    SignaturesRequestId id,
    FinalExpirable expirable,
  ) async {
    sigsRejected[id] = expirable;
  }

  @override
  Future<void> addSignaturesNonces(
    SignaturesRequestId id,
    SignaturesNonces nonces,
    int capacity,
  ) async {
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

  @override
  Future<void> prepareSignaturesOperation(
    PreparedSignaturesOperation operation,
    int capacity,
  ) async {
    final id = operation.id;
    final updated = Map<int, SigningNonces>.of(sigNonces[id]?.map ?? {});
    updated.addEntries(operation.nextNonces.map.entries);
    sigNonces[id] = SignaturesNonces(updated, operation.expiry);
    preparedSigOperations[id] = operation;
  }

  @override
  Future<void> completeSignaturesOperation(SignaturesRequestId id) async {
    preparedSigOperations.remove(id);
  }

  @override
  Future<void> removeRejectionOfSigsRequest(SignaturesRequestId id) async {
    sigsRejected.remove(id);
  }

  @override
  Future<void> removeSigsRequest(SignaturesRequestId id) async {
    sigNonces.remove(id);
    preparedSigOperations.remove(id);
    sigsRejected.remove(id);
  }

  /// Waits for a key to be created and receive a number of ACKs. Must only be
  /// used once at a time.
  Future<FrostKeyWithDetails> waitForKeyWithName(
    String name,
    int expAcks,
  ) async {
    final key = keys.values.firstWhereOrNull((key) => key.name == name);
    if (key != null && key.acceptedAcks >= expAcks) return key;

    final toComplete = keyCompleters[name] = KeyToComplete(expAcks);
    return await toComplete.completer.future;
  }
}

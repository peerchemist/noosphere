import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_client/src/api/types/expirable.dart';
import 'package:noosphere_client/src/api/types/expiry.dart';
import 'package:noosphere_client/src/api/types/signatures_request_details.dart';
import 'package:noosphere_client/src/api/types/signed_dkg_ack.dart';
import 'package:frosty/frosty.dart';

import 'frost_key_with_details.dart';

class SignaturesNonces implements Expirable {
  /// Maps the index of a signature in a request with the nonce to store.
  final Map<int, SigningNonces> map;
  @override
  final Expiry expiry;
  SignaturesNonces(this.map, this.expiry);
}

enum PreparedSignaturesOperationKind { request, replies }

/// A signing operation durably prepared before its network request is sent.
///
/// Presence of this record means that the outcome of the operation may be
/// unknown. The client must not prepare another operation for the same
/// signatures request until this record has been cleared after a response.
class PreparedSignaturesOperation with cl.Writable implements Expirable {
  final SignaturesRequestId id;
  final PreparedSignaturesOperationKind kind;

  /// Canonical domain payload components sent by the operation.
  final List<Uint8List> payloads;

  /// Signing-round transcripts consumed while producing [payloads].
  final List<Uint8List> transcripts;

  /// Nonces corresponding to commitments contained in [payloads].
  final SignaturesNonces nextNonces;

  @override
  Expiry get expiry => nextNonces.expiry;

  PreparedSignaturesOperation({
    required this.id,
    required this.kind,
    required List<Uint8List> payloads,
    required List<Uint8List> transcripts,
    required this.nextNonces,
  }) : payloads = payloads.map(Uint8List.fromList).toList(growable: false),
       transcripts = transcripts
           .map(Uint8List.fromList)
           .toList(growable: false) {
    if (payloads.length > 0xffff || transcripts.length > 0xffff) {
      throw ArgumentError('too many prepared operation components');
    }
    if (nextNonces.map.length > 0xffff) {
      throw ArgumentError('too many signature nonces');
    }
  }

  factory PreparedSignaturesOperation.fromReader(cl.BytesReader reader) {
    final id = SignaturesRequestId.fromReader(reader);
    final kindIndex = reader.readUInt8();
    if (kindIndex >= PreparedSignaturesOperationKind.values.length) {
      throw ArgumentError.value(kindIndex, 'kind', 'unknown operation kind');
    }
    final expiry = Expiry.fromReader(reader);
    final nonces = <int, SigningNonces>{};
    final nonceCount = reader.readUInt16();
    for (var i = 0; i < nonceCount; i++) {
      nonces[reader.readUInt16()] = SigningNonces.fromBytes(
        reader.readVarSlice(),
      );
    }
    List<Uint8List> readComponents() => List.generate(
      reader.readUInt16(),
      (_) => reader.readVarSlice(),
      growable: false,
    );
    return PreparedSignaturesOperation(
      id: id,
      kind: PreparedSignaturesOperationKind.values[kindIndex],
      payloads: readComponents(),
      transcripts: readComponents(),
      nextNonces: SignaturesNonces(nonces, expiry),
    );
  }

  factory PreparedSignaturesOperation.fromBytes(Uint8List bytes) =>
      PreparedSignaturesOperation.fromReader(cl.BytesReader(bytes));

  @override
  void write(cl.Writer writer) {
    id.write(writer);
    writer.writeUInt8(kind.index);
    expiry.write(writer);
    final nonceEntries = nextNonces.map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    writer.writeUInt16(nonceEntries.length);
    for (final entry in nonceEntries) {
      writer.writeUInt16(entry.key);
      writer.writeVarSlice(entry.value.toBytes());
    }
    void writeComponents(List<Uint8List> components) {
      writer.writeUInt16(components.length);
      for (final component in components) {
        writer.writeVarSlice(component);
      }
    }

    writeComponents(payloads);
    writeComponents(transcripts);
  }
}

/// These methods need to be implemented for permanent storage of key
/// information.
abstract interface class ClientStorageInterface {
  /// Add or replace the key with details to the storage. If the
  /// [FrostKeyWithDetails.groupKey] is the same as an existing key, it must be
  /// replaced with the new details.
  Future<void> addOrReplaceFrostKey(FrostKeyWithDetails newKey);

  /// Stores the nonces for the presignatures of a request given by [id]. Each
  /// nonce is mapped by the signature index in the request.
  ///
  /// [capacity] provides the total possible number of nonces that may need to
  /// be stored, so that a list may be pre-allocated.
  ///
  /// Existing nonces for a given signature index included in the map should be
  /// replaced. Existing nonces for signature indexes that are not included in
  /// the map should not be removed.
  ///
  /// The nonces can be safely removed after they have expired.
  Future<void> addSignaturesNonces(
    SignaturesRequestId id,
    SignaturesNonces nonces,
    int capacity,
  );

  /// Atomically stores [operation] and replaces the nonce indexes contained in
  /// [PreparedSignaturesOperation.nextNonces]. This must be durable before the
  /// returned future completes. No network request may be sent before it does.
  ///
  /// If the process stops or the network outcome is unknown before
  /// [completeSignaturesOperation] succeeds, the operation remains prepared
  /// and blocks further signing for the request. [capacity] is the maximum
  /// number of nonce indexes for the signatures request.
  Future<void> prepareSignaturesOperation(
    PreparedSignaturesOperation operation,
    int capacity,
  );

  /// Marks a prepared signing operation as having received a response. This
  /// does not remove the next nonces stored with the operation.
  Future<void> completeSignaturesOperation(SignaturesRequestId id);

  /// Add the ID of a signatures request that was rejected. This may be removed
  /// when [expirable] expires or by [removeRejectionOfSigsRequest].
  Future<void> addRejectedSigsRequest(
    SignaturesRequestId id,
    FinalExpirable expirable,
  );

  /// Removes the ID of a signatures request that is no longer rejected.
  Future<void> removeRejectionOfSigsRequest(SignaturesRequestId id);

  /// Remove all data (rejection and/or nonces) for a signatures request
  Future<void> removeSigsRequest(SignaturesRequestId id);

  /// Load the key details including [SignedDkgAck]s.
  Future<Set<FrostKeyWithDetails>> loadKeys();

  /// For every non-expired signature request, this should return a map from the
  // [SignaturesRequestId] to the [SignaturesNonces].
  Future<Map<SignaturesRequestId, SignaturesNonces>> loadSigNonces();

  /// Loads non-expired operations whose network outcome is not known to have
  /// been received by the client.
  Future<Map<SignaturesRequestId, PreparedSignaturesOperation>>
  loadPreparedSignaturesOperations();

  /// Loads the IDs of all of the signatures requests that were rejected by the
  /// client
  Future<Map<SignaturesRequestId, FinalExpirable>> loadRejectedSigsRequests();
}

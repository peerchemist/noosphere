import 'dart:isolate';
import 'dart:typed_data';

import '../worker_models.dart';

/// Private operations, shared by both ends of the same worker build.
enum WorkerOperation {
  startSetup,
  stopRoles,
  snapshot,
  switchCoordinator,
  updateSignerAddress,
  requestDkg,
  acceptDkg,
  rejectDkg,
  requestSignatures,
  acceptSignatures,
  rejectSignatures,
  close,
  testStopServing,
  testPending,
  testRoomLoad,
  testRoomWrite,
  testHost,
  testClientStorage,
}

enum ProviderOperation {
  persistCoordinator,
  readIdentity,
  loadRooms,
  writeRoom,
  loadServer,
  writeServer,
  getPrivateKey,
  loadState,
  addKey,
  addNonces,
  prepareSignatures,
  completeSignatures,
  addRejection,
  removeRejection,
  removeSignatures,
  testHost,
}

/// Copies mutable payload data and restricts payloads to isolate-safe values.
/// Domain/native objects must be encoded by the configuration/storage codecs.
Object? _copyValue(Object? value) => switch (value) {
  null || bool() || int() || double() || String() => value,
  Uint8List() => Uint8List.fromList(value).asUnmodifiableView(),
  List() => List<Object?>.unmodifiable(value.map(_copyValue)),
  Map() => Map<String, Object?>.unmodifiable({
    for (final entry in value.entries)
      _stringKey(entry.key): _copyValue(entry.value),
  }),
  _ => throw const FormatException('Unsupported worker payload value'),
};

final class MessageFields {
  MessageFields(Map<String, Object?> values)
    : values = _copyValue(values)! as Map<String, Object?>;
  final Map<String, Object?> values;
  T require<T>(String key) {
    final value = values[key];
    if (value is! T) throw FormatException('Invalid worker field: $key');
    return value;
  }

  T? optional<T>(String key) => values[key] == null ? null : require<T>(key);
  Uint8List bytes(String key) => require<Uint8List>(key);
  String string(String key) => require<String>(key);
  int integer(String key) => require<int>(key);
  Map<String, Object?> map(String key) => require<Map<String, Object?>>(key);
}

sealed class WorkerMessage {
  const WorkerMessage(this.generation);
  final int generation;
}

final class WorkerCommand extends WorkerMessage {
  WorkerCommand(
    super.generation,
    this.id,
    this.operation, {
    this.setupId,
    Map<String, Object?> payload = const {},
  }) : fields = MessageFields(payload);
  final int id;
  final WorkerOperation operation;
  final String? setupId;
  final MessageFields fields;
}

final class ProviderRequest extends WorkerMessage {
  ProviderRequest(
    super.generation,
    this.id,
    this.setupId,
    this.operation,
    Map<String, Object?> payload,
  ) : fields = MessageFields(payload);
  final int id;
  final String setupId;
  final ProviderOperation operation;
  final MessageFields fields;
}

/// Replies contain either a result or a sanitized failure, never both.
sealed class OperationReply extends WorkerMessage {
  const OperationReply(super.generation, this.id, this.result, this.failure);
  final int id;
  final Object? result;
  final NoosphereWorkerException? failure;
}

final class WorkerReply extends OperationReply {
  const WorkerReply.success(int generation, int id, Object? result)
    : super(generation, id, result, null);
  const WorkerReply.failure(
    int generation,
    int id,
    NoosphereWorkerException failure,
  ) : super(generation, id, null, failure);
}

final class ProviderReply extends OperationReply {
  const ProviderReply.success(int generation, int id, Object? result)
    : super(generation, id, result, null);
  const ProviderReply.failure(
    int generation,
    int id,
    NoosphereWorkerException failure,
  ) : super(generation, id, null, failure);
}

final class WorkerReady extends WorkerMessage {
  const WorkerReady(super.generation, this.port);
  final SendPort port;
}

final class WorkerStartupFailure extends WorkerMessage {
  const WorkerStartupFailure(super.generation, this.failure);
  final NoosphereWorkerException failure;
}

final class WorkerEventMessage extends WorkerMessage {
  const WorkerEventMessage(super.generation, this.event);
  final NoosphereWorkerEvent event;
}

String _stringKey(Object? key) => key is String
    ? key
    : throw const FormatException('Payload keys must be strings');

/// Host services consumed by worker-owned roles; injectable for lifecycle tests.
abstract interface class WorkerHost {
  Future<Object?> request(
    String setupId,
    ProviderOperation operation,
    Map<String, Object?> payload,
  );
}

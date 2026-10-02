import 'dart:typed_data';

import '../worker_models.dart';
import 'messages.dart';

int approximateMessageBytes(Object? value) => switch (value) {
  WorkerCommand() =>
    96 +
        approximateMessageBytes(value.setupId) +
        approximateMessageBytes(value.fields.values),
  ProviderRequest() =>
    96 +
        approximateMessageBytes(value.setupId) +
        approximateMessageBytes(value.fields.values),
  OperationReply() =>
    80 +
        approximateMessageBytes(value.result) +
        approximateMessageBytes(value.failure?.code) +
        approximateMessageBytes(value.failure?.message),
  WorkerEventMessage() => 64 + approximateMessageBytes(value.event),
  WorkerReady() => 64,
  WorkerStartupFailure() =>
    64 +
        approximateMessageBytes(value.failure.code) +
        approximateMessageBytes(value.failure.message),
  null => 0,
  final String value => value.length * 2,
  final Uint8List value => value.length,
  final List value => value.fold<int>(
    0,
    (sum, item) => sum + approximateMessageBytes(item),
  ),
  final Map value => value.entries.fold<int>(
    0,
    (sum, entry) =>
        sum +
        approximateMessageBytes(entry.key) +
        approximateMessageBytes(entry.value),
  ),
  final WorkerCoordinatorAddress value => _workerDtoBytes(value),
  final WorkerDkgStatus value => _workerDtoBytes(value),
  final WorkerKeyInfo value => _workerDtoBytes(value),
  final WorkerSigningRequest value => _workerDtoBytes(value),
  final WorkerSigningProgress value => _workerDtoBytes(value),
  final NoosphereWorkerSnapshot value => _workerDtoBytes(value),
  final NoosphereWorkerEvent value => _workerDtoBytes(value),
  _ => 8,
};

int _workerDtoBytes(Object value) => switch (value) {
  final WorkerCoordinatorAddress value => _strings([
    value.id,
    ...value.relayUrls,
    ...value.ipAddrs,
  ]),
  final WorkerDkgStatus value =>
    _strings([
          value.name,
          value.description,
          value.creator,
          value.stage,
          ...value.completedParticipants,
        ]) +
        value.proposalBytes.length +
        16,
  final WorkerKeyInfo value => _strings([
    value.groupKeyHex,
    value.name,
    value.description,
  ]),
  final WorkerSigningRequest value =>
    _strings([value.creator, value.status]) +
        value.id.length +
        value.proposalBytes.length +
        _workerDtoBytes(value.progress) +
        8,
  final WorkerSigningProgress value =>
    _strings([value.stage, ...value.contributingParticipants]) + 8,
  final NoosphereWorkerSnapshot value =>
    _strings([value.setupId, ...value.onlineParticipants]) +
        (value.coordinator == null ? 0 : _workerDtoBytes(value.coordinator!)) +
        value.dkgs.fold<int>(0, (sum, item) => sum + _workerDtoBytes(item)) +
        value.signingRequests.fold<int>(
          0,
          (sum, item) => sum + _workerDtoBytes(item),
        ) +
        value.keys.fold<int>(0, (sum, item) => sum + _workerDtoBytes(item)) +
        24,
  final WorkerSnapshotEvent value => _workerDtoBytes(value.snapshot),
  final WorkerParticipantEvent value => _strings([
    value.setupId,
    value.participant,
  ]),
  final WorkerDkgEvent value =>
    _strings([value.setupId, ?value.failure]) + _workerDtoBytes(value.status),
  final WorkerSigningRequestEvent value =>
    _strings([value.setupId]) + _workerDtoBytes(value.request),
  final WorkerSigningResultEvent value =>
    _strings([value.setupId, value.creator]) +
        value.requestId.length +
        value.proposalBytes.length +
        value.signatures.fold<int>(0, (sum, bytes) => sum + bytes.length),
  final WorkerKeyUpdatedEvent value =>
    _strings([value.setupId]) + _workerDtoBytes(value.key),
  final WorkerSessionReplacedEvent value => _strings([value.setupId]),
  final WorkerFailureEvent value => _strings([
    value.setupId,
    value.operation,
    value.message,
  ]),
  _ => throw ArgumentError.value(value, 'value', 'not a worker DTO'),
};

int _strings(Iterable<String> values) =>
    values.fold(0, (sum, value) => sum + value.length * 2);

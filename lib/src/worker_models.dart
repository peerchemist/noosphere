import 'dart:typed_data';

import 'package:noosphere_server/noosphere_server.dart';

/// Roles owned by a worker setup.
enum NoosphereWorkerRoles { server, signer, both }

/// Public, sendable representation of an Iroh coordinator address.
final class WorkerCoordinatorAddress {
  WorkerCoordinatorAddress({
    required this.id,
    required List<String> relayUrls,
    required List<String> ipAddrs,
  }) : relayUrls = List.unmodifiable(relayUrls),
       ipAddrs = List.unmodifiable(ipAddrs);

  final String id;
  final List<String> relayUrls;
  final List<String> ipAddrs;
}

/// Sanitized public view of a DKG proposal or progress update.
final class WorkerDkgStatus {
  WorkerDkgStatus({
    required this.name,
    required this.description,
    required this.threshold,
    required this.expiry,
    required this.creator,
    required this.stage,
    required List<String> completedParticipants,
    required Uint8List proposalBytes,
  }) : completedParticipants = List.unmodifiable(completedParticipants),
       proposalBytes = Uint8List.fromList(proposalBytes);

  final String name;
  final String description;
  final int threshold;
  final DateTime expiry;
  final String creator;

  /// `waiting`, `round1`, or `round2`.
  final String stage;
  final List<String> completedParticipants;

  /// Canonical proposal bytes. Approval APIs echo these bytes so approval is
  /// bound to the proposal that the host reviewed.
  final Uint8List proposalBytes;

  NewDkgDetails decodeProposal() => NewDkgDetails.fromBytes(proposalBytes);
}

/// Public view of a locally available FROST key. It contains no secret share.
final class WorkerKeyInfo {
  const WorkerKeyInfo({
    required this.groupKeyHex,
    required this.name,
    required this.description,
  });

  final String groupKeyHex;
  final String name;
  final String description;
}

/// Sanitized signing proposal used both for display and approval binding.
final class WorkerSigningRequest {
  WorkerSigningRequest({
    required Uint8List id,
    required Uint8List proposalBytes,
    required this.creator,
    required this.expiry,
    required this.status,
  }) : id = Uint8List.fromList(id),
       proposalBytes = Uint8List.fromList(proposalBytes);

  final Uint8List id;
  final Uint8List proposalBytes;
  final String creator;
  final DateTime expiry;

  /// `waiting`, `accepted`, or `rejected`.
  final String status;

  SignaturesRequestDetails decodeProposal() =>
      SignaturesRequestDetails.fromBytes(proposalBytes);
}

/// A point-in-time public view of one setup.
final class NoosphereWorkerSnapshot {
  NoosphereWorkerSnapshot({
    required this.setupId,
    required this.generation,
    required this.serverRunning,
    required this.signerRunning,
    required this.connected,
    required this.coordinator,
    required List<String> onlineParticipants,
    required List<WorkerDkgStatus> dkgs,
    required List<WorkerSigningRequest> signingRequests,
    required List<WorkerKeyInfo> keys,
  }) : onlineParticipants = List.unmodifiable(onlineParticipants),
       dkgs = List.unmodifiable(dkgs),
       signingRequests = List.unmodifiable(signingRequests),
       keys = List.unmodifiable(keys);

  final String setupId;
  final int generation;
  final bool serverRunning;
  final bool signerRunning;
  final bool connected;
  final WorkerCoordinatorAddress? coordinator;
  final List<String> onlineParticipants;
  final List<WorkerDkgStatus> dkgs;
  final List<WorkerSigningRequest> signingRequests;
  final List<WorkerKeyInfo> keys;
}

sealed class NoosphereWorkerEvent {
  const NoosphereWorkerEvent(this.setupId, this.generation);

  final String setupId;
  final int generation;
}

final class WorkerSnapshotEvent extends NoosphereWorkerEvent {
  WorkerSnapshotEvent(this.snapshot)
    : super(snapshot.setupId, snapshot.generation);

  final NoosphereWorkerSnapshot snapshot;
}

final class WorkerParticipantEvent extends NoosphereWorkerEvent {
  const WorkerParticipantEvent(
    super.setupId,
    super.generation, {
    required this.participant,
    required this.online,
  });

  final String participant;
  final bool online;
}

final class WorkerDkgEvent extends NoosphereWorkerEvent {
  const WorkerDkgEvent(
    super.setupId,
    super.generation, {
    required this.status,
    this.rejected = false,
    this.failure,
  });

  final WorkerDkgStatus status;
  final bool rejected;
  final String? failure;
}

final class WorkerSigningRequestEvent extends NoosphereWorkerEvent {
  const WorkerSigningRequestEvent(
    super.setupId,
    super.generation, {
    required this.request,
  });

  final WorkerSigningRequest request;
}

final class WorkerSigningResultEvent extends NoosphereWorkerEvent {
  WorkerSigningResultEvent(
    super.setupId,
    super.generation, {
    required Uint8List requestId,
    required Uint8List proposalBytes,
    required List<Uint8List> signatures,
    required this.creator,
  }) : requestId = Uint8List.fromList(requestId),
       proposalBytes = Uint8List.fromList(proposalBytes),
       signatures = List.unmodifiable(signatures.map(Uint8List.fromList));

  final Uint8List requestId;
  final Uint8List proposalBytes;
  final List<Uint8List> signatures;
  final String creator;
}

final class WorkerKeyUpdatedEvent extends NoosphereWorkerEvent {
  const WorkerKeyUpdatedEvent(
    super.setupId,
    super.generation, {
    required this.key,
  });

  final WorkerKeyInfo key;
}

final class WorkerSessionReplacedEvent extends NoosphereWorkerEvent {
  const WorkerSessionReplacedEvent(super.setupId, super.generation);
}

final class WorkerFailureEvent extends NoosphereWorkerEvent {
  const WorkerFailureEvent(
    super.setupId,
    super.generation, {
    required this.operation,
    required this.message,
    this.interrupted = false,
  });

  final String operation;
  final String message;
  final bool interrupted;
}

/// Exception returned by a worker command. It deliberately contains no remote
/// stack trace or arbitrary native error payload.
final class NoosphereWorkerException implements Exception {
  const NoosphereWorkerException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'NoosphereWorkerException($code): $message';
}

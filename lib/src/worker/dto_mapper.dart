import 'package:iroh_flutter/iroh_flutter.dart' show EndpointAddr;
import 'package:noosphere_client/noosphere_client.dart';

import '../worker_models.dart';

/// Converts domain objects into public, sendable values without owning roles.
final class WorkerDtoMapper {
  WorkerDtoMapper(this.setupId, this.generation, this.emit);
  final String setupId;
  final int generation;
  final void Function(NoosphereWorkerEvent) emit;
  NoosphereWorkerSnapshot snapshot({
    Client? client,
    required bool serverRunning,
    required bool signerRunning,
    required bool connected,
    EndpointAddr? serverAddress,
  }) {
    return NoosphereWorkerSnapshot(
      setupId: setupId,
      generation: generation,
      serverRunning: serverRunning,
      signerRunning: signerRunning,
      connected: connected,
      coordinator: serverAddress == null
          ? null
          : WorkerCoordinatorAddress(
              id: serverAddress.id.toZ32(),
              relayUrls: [for (final url in serverAddress.relayUrls) url.value],
              ipAddrs: serverAddress.ipAddrs,
            ),
      onlineParticipants: client == null
          ? const []
          : [for (final id in client.onlineParticipants) id.toString()],
      dkgs: client == null
          ? const []
          : [
              for (final dkg in client.dkgRequests)
                _dkgStatus(dkg, stage: 'waiting'),
              for (final dkg in client.acceptedDkgs) _dkgStatus(dkg),
            ],
      signingRequests: client == null
          ? const []
          : [
              for (final request in client.signaturesRequests)
                _signing(request),
            ],
      keys: client == null
          ? const []
          : [for (final key in client.keys.values) _key(key)],
    );
  }

  WorkerDkgStatus _dkgStatus(DkgInProgress progress, {String? stage}) =>
      WorkerDkgStatus(
        name: progress.details.name,
        description: progress.details.description,
        threshold: progress.details.threshold,
        expiry: progress.expiry.time,
        creator: progress.creator.toString(),
        stage: stage ?? progress.stage.name,
        completedParticipants: [
          for (final id in progress.completed) id.toString(),
        ],
        proposalBytes: progress.details.toBytes(),
      );

  WorkerSigningRequest _signing(SignaturesRequest request) =>
      WorkerSigningRequest(
        id: request.details.id.toBytes(),
        proposalBytes: request.details.toBytes(),
        creator: request.creator.toString(),
        expiry: request.expiry.time,
        status: request.status.name,
        progress: WorkerSigningProgress(
          threshold: request.progress.threshold,
          contributingParticipants: [
            for (final id in request.progress.contributingParticipants)
              id.toString(),
          ]..sort(),
          stage: request.progress.stage.name,
        ),
      );

  WorkerKeyInfo _key(FrostKeyWithDetails key) => WorkerKeyInfo(
    groupKeyHex: key.groupKey.hex,
    name: key.name,
    description: key.description,
  );

  void event(ClientEvent event, {Client? client}) {
    switch (event) {
      case ParticipantStatusClientEvent():
        emit(
          WorkerParticipantEvent(
            setupId,
            generation,
            participant: event.id.toString(),
            online: event.loggedIn,
          ),
        );
      case UpdatedDkgClientEvent():
        final waitingForLocalApproval =
            client?.dkgRequests.any(
              (dkg) => dkg.details.name == event.progress.details.name,
            ) ==
            true;
        emit(
          WorkerDkgEvent(
            setupId,
            generation,
            status: _dkgStatus(
              event.progress,
              stage: waitingForLocalApproval ? 'waiting' : null,
            ),
          ),
        );
      case RejectedDkgClientEvent():
        emit(
          WorkerDkgEvent(
            setupId,
            generation,
            status: WorkerDkgStatus(
              name: event.details.name,
              description: event.details.description,
              threshold: event.details.threshold,
              expiry: event.details.expiry.time,
              creator: event.participant?.toString() ?? '',
              stage: 'rejected',
              completedParticipants: const [],
              proposalBytes: event.details.toBytes(),
            ),
            rejected: true,
            failure: event.fault.name,
          ),
        );
      case CompletedDkgClientEvent():
        emit(
          WorkerKeyUpdatedEvent(
            setupId,
            generation,
            key: _key(event.keyDetails),
          ),
        );
      case SignaturesRequestClientEvent():
        emit(
          WorkerSigningRequestEvent(
            setupId,
            generation,
            request: _signing(event.request),
          ),
        );
      case SignaturesProgressClientEvent():
        emit(
          WorkerSigningRequestEvent(
            setupId,
            generation,
            request: _signing(event.request),
          ),
        );
      case SignaturesFailureClientEvent():
        emit(
          WorkerFailureEvent(
            setupId,
            generation,
            operation: 'signatures',
            message: 'Signing request failed.',
          ),
        );
      case SignaturesExpiryClientEvent():
        emit(
          WorkerFailureEvent(
            setupId,
            generation,
            operation: 'signatures',
            message: 'Signing request expired.',
          ),
        );
      case SignaturesCompleteClientEvent():
        emit(
          WorkerSigningResultEvent(
            setupId,
            generation,
            requestId: event.details.id.toBytes(),
            proposalBytes: event.details.toBytes(),
            creator: event.creator.toString(),
            signatures: [
              for (final signature in event.signatures) signature.data,
            ],
          ),
        );
      case SecretShareClientEvent():
        emit(
          WorkerKeyUpdatedEvent(
            setupId,
            generation,
            key: _key(event.keyDetails),
          ),
        );
    }
  }
}

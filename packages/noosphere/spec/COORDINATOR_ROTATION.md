# Coordinator switching

`NoosphereWorker.switchCoordinator` switches an existing signer to a coordinator
already approved by the application. It preserves the group, participant
identity, FROST keys, client storage and any embedded server role.

```dart
// The app has verified the user's/group's approval of this endpoint ID.
await worker.switchCoordinator(
  'primary-wallet',
  newCoordinator: approvedAddress,
  persist: (address) => settings.saveCoordinator(address),
);
```

## Library contract

The helper serializes the switch with lifecycle and signing operations for this
setup. It stops the old session, checks client storage for prepared signing
operations or unexpired nonce records, awaits the host's durable `persist`
callback, and then connects with the new pin. It uses existing snapshot and
session-replacement events.
The destination must already serve the same `GroupConfig`; normal authenticated
login checks the group. The old coordinator need not be reachable.

`stop -> check local signing state -> persist -> connect` is a serialized
sequence, not an atomic transaction across host storage and the network.
Success confirms only this signer's connection to the selected coordinator.
The local pending-state check does not inspect other signers, collect their
approval or ensure that enough participants have switched to sign together.

The library owns that ordering, local signing-state checks, authenticated group
checks and failure behavior. The application owns proposal delivery,
approval/signature verification, governance and quorum policy, endpoint
distribution, durable selection storage, UI and recovery. This helper adds no
voting protocol, certificate format, persistence interface or background retry
timer. Do not call it with an endpoint received from an untrusted message before
approving that identity. For address hints under the same pin, use
`updateSignerAddress`.

## Partial failure and recovery

An unresolved signing operation yields `pending_signing_operations` before
`persist` is called. Records are retained and the signer stays stopped for the
host to reconcile. A persistence failure or timeout also leaves it stopped;
a timed-out callback may still commit. Wait for/reconcile that write before
restarting from the selection actually stored by the app. Never blindly start
with the old pin after an ambiguous outcome. The callback must not re-enter
worker lifecycle or signing commands for this setup while the switch waits.

A connection failure after persistence keeps the signer stopped and retains
the new configuration for an explicit retry. There is no automatic fallback
or mutation replay. Retry `switchCoordinator` with the selected address and an
idempotent persistence callback, or start from the app's stored selection using
`clientOptions.withCoordinator(address)`. Subsequent disconnects after a
successful connection use the existing reconnect behavior. On process restart,
load the persisted selection before `startSetup`.

| Failure | Local signer and selection | Host action |
| --- | --- | --- |
| Pending signing operations or unexpired nonce records | Signer stopped; `persist` not called; records retained | Reconcile pending signing state before another switch; use `startSetup` with the stored selection when restarting |
| Persistence error or timeout | Signer stopped; durable selection may already have changed | Wait for/reconcile the write, then restart from the actual stored selection |
| Connection or group check fails after persistence | Signer stopped; new selection persisted and retained for retry | Resolve destination availability/configuration and explicitly retry the selected endpoint |

## Host workflow

1. Obtain and verify approval of the exact destination endpoint ID using the
   application's governance rules. Prepare that coordinator to serve the same
   `GroupConfig`. Arrange server-state transfer separately if the application
   needs it.
2. Distribute the approved endpoint through the application's chosen channel.
   Each signer application verifies its authorization before calling
   `switchCoordinator`; one signer's switch does not authorize the others.
3. Supply a durable, idempotent `persist` callback for this setup's selected
   coordinator. Await the switch and reflect its local state in the UI. The
   application tracks participant progress and signing availability separately.
4. On failure, follow the recovery rules above. After a persistence timeout,
   ensure the outstanding write has settled before loading the selection and
   restarting. On application restart, load that selection before `startSetup`.

The repository's Flutter example uses in-memory stores and does not implement
this durable host workflow. Consuming applications provide their own approval,
storage and recovery integration.

## Scope

Room records and invitations remain bound to their original coordinator
identity; this helper does not migrate them. Moving a server while preserving
its Iroh identity still uses the existing identity-backup/restore workflow.

Membership changes, successor FROST keys and migration of funds are separate
from switching coordinators. [Group transitions](GROUP_TRANSITIONS.md) proposes
a future shared layer for canonical transition data, consent checks, identity
and DKG-result bindings and progress. Those protocol checks should not need
independent implementations in every application. Applications own governance,
concrete storage, transaction construction/submission and external completion
checks. No group-transition orchestration API is implemented by this helper.

`integration_test/coordinator_rotation_test.dart` covers durable-write ordering,
persistence failures, concurrent calls, pending signing state and a real FROST
signature after switching with the old coordinator offline.

# Coordinator switching

`NoosphereWorker.rotateCoordinator` switches an existing signer to a coordinator
already approved by the application. It preserves the group, participant
identity, FROST keys, client storage and any embedded server role.

```dart
// The app has verified the user's/group's approval of this endpoint ID.
await worker.rotateCoordinator(
  'primary-wallet',
  newCoordinator: approvedAddress,
  persist: (address) => settings.saveCoordinator(address),
);
```

The helper serializes the switch with other signer operations. It stops the
old session, checks client storage for prepared signing operations or unexpired
nonce records, awaits the host's durable `persist` callback, and then connects
with the new pin. It uses existing snapshot and session-replacement events.
The destination must already serve the same `GroupConfig`; normal authenticated
login checks the group. The old coordinator need not be reachable.

The application owns proposal delivery, approval/signature verification and
its selection storage. This helper adds no voting protocol, quorum policy,
certificate format, persistence interface or background retry timer. Do not
call it with an endpoint received from an untrusted message before approving
that identity. For address hints under the same pin, use `updateSignerAddress`.

An unresolved signing operation yields `pending_signing_operations` before
`persist` is called. Records are retained and the signer stays stopped for the
host to reconcile. A persistence failure or timeout also leaves it stopped;
a timed-out callback may still commit. Wait for/reconcile that write before
restarting from the selection actually stored by the app. Never blindly start
with the old pin after an ambiguous outcome. The callback must not re-enter
worker lifecycle or signing commands for this setup while the switch waits.

A connection failure after persistence keeps the signer stopped and retains
the new configuration for an explicit retry. There is no automatic fallback
or mutation replay. Retry `rotateCoordinator` with the selected address and an
idempotent persistence callback, or start from the app's stored selection using
`clientOptions.withCoordinator(address)`. Subsequent disconnects after a
successful connection use the existing reconnect behavior. On process restart,
load the persisted selection before `startSetup`.

Room records and invitations remain bound to their original coordinator
identity; this helper does not migrate them. Moving a server while preserving
its Iroh identity still uses the existing identity-backup/restore workflow.

`integration_test/coordinator_rotation_test.dart` covers durable-write ordering,
persistence failures, concurrent calls, pending signing state and a real FROST
signature after switching with the old coordinator offline.

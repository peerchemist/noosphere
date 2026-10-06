# State and persistence

[Architecture overview](../architecture.md)

Noosphere owns protocol state machines; the host owns durable storage and
application state. The library defines transaction ordering but does not choose
a database, encrypt wallet data or provide a durable UI event log.

## Ownership

| State | Library | Host |
| --- | --- | --- |
| Sessions, sockets, timers | Validate and expire | Restart runtime |
| DKG temporary secrets | Keep in memory | Treat interruption as a new attempt |
| FROST keys and recovery state | Define safe updates | Encrypt, namespace and persist |
| Signing nonces/prepared operations | Enforce ordering | Commit atomically and reconcile ambiguity |
| Coordinator attempts/results | Serialize and recover safely | Atomic store per group ID |
| Rooms/invitations | Validate transitions | Atomic records and cross-process ordering |
| Application history/effects | Expose proposals/results | Consent, policy, transactions and deduplication |

In-memory providers are test utilities, not production durability.

## Client storage

`ClientStorageInterface.loadState()` must return keys, nonces, prepared
operations and rejections from one consistent snapshot. The provider is already
bound to a participant/setup namespace; methods do not repeat a group ID.

FROST nonce replacement and the corresponding outgoing operation must be one
atomic `prepareSignaturesOperation` transaction:

```text
build payload and next nonces
  -> atomically store prepared operation + replace nonce indexes
  -> send RPC
  -> mark operation complete
```

If preparation fails, the client assumes the write may have committed and does
not send. If the RPC or completion write is ambiguous, the durable marker
blocks blind retry and nonce reuse. Reconnecting does not replay it
automatically. Final verified signatures are exposed only after durable request
cleanup; the application stores their business meaning separately.

## Coordinator and room storage

`ServerPersistence` atomically loads/writes an opaque `ServerStateSnapshot` by
group ID. Startup converts active DKG/signing attempts into safe interrupted or
blocked records and persists that conversion before readiness. A write with an
unknown outcome latches the handler closed until storage is reloaded.

`RoomPersistence` atomically stores room records. Invite consumption and
participant insertion are one write. Room write failure similarly blocks
mutations until reopen/reload.

Server identity storage belongs to the host. Flutter can derive the same
32-byte Iroh secret from a BIP-39 seed, but does not persist it.

## Worker ordering and timeouts

Worker storage/key providers remain on the host isolate. Calls pass through
FIFO queues keyed by provider instance, so replacement setups wait behind old
operations using the same provider. Separate instances or processes still need
database-level coordination.

A host-operation timeout does not cancel the underlying write. It may commit
later, so a replacement must wait or reconcile before trusting a new load.

## Recovery summary

| Interrupted record | Recovery |
| --- | --- |
| Session/challenge/connection | Discard and authenticate again |
| Client DKG temporary secret | Start a fresh attempt |
| Coordinator DKG | Restore as interrupted; creator may replace it |
| Coordinator signing request | Block ID until expiry; do not resume rounds |
| Completed signatures | Restore and redeliver until expiry |
| Encrypted recovery shares | Restore for recipient delivery |
| Client prepared signing operation | Block pending reconciliation |
| Durable rejection | Re-send when proposal reappears |
| Used/revoked invite and frozen room | Preserve |
| DKG ACK cache | Rebuild from participant key records |

Completion can be redelivered, so application side effects must be idempotent.
Use durable records and external outcomes—not a missing event or discarded
runtime—to decide whether work can resume.

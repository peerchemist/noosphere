# State and persistence

[Architecture overview](README.md)

Noosphere owns protocol state machines; the host owns durable storage and
application state. The library defines transaction ordering but does not choose
a database, encrypt wallet data or provide a durable UI event log.

## Ownership

| State | Library | Host |
| --- | --- | --- |
| Sessions, sockets, timers | Validate and expire | Restart runtime |
| DKG temporary secrets | Expose opaque export/import and validate resume context | Export after transitions, encrypt, persist and delete |
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

`FrostKeyWithDetails` uses one explicit versioned format containing mandatory
ceremony ID and transcript hash plus the complete bytes of every contextual
signed ACK. The decoder defines only this grammar; any other bytes are simply
malformed input with no protocol meaning.

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

Creator cancellation uses `cancelSignaturesRequest(requestId)` on the client
and `cancelSignaturesRequest(setupId, requestId)` on the worker. Only a confirmed
coordinator response, event, or authoritative snapshot establishes cancellation.
A timeout is an unknown outcome; reconnect and reconcile, or retry safely.

Providers implement atomic `cancelSignaturesRequest(requestId, expiresAt)`:
insert only the request ID and its original expiry, and remove every nonce,
prepared operation, request record and local decision in the same transaction.
Unexpired tombstones block subsequent signing writes. `loadState()` includes
them; load and session maintenance invoke `pruneCancelledSignaturesRequests()`.
An uncertain cancellation write blocks signing until storage is reloaded.

## Coordinator and room storage

`ServerPersistence` atomically loads/writes an opaque `ServerStateSnapshot` by
group ID. The snapshot grammar is version 3 and restores active DKG commitments, the frozen
transcript, recipient-encrypted round-two mailboxes, completion
acknowledgements and DKG terminal records. Any input that does not form a
current snapshot is reported as malformed. Signing attempts remain blocked
after restart. A write with an unknown outcome latches the handler closed until
storage is reloaded.

Noosphere does not select or operate a database. The calling application owns
the `ServerPersistence` implementation and decides how snapshots are encrypted,
committed and retained. The coordinator snapshot never contains participant
intermediate DKG secrets.

## Resumable DKG boundary

The coordinator can resume a DKG across disconnects and coordinator process
restarts. It retains an immutable commitment transcript and caller-scoped
encrypted-share mailboxes until every participant acknowledges the same
transcript and group key or the signed deadline expires. Fetching a ceremony is
authoritative; live events are only progress notifications and may be replayed.

Participant process restart additionally requires the host to restore the
round-one or round-two private secret and the exact pending payload. Noosphere
does not persist those bytes. Frosty generates and serializes the cryptographic
round secrets; Noosphere wraps them with enough ceremony and exact outgoing
payload data to resume safely.

For crash-safe operation, the calling application supplies
`persistDkgSecret`. Noosphere awaits this durability callback after preparing
round-one or round-two state and before submitting the corresponding message.
A callback failure prevents submission. The application chooses the storage
format and location, atomically replaces the previous blob, and protects it as
private key material. `exportDkgSecret` remains available for explicit export,
but Noosphere never places these blobs in `ClientStorageInterface` or another
Noosphere storage snapshot.

After restart, login restores only the coordinator's public ceremony state. It
does not load the participant secret. The application reads its own storage and
passes the matching blob to `importDkgSecret`; Noosphere validates it against
the current ceremony and reconciles or retries the exact contribution. Without
an import, explicit refresh reports `MissingDkgSecret`, while login and
rejection remain available; the client never substitutes fresh randomness. The
application deletes its blob after completion, rejection, or expiry. A
complete worker-level example is
[`worker_dkg_dropout_test.dart`](../../apps/integration_host/integration_test/worker_dkg_dropout_test.dart).

Rejected or expired ceremonies leave terminal records keyed by ceremony ID.
Those records are retained for `maxDkgRequestTTL` from terminalization and are
written through the same caller-provided `ServerPersistence`; replaying the
same signed proposal cannot revive it during that bound. A replacement requires
a new attempt ID and may reuse only the display name.

## Protocol v3 source breaks

Only the protocol v3 grammar is defined. DKG events have mandatory ceremony
IDs, authenticated DKG fetch/mutation APIs require a ceremony ID, ACK requests
require ceremony and transcript context, Frost-key storage uses the current
versioned encoding, and coordinator persistence uses snapshot version 3. Other
bytes have no defined meaning and fail ordinary parsing or validation.

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
| Client DKG temporary secret | Fail explicitly if its published contribution exists; never regenerate it |
| Coordinator DKG (snapshot v3) | Restore its exact stage, accepted payloads and completion acknowledgements |
| Coordinator signing request | Block ID until expiry; do not resume rounds |
| Completed signatures | Restore and redeliver until expiry |
| Cancelled signing request | Retain only ID and original expiry; reconcile all clients through snapshots |
| Encrypted recovery shares | Restore for recipient delivery |
| Client prepared signing operation | Block pending reconciliation |
| Durable rejection | Re-send when proposal reappears |
| Used/revoked invite and frozen room | Preserve |
| DKG terminal record | Retain through caller persistence for `maxDkgRequestTTL` after rejection/expiry |
| DKG ACK cache | Ephemeral; contextual possession ACKs repopulate it from participant key records |

Completion can be redelivered, so application side effects must be idempotent.
Use durable records and external outcomes—not a missing event or discarded
runtime—to decide whether work can resume.

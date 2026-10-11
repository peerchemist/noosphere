# Public event feed and Sygnature integration

The public feed is an optional, unauthenticated notification/transparency API.
It reports coordinator observations of DKG and signing attempts. It cannot sign,
approve, reject, open a participant session, or affect participant presence.
Applications must still use the authenticated signer API for all participant
actions. The polling client does not import the signer client, load FROST, open
signer storage, or request a participant private key.

## Enable one feed per group

Feeds are disabled by default. Generate an opaque 256-bit ID once, persist it in
the host's server configuration, and opt in explicitly:

```dart
import 'package:noosphere_server/noosphere_server.dart';

final feedId = PublicFeedId.generate(); // Once, using the system CSPRNG.
// Save feedId.hex in your coordinator configuration before starting it.
final config = ServerConfig(
  group: group,
  publicFeed: PublicFeedConfig(
    feedId: feedId,
    maxEntries: 10000,
    maxAge: const Duration(days: 30),
  ),
);
```

The CLI accepts the equivalent `server.public-feed` block shown in
[`iroh-server.example.yaml`](../packages/noosphere_server/config/iroh-server.example.yaml).
Each configured group has its own `ServerConfig.publicFeed`. Frozen enrollment
room groups opt in separately through `IrohConfig.roomPublicFeeds`, keyed by
their group IDs. They do not inherit the primary group's feed. Duplicate feed
IDs on one dispatcher are rejected. Configuration group IDs are private and
are never public request routing parameters.

The ID is also stored in the existing atomic coordinator snapshot, together
with the journal and cursor. Startup rejects a different ID for that persisted
coordinator. Disabling and re-enabling the same feed preserves its cursor and
retained history. Operations accepted while disabled are not backfilled.

Treat an unlisted feed ID as a capability to discover metadata: anyone who
learns it can read the feed. There is no feed listing or discovery operation.
Applications may instead deliberately publish an ID for transparency. Both
uses have exactly the same protocol; publication and distribution are host
application choices, not coordinator endpoints.

## Metadata and privacy

Every entry contains only a monotonically increasing cursor, a random 256-bit
event ID, category (`dkg` or `signing`), lifecycle state, coordinator observation
time, and operation expiry time. Times are UTC milliseconds since the epoch.
Event IDs are random per accepted attempt, scoped to its feed, and remain stable
from `requested` to its terminal entry. They have no derivation from names,
participant identities, fingerprints, or protocol request IDs. A newly accepted
attempt receives a fresh ID even when a participant reuses a DKG name.

Version 1 emits `requested` and terminal `completed`, `rejected`, `cancelled`, or
`expired` entries. `progress` is reserved by the domain vocabulary; version 1
does not publish intermediate counts or individual votes. A signing operation
is `rejected` when rejection prevents its threshold from being reached; a
partial participant rejection is not a terminal operation. Other unrecoverable
signing failures are `cancelled`. Completion of DKG means the coordinator has
received all round-two submissions, not that it possesses or independently
verified participants' resulting keys.

No request details, proposals, transaction data, amounts, derivation paths,
messages, participant data, key material, commitments, nonces, shares, ROAST
signatures, group identifiers, or network address hints are serialized in the
public page. The outer envelope contains only the page and its coordinator
Ed25519 signature. Hosts should still consider the privacy cost: polling reveals
the existence, type, timing, frequency, and outcome of operations. An unlisted
ID does not make that metadata encrypted from readers who know the ID.

## Sygnature polling

Use the pure Dart client entry point independently of `Client`,
`ClientNodeOptions`, and the Flutter signer worker:

```dart
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_client/public_feed.dart';

final client = await PublicFeedClient.connect(
  coordinatorAddress, // EndpointAddr, from trusted application configuration.
  pinnedCoordinatorId, // EndpointId, pinned independently of address hints.
);
try {
  final page = await client.fetch(
    PublicFeedId(savedFeedIdHex),
    afterCursor: savedCursor, // Initially zero.
    limit: 100,
  );
  // If page.historyGap, record that retained history cannot cover this run.
  // Handle entries idempotently, then durably save page.nextCursor.
  // Continue with that cursor while page.hasMore, within the worker's budget.
} finally {
  await client.close();
}
```

Sygnature should persist the coordinator address, pinned EndpointId, feed ID,
and last processed cursor in its notification settings/database. Scope the
cursor by both EndpointId and feed ID. Save the cursor only after processing
the page, preferably in the same local transaction as notification bookkeeping.
Deduplicate delivery by `(feedId, cursor)` and correlate lifecycle updates by
event ID. A repeated poll returns the same entries, so crashes between showing
a notification and committing its cursor require application-level deduplication.
Choose a bounded number of pages per background run and resume next time.

Every connection creates a new ephemeral client Iroh endpoint. No persistent
client identity, signer configuration, participant callback, or storage object
is needed. The caller supplies/bundles the Iroh native library as usual (the
optional `nativeLibraryPath` argument supports pure Dart deployments). This
API does not require coinlib/FROST initialization. `relay`, `connectTimeout`,
and `rpcTimeout` can be supplied for the deployment. Close the client at the
end of each polling run; failed polling closes its connection as well.

## Cursor, retention, and recovery

`afterCursor` is exclusive. Entries are returned in increasing cursor order.
The server clamps the requested limit to 1–100, bounds the request body to
256 bytes, and bounds the signed response to 64 KiB or the host's smaller
transport message limit. A host limit too small for the requested page returns
a generic resource-exhausted error. Connections, concurrent streams, and read
and write deadlines use the existing Iroh resource limits.

`latestCursor` is the last allocated cursor, including entries no longer
retained. `oldestAvailableCursor` is the first retained cursor, or
`latestCursor + 1` when history is empty. `historyGap` is true exactly when
`afterCursor < oldestAvailableCursor - 1`. A fresh cursor zero therefore also
reports a gap if older entries were pruned. `nextCursor` is the last returned
cursor; for an empty page it is the greater of `afterCursor` and `latestCursor`.
This advances past entirely pruned history without an endless polling loop.
`hasMore` means `nextCursor < latestCursor`. Empty pages are valid. If a server
reports a latest cursor below a previously stored cursor, applications should
report coordinator rollback/configuration mismatch rather than reset silently.

Retention removes the oldest prefix by maximum entries (default 10,000,
configurable from 1 to 100,000) and age (default 30 days), whichever removes
more. Pruning never decreases or reuses the next cursor. Cursor exhaustion
fails closed rather than wrapping. Public reads filter age-expired history
without changing state; coordinator maintenance durably prunes it. Private
active-attempt bookkeeping follows live protocol attempts, separately from the
bounded retained history, so a terminal entry can retain the same event ID even
after its requested entry has been pruned.

Creation and terminal records are written in the same `ServerPersistence.write`
snapshot as the corresponding protocol transition. Only the committed journal
is readable. An uncertain write makes the handler refuse public responses until
it is recreated. Retries that do not cause a new protocol transition do not add
entries; replay cannot reopen an already completed signing request still held
in coordinator storage. Recovery cancels active DKG and signing attempts that
the existing protocol cannot resume (signing requests remain privately blocked
until expiry). Those cancellations are committed once before accepting requests.
Already expired attempts receive `expired` instead. Later restarts add no repeat
terminal entries. Polling does not perform recovery or expiry transitions.
Public reads use the immutable committed view directly and do not queue work
in the participant mutation lane, including while host persistence is pending.

`IrohDispatcher` schedules serialized maintenance once per second for enabled
feeds. Hosts using `ServerApiHandler` directly must schedule
`maintainPublicFeed()` in the same serial lane as other handler calls. This
publishes expiry independently of signer traffic and public polling.

## Identity and redistribution

The connection verifies that the address ID and authenticated remote EndpointId
both match the independent pin. The established Iroh binding's `SecretKey.sign`
and `PublicKey.verify` expose standard Ed25519 application signatures, so no
new signing key or key-binding protocol is introduced.

The signature covers
`UTF8("noosphere/public-feed/checkpoint/v1\0") || canonicalPublicFeedPageBytes`.
The literal `\0` denotes one zero byte. Canonical v1 protobuf encodes known
fields once in ascending tag order, preserves repeated entry order, omits
default-valued nonoptional scalars, and preserves optional expiry presence.
It contains no maps or unknown fields and uses minimal protobuf varints. It
covers the schema version, feed ID, every entry byte, oldest/latest cursors,
pagination and requested cursor, and generation time. The client rejects a
noncanonical or unsupported page after signature verification.
The outer envelope must also be canonical and contain only its page and signature.

`fetchCheckpoint(...)` returns a verified `PublicFeedCheckpoint`; `toBytes()`
preserves its signed envelope for caching/redistribution. Offline consumers
initialize Iroh and call `PublicFeedCheckpoint.verify(bytes, trustedEndpointId)`.
They must obtain the pin from a trusted source, not from the cache itself.
Verification authenticates the coordinator's statement, not its truth,
completeness, freshness, or global append-only behavior. Consumers must apply
their own timestamp/freshness policy. Checkpoints are not a Merkle log or proof
that a coordinator has never equivocated. The coordinator identity key must
remain durable and protected by the host.

## Compatibility

This change targets the code at `38f1f9`; the workspace's following commit only
changes `.gitignore`. Public protobuf messages and error code `NOT_FOUND` are
additive. The new `noosphere/public-feed/1` ALPN has one operation, ID 1,
`getPublicFeed`; its IDs are independent of the existing signer ALPN. Existing
authenticated wire messages, operation IDs, and login flow are unchanged.
Both RPC directions use the existing QUIC-varint operation/status prefix and
FIN-delimited protobuf framing. Disabled and unknown valid feed IDs have the
same `NOT_FOUND` response and disclose no group information.

Snapshot version 1 gains optional `publicFeed` data. Existing snapshots without
it load as disabled/empty unless configuration explicitly opts in. Enabled
`ServerConfig` serialization gains a trailing versioned extension, including
the feed ID and retention policy, so it also crosses the existing Flutter
worker configuration boundary. Disabled configuration retains its original
bytes. New readers accept the original bytes. Frozen room feed configuration
must be supplied again by the host on startup.

Do not downgrade an enabled coordinator to a binary that discards public-feed
snapshot fields or restore an older backup over a live journal: either can
lose cursor history. Atomic persistence protects normal transitions and crash
recovery, not deliberate host rollback. Preserve coordinator identity,
configuration, and the complete atomic snapshot together.

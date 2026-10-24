# Coordinator server

[Architecture overview](README.md)

The coordinator combines an Iroh endpoint, connection adapter, per-group
dispatcher, `ServerApiHandler` and host persistence. It routes and verifies
contributions without holding participant private shares.

## Routing and concurrency

Handlers are selected by `GroupConfig.fingerprint`; persistence is keyed by
group ID, which must be unique in the host namespace. Authentication binds a
connection to one group and participant. Rooms add more handlers to the same
endpoint.

`IrohDispatcher` gives each group one FIFO mutation lane. Different groups run
independently. Persistence completes inside the lane; socket writes happen
after release so slow receivers do not block domain state. Direct callers that
bypass the dispatcher must serialize handler calls themselves.

`LocalCoordinatorApi` uses this same lane for a co-located participant while
bypassing CBOR and QUIC. It retains ordinary login, session and event
semantics, so local and remote participants observe the same state ordering.

## Sessions

Login verifies protocol version, group, roster member and a signed challenge.
`StartSession` replaces that participant's previous session and returns a
snapshot containing current DKG/signing work, completed results and recovery
shares. Session IDs must remain bound to their authenticated connection.

Sessions and challenges are ephemeral. Optional keepalives are disabled by
default. Logging out removes the session; reachability is not a DKG mutation or
a durable rejection vote.

## DKG and ROAST

For DKG, the server validates protocol version and group fingerprint on signed
proposals, enforces unique active names, collects the full roster's
commitments, and routes encrypted round-two shares to their recipients. Every
authenticated fetch or mutation targets both name and mandatory ceremony ID.
Commitment, rejection and round-two events also carry that ID, so delayed
traffic cannot mutate a replacement sharing the display name.

Each encrypted share is a recipient-specific signed envelope binding the
protocol version, ceremony ID, transcript, sender, recipient and ciphertext.
The coordinator and recipient both verify it, so a ciphertext replayed into
another context fails closed.

Completion ACKs are accepted only against a retained ceremony with a complete
round-two transcript and a contribution from that signer. The same contextual
signed value is a long-lived key-possession statement once the ceremony has
been removed; it can repopulate the ephemeral ACK cache after expiry,
rejection, restart or cache eviction. ACK batches are fully validated before
any member is applied, and completion changes are persisted before events are
published. Negative possession responses are valid even while the ceremony is
retained; they do not create, revoke, or replace completion acknowledgements.

For signing, it validates the signed request, exact group keys, initial
commitments and expiry. Per-signature state tracks queued commitments, active
rounds, verified shares, rejectors and malicious contributors. New commitment
sets start rounds at the required threshold; older rounds may remain active
while later commitments arrive.

Every share is verified against its exact transcript and derived public share.
When all requested signatures complete, the server persists the result before
returning it to the final submitter and emitting completion events. If too few
eligible participants remain for an unfinished threshold, it persists and
emits failure.

## Persistence and delivery

Participant DKG secrets and ROAST rounds are not coordinator state. Version 4
coordinator snapshots restore active DKG commitments, encrypted round-two
mailboxes and completion acknowledgements only after rechecking roster
membership, signatures, transcript hashes, recipient sets, stage invariants and
resource bounds. Active signing requests become blocked records. Rejected and
expired DKG ceremony IDs remain terminal for the configured maximum DKG request
TTL. Completed signatures and encrypted recovery shares remain available for
redelivery. A write with unknown outcome blocks further mutations until the
handler reloads storage. Snapshot or public-feed capture failures after a live
mutation also latch the handler closed, even before a host write starts. The
committed snapshot remains unchanged, public-feed reads become unavailable, and
transport sessions can still close. Recreate the handler from durable storage
to resume operations.

The server caps rosters at 64 members, active ceremonies at 32, encrypted
shares at 4 KiB, retained DKG payload at 16 MiB, serialized coordinator state
at 64 MiB and DKG creation at eight requests per participant per minute.

Signing admission caps each group at 32 active requests and 128 total retained
requests, including completed results, blocked requests, cancellations and
terminal records. Cancellation therefore does not immediately free retained
capacity. A request may contain at most 16 signatures and 16 KiB of signed
details, aggregate keys and initial commitments combined. Each participant may
create eight requests per rolling minute. Expiry frees retained capacity through
the normal durable maintenance path.

Recovery is bounded separately: at most 32 key mailboxes, 256 bytes per encrypted
share and 4 MiB of canonical recovery payload per group. The payload budget
counts group keys, recipient identifiers and encoded pending-share/completion
events; it is not the JSON snapshot's byte size. A participant may submit at
most 32 state-changing recovery batches/acknowledgements per rolling minute.
Identical already-stored shares are no-ops and do not spend that rate budget.
All admission checks precede the corresponding state mutation.

A new recovery mailbox requires positive possession ACKs from every roster
member, matching the same key, ceremony and transcript. The client resubmits its
stored ACKs before sharing because the coordinator's ACK cache is ephemeral.
A construction acknowledgement is accepted only for an existing recipient
mailbox; it cannot allocate a new key record. Pending ciphertexts remain until
that recipient acknowledges reconstruction, then become a small signed completion
record. Mailboxes and completion records are retained without automatic expiry
within the count/byte limits; a full store rejects new allocations instead of
evicting another recipient's recovery data. Thus admission can require capacity
planning for long-lived coordinators.

Signing/recovery count and payload bounds are also checked on snapshot restore;
over-limit snapshots fail validation. Rate windows are process-local, while
retained-capacity limits survive restart. These bounds limit resource growth;
they do not promise fair scheduling against a continuously abusive roster member.

Each session has a 100-event pause buffer. It drops older transient entries
when full and provides neither durable replay nor exactly-once delivery.
Persisted completions are separate. Endpoint limits supplement, but do not
replace, host rate limits and operational controls.

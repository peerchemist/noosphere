# Coordinator server

[Architecture overview](../architecture.md)

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
bypassing protobuf and QUIC. It retains ordinary login, session and event
semantics, so local and remote participants observe the same state ordering.

## Sessions

Login verifies protocol version, group, roster member and a signed challenge.
`StartSession` replaces that participant's previous session and returns a
snapshot containing current DKG/signing work, completed results and recovery
shares. Session IDs must remain bound to their authenticated connection.

Sessions and challenges are ephemeral. Optional keepalives are disabled by
default. Logging out removes the session and updates in-memory DKG/signing
state; reachability is not a durable rejection vote.

## DKG and ROAST

For DKG, the server validates signed proposals, enforces unique active names,
collects the full roster's commitments, and routes encrypted round-two shares
to their recipients. It caches signed ACKs and requests missing ones, but can
rebuild that cache from participant records after restart.

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

Live DKG secrets and ROAST rounds are not restartable. Restore converts active
DKGs to interrupted records and active signing requests to blocked records
before accepting traffic. Completed signatures and encrypted recovery shares
remain available for redelivery. A write with unknown outcome blocks further
mutations until the handler reloads storage.

Each session has a 100-event pause buffer. It drops older transient entries
when full and provides neither durable replay nor exactly-once delivery.
Persisted completions are separate. Endpoint limits supplement, but do not
replace, host rate limits and operational controls.

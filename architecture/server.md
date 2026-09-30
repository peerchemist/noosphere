# Coordinator server

[Architecture overview](../architecture.md)

The coordinator is composed of a transport endpoint, connection/session adapter,
per-group dispatcher, domain `ServerApiHandler`, and host persistence. It routes
and verifies cryptographic contributions without holding participant private
shares.

## Startup and group routing

[`IrohServer`](../packages/noosphere_server/lib/src/iroh/server.dart) binds the
host identity, creates or accepts a handler for the configured base group and
awaits its storage restoration. With rooms enabled, it verifies that the room
manager belongs to the same endpoint identity and registers handlers for all
restored frozen rooms.

Handlers are routed by `GroupConfig.fingerprint`; their storage records are
keyed by `GroupConfig.id`. Hosts must keep group IDs unique within their storage
namespace. A connection binds to one group during authentication and cannot
switch groups by placing a different fingerprint in a later operation.

`serve` accepts connections and selects the ROAST or enrollment handler by
ALPN. Creating, inviting, freezing and closing rooms are management methods on
the local server API. They are not unauthenticated management RPCs in the
public enrollment protocol.

## Serialized domain mutations

[`ServerApiHandler`](../packages/noosphere_server/lib/src/server/api_handler.dart)
implements `ApiRequestInterface`. Its methods are intended to be called
sequentially. [`IrohDispatcher`](../packages/noosphere_server/lib/src/iroh/dispatcher.dart)
provides one FIFO lane for each group so network RPCs from different connections
can safely share a handler. Different groups have independent lanes.

Within a lane, code validates bindings and invokes domain methods, including
their awaited persistence. The lane releases before writing the RPC result to
the socket. This prevents a slow network writer from blocking unrelated domain
work in the same group. A provider's slow durable write does delay that group's
mutations, because later transitions must observe a consistent stored history.

The queue rejects reentrant dispatch into itself using zone state, propagates
individual failures without poisoning its tail, and stops accepting work when
closed. Direct callers bypassing the dispatcher must respect the handler's
sequential-call contract.

## Session state

`ServerRuntimeState` holds expiring challenges, session-ID mappings and
participant-to-session mappings. Login verifies the protocol version, roster
fingerprint and participant ID, then generates a challenge. Verification uses
the participant public key in `GroupConfig`.

Starting a session ends the prior one for that participant, announces presence,
creates a new `SessionID` and returns a snapshot. Snapshot contents include
round-one DKGs, outstanding signing requests, rounds awaiting that participant,
completed signatures and encrypted recovery shares. Optional keepalive timers
publish `KeepaliveEvent`; the default configuration does not enable them.

Session loss removes presence and resets DKGs as required. Presence is an
ephemeral coordinator observation, not proof of key custody or membership
consent. Session expiration is processed as the handler prepares operations;
expiring maps are not a universal background scheduler.

## DKG coordination

[`api_dkg.dart`](../packages/noosphere_server/lib/src/server/api_dkg.dart)
validates the requesting session, threshold, TTL and creator signature. It
stores a `DkgState` containing signed details, creator and initial commitment,
persists the snapshot, then publishes the proposal to others.

`DkgRound1State` collects one commitment per participant. Once all roster
members contribute, the server constructs the expected combined hash and
changes to `DkgRound2State`. Round-two requests must sign that hash and contain
encrypted shares for other participants. Duplicate round-two submissions are
rejected.

The server tracks which participants supplied round two, persists that progress
marker and forwards recipient-specific events. After the last submission it
removes the DKG from active coordination. It does not compute or retain the
new participant private key information; clients generate the final key data.

Signed DKG ACKs are verified and cached by group public key. Positive ACKs can
replace negative ones; duplicate announcements need not be rebroadcast.
Requests for missing ACKs use the cache and ask other participants for missing
entries. This cache is rebuilt after restart from participant stores.

## ROAST coordination

[`api_signing.dart`](../packages/noosphere_server/lib/src/server/api_signing.dart)
accepts signed details, aggregate key information and one initial commitment
per requested signature. It validates the exact set of required group keys,
commitment count, expiry, creator signature and active/blocked request IDs.

`SignaturesCoordinationState` stores the request, creator, per-signature states,
rejectors and participants found to send invalid contributions. Each
`SingleSignatureInProgressState` has its aggregate key, next commitments and
participant-to-round mappings. A `SignatureRoundState` holds a commitment set
and collected signature shares.

The coordinator derives `SignaturesProgress` from this state and publishes it
with the initial request, after each valid reply, and immediately before a
terminal completion or failure. In `collecting`, contributors are participants
with queued commitments. In `signing`, they are participants with verified
shares in the most advanced active round. For a multi-signature request, the
highest-threshold unfinished signature is the representative progress item.

For each submitted reply, the server checks the index, duplicates, expected
commitment/share phase, and whether a next commitment is already pending.
When a participant owes a share, `verifySignatureShare` checks it using the
exact round, signing digest and derived public share. Invalid contributions
mark that participant malicious for this request.

When next commitments reach the key threshold, the coordinator forms a round,
records it for its selected participants and clears that next-commitment set.
Replies always include new commitments, allowing further rounds as contributions
arrive. Older rounds and newly collected commitments can coexist; there is no
single global round counter for the entire batch.

When a round has the threshold number of valid shares, `SignatureAggregation`
produces that signature. Once every signature in the batch is finished, the
server durably stores the completed result, removes the active request, returns
the result to the submitting participant and sends completion events to others.
Completion retention is at least `minCompletedSignaturesTTL` (one day by default).

If the roster size minus rejectors and malicious participants falls below the
largest threshold still needed, the request fails and a failure event is sent
after persistence. Reachability alone is not a persisted rejection vote.

## Persistent representation and recovery

[`ServerState`](../packages/noosphere_server/lib/src/server/state/state.dart)
separates runtime collections from protocol state represented in snapshots.
The snapshot includes attempt markers, completed signatures and encrypted
recovery shares. It does not serialize enough live ROAST or DKG secrets/rounds
to restart those exact active computations.

Restore converts active DKGs to interrupted records and active signing requests
to blocked records, then writes the conversion before readiness. A DKG creator
can explicitly replace its own interrupted attempt; other creators cannot
claim the name before expiry. Blocked signing request IDs remain unavailable
until expiry. Completed signatures and recovery shares are restored for
redelivery. See [state and persistence](state-and-persistence.md) for write
failure handling and host transaction obligations.

## Recovery shares and publication limits

[`api_key_sharing.dart`](../packages/noosphere_server/lib/src/server/api_key_sharing.dart)
stores encrypted shares by group key, receiver and sender. It rejects invalid
recipient maps and avoids adding duplicate shares from the same sender. A
signed constructed-key claim changes that recipient's record to completed and
is announced to other participants. The claim is authenticated but does not
prove the recipient actually reconstructed the key.

Each `ClientSession` has an event controller and a 100-entry ring buffer used
when its stream is paused. The buffer keeps only recent entries when full.
This is bounded temporary buffering, not durable replay or exactly-once
delivery. Completed results have separate persistence; ordinary transient
events do not all become durable history.

The endpoint's connection/stream limits supplement the domain handler. They
do not make every public handler method a rate-limited service or remove the
host's responsibility for operational controls.

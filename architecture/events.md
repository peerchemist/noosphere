# Events

[Architecture overview](../architecture.md)

An `Event` is a typed coordinator-to-participant input. It can announce a
proposal, deliver another participant's contribution, start a signing round or
report a result. Processing may validate data, update state, write storage,
send an RPC and notify the host.

```text
coordinator state transition
  -> domain Event
  -> protobuf EventMessage
  -> length-prefixed Iroh session record
  -> decoded Event
  -> client validation/state transition
  -> optional ClientEvent
  -> optional NoosphereWorkerEvent
```

These are distinct APIs. Network `Event`s drive the protocol; `ClientEvent`s
and worker events report selected local outcomes. None is a durable application
log.

## Meaning and routing

`Event` is a sealed family, not an arbitrary payload envelope. Each variant
defines its own correlation fields and checks. Receiving a well-formed event is
not approval: the client still verifies signatures, expiry, group/key binding,
replay state and application consent.

| Direction | Purpose |
| --- | --- |
| Participant RPC | Ask the coordinator to mutate or query protocol state |
| RPC response | Reply on the same bidirectional QUIC stream |
| Domain `Event` | Deliver independent protocol work to participant sessions |
| `ClientEvent` | Report a local client outcome |
| Worker event | Expose a public DTO across the Flutter isolate boundary |

The coordinator routes an event to all sessions, all others, one recipient or
selected round participants. Encrypted DKG/recovery shares still pass through
the coordinator, but only the intended recipient can decrypt their inner
content.

Domain state is normally persisted before publishing an event that represents
a durable mutation. RPC responses and event streams are independent, so they
have no global arrival order.

## Authorship and trust

Participants submit authenticated RPCs; they do not normally create network
events directly:

```text
participant A -> authenticated RPC -> coordinator -> Event -> participants
```

The Iroh connection proves that the pinned coordinator delivered an event.
Where participant authorship matters, the event retains a participant-signed
canonical object, which recipients verify with the roster key. The coordinator
cannot alter that content or forge approval, but it can omit, delay, replay or
selectively route events.

## Wire representation

`EventMessage` contains exactly one typed protobuf `oneof` variant. Signed
domain objects remain canonical nested bytes; ordinary fields use protobuf.
The message is prefixed by a QUIC-varint length on the persistent session
stream because QUIC reads do not preserve application write boundaries.

| Tag | Domain event | Purpose |
| ---: | --- | --- |
| 1 | `ParticipantStatusEvent` | Login/logout observation |
| 2 | `NewDkgEvent` | DKG proposal |
| 3 | `DkgCommitmentEvent` | Round-one contribution |
| 4 | `DkgRejectEvent` | DKG rejection |
| 5 | `DkgRound2ShareEvent` | Recipient-encrypted round-two share |
| 6 | `DkgAckEvent` | Stored-key acknowledgments |
| 7 | `DkgAckRequestEvent` | Request missing acknowledgments |
| 8 | `SignaturesRequestEvent` | Signing proposal |
| 9 | `SignatureNewRoundsEvent` | ROAST commitment sets |
| 10 | `SignaturesCompleteEvent` | Final signatures |
| 11 | `SignaturesFailureEvent` | Terminal failure |
| 12 | `KeepaliveEvent` | Transport liveness only |
| 13 | `SecretShareEvent` | Encrypted recovery share |
| 14 | `ConstructedKeyEvent` | Signed reconstruction claim |
| 15 | `SignaturesProgressEvent` | Coordinator-observed progress |

The server converts domain events with `encodeEvent`; the client incrementally
decodes records with `decodeEvent` and applies protocol-specific validation.
Successful protobuf parsing proves structure only, not authorization.

## Client and worker projections

One network event may cause an RPC without a UI event, and local expiry may
cause a UI event without new network traffic. Projections intentionally expose
application-relevant state rather than mirroring every wire field.

Worker events contain sendable public values and exact proposal bytes used to
bind approval to what the host reviewed. Private FROST shares, nonces, native
objects and callbacks do not appear. Each replacement session emits a snapshot
before its later events; stale-session callbacks are discarded.

Applications should subscribe before starting a setup, reduce events into
their own keyed state, treat snapshots as authoritative current views and keep
their own durable history. Handlers should stay short; a Dart `listen` callback
does not automatically serialize asynchronous application writes.

## Delivery guarantees

- Event order is preserved only within one session stream.
- RPC responses and other participants' streams race independently.
- A socket write does not acknowledge processing, persistence or approval.
- Reconnect creates a new session/snapshot; there is no durable event cursor.
- A paused server session buffers at most 100 recent events and drops older
  transient entries when full.
- Completed results and recovery shares can be restored separately, so hosts
  must deduplicate side effects.

## Adding an event

A core event change requires a domain variant, protobuf `oneof` field, shared
converter, coordinator emission/routing, client validation/state effects and
any public projection. Decide persistence and reconnect semantics explicitly,
then test domain/wire round trips, routing, invalid input and restoration.

Applications cannot add opaque events through the current core. See
[generic data](generic-data.md) and the proposed
[protocol extensions](protocol-extensions.md). Room-manager streams are local
management notifications, not ROAST network events.

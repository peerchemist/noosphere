# Iroh transport

[Architecture overview](../architecture.md)

Iroh provides authenticated endpoint identities, encrypted QUIC connections,
discovery and direct/relay connectivity. Noosphere adds participant
authentication, RPC framing, sessions and event routing.

This chapter describes remote transport. A signer attached to a matching
co-located coordinator can use `LocalCoordinatorApi`, which preserves the
domain protocol while bypassing protobuf and QUIC.

## Identity and authentication

The host supplies the server's Iroh `SecretKey`. Clients connect to an
`EndpointAddr`, but independently pin its endpoint ID; relay URLs and IPs are
only hints. The connected remote ID must match the pin.

Iroh identity authenticates the coordinator transport. Participant identity is
a separate secp256k1 roster key proven by signing a fresh challenge:

```text
pinned Iroh connection
  -> Login(group fingerprint, participant ID, version)
  -> connection-bound challenge and participant signature
  -> StartSession
  -> session ID bound to that connection, group and participant
```

Authentication does not displace an existing signer; `StartSession` does.
Later RPCs must carry the bound session ID on the same connection. Handlers
derive the caller from that binding and must not trust sender IDs inside a
payload.

Events come from the pinned coordinator. Participant-signed inner objects prove
their author's content, but the coordinator still controls delivery and can
omit, delay or replay events.

Room enrollment links contain only the pinned coordinator endpoint ID, not a
snapshot of its IP or relay locations. `IrohRoomEnrollmentApi.joinRoom` creates
an `EndpointAddr` from that ID and lets Iroh discovery resolve the current
route before opening the enrollment ALPN. This keeps changing network
locations out of canonical room models and invite encodings.

## Streams and routing

The server selects ROAST or enrollment by ALPN. Each RPC gets an independent
bidirectional stream. A separate long-lived stream sends `SessionStarted` and
length-prefixed events. Participant contributions use RPCs; clients cannot
publish arbitrary `EventMessage` values.

Per-group dispatch serializes domain mutations even though QUIC multiplexes
streams. Socket writes occur after dispatch releases the group lane. A written
event is not an acknowledgment that the recipient processed, persisted or
approved it. Reconnect starts a new session and snapshot rather than resuming a
durable event offset.

## Defaults

| Setting | Core | Flutter |
| --- | ---: | ---: |
| Protobuf body | 1 MiB | 1 MiB |
| Client concurrent RPCs | 32 | 2 |
| Server streams/connection | 32 | 4 |
| Server connections | 128 | 128 |
| Connect timeout | 15 s | 15 s |
| Authentication timeout | 10 s | 10 s |
| RPC timeout | 30 s | 30 s |
| Server shutdown timeout | 5 s | 5 s |

These are resource bounds, not a complete abuse-prevention system.

## Reconnect and shutdown

`ReconnectingIrohClient` reuses its endpoint but creates a fresh authenticated
`Client` after disconnection. Backoff defaults to 250 ms, multiplier 2, jitter
0.2 and a 30-second cap. Direct callers replace client references from the
`sessions` stream; the worker handles replacement internally.

Mutating RPCs are never replayed automatically. A timeout may have followed a
successful server mutation, so durable prepared records must be reconciled.
Address hints may change under the same pin; changing coordinator identity
requires the explicit rotation workflow.

Logout closes the client connection. Server shutdown closes its endpoint,
waits for handlers and drains dispatch with configured bounds. Iroh encrypts
transport traffic, but the coordinator can read ordinary proposals and message
text. DKG and recovery shares add recipient-specific encryption.

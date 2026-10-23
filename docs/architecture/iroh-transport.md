# Iroh transport

[Architecture overview](README.md)

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

Request decoding treats `ArgumentError` as invalid input and returns a generic
protocol error. Each stream and connection task installs an immediate error
handler. Unexpected errors close the affected connection and are reported through
`IrohServer.start(onError: ...)`, or to stderr when no callback is supplied.
If that callback throws, both failures are logged to stderr. Other connections
continue serving; internal error details are not sent to the peer.

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

The authentication deadline starts when the ROAST connection is accepted,
including before its first stream, and ends only after successful participant
authentication. Issuing a challenge or opening more streams does not extend it.
Public-feed connections expire after `rpcTimeout` without an active request;
enrollment connections use `authTimeout` for the same idle policy. The idle
clock restarts after the last in-flight request finishes. Per-stream deadlines
still apply while requests are active.

Public-feed and enrollment connections together may occupy at most
`maxConnections ~/ 2` slots. The remaining slots are reserved for ROAST traffic,
within the unchanged total connection limit. Setting `maxConnections` to one
therefore admits signer traffic only. Unauthenticated ROAST connections can
briefly fill signer slots until their authentication deadlines expire; this is
not protection against sustained connection floods. Hosts still need admission
and rate controls appropriate to their deployment.

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

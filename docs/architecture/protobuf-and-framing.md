# Protobuf and QUIC framing

[Architecture overview](README.md)

Protobuf supplies typed wire values; QUIC streams supply isolation,
correlation and single-message boundaries. The schema is
[`noosphere.proto`](../../packages/noosphere_protocol/proto/noosphere.proto), exported with
framing helpers through `package:noosphere_protocol/wire.dart`.

## Protocol selection

| ALPN | Purpose |
| --- | --- |
| `noosphere/roast/1` | Login, sessions, DKG and signing |
| `noosphere/roast-enrollment/1` | Invite enrollment |
| `noosphere/public-feed/1` | Unauthenticated public-feed polling |

ALPN selects the wire protocol. `LoginRequest.protocol_version` is a separate
domain check and is currently exactly `1`. Only the current DKG proposal,
event, ACK and storage grammars are defined; other bytes are malformed input.

## RPC framing

Each RPC uses one bidirectional QUIC stream:

```text
request:  [operation QUIC varint][concrete request protobuf] FIN
response: [status QUIC varint][concrete response or ProtocolError] FIN
```

The stable operation ID selects one request/response pair. Status `0` means
success; `1` means `ProtocolError`. FIN delimits the protobuf, so ordinary RPCs
need no length prefix or request ID. Unknown operations return a protocol error
without guessing the body type.

## Persistent session stream

The session response carries several records and therefore needs lengths:

```text
client -> server:
[startSession operation][StartSession] FIN

server -> client:
[length][SessionStarted]
[length][EventMessage]
[length][EventMessage] ... FIN
```

Lengths use RFC 9000 QUIC varints and cover only the following protobuf bytes.
`SessionStarted` is always first. The incremental decoder handles records split
or combined by arbitrary QUIC reads. The server subscribes the session before
writing its snapshot, preserving the snapshot/live-event boundary.

`maxMessageLength` bounds every FIN-delimited body and persistent record.
Truncated varints/records, oversized bodies, invalid protobuf, unknown status
and unknown operations are protocol errors.

## Large objects

No current operation transfers large media. A future large-object stream
should send an operation, a small typed metadata header and raw bytes to FIN,
rather than buffering the payload inside the normal protobuf limit. Add a
header length only if its size is not fixed by the operation.

Length-prefixing remains limited to streams carrying multiple records. Adding
a generic envelope to every RPC would duplicate QUIC's stream correlation and
FIN boundary.

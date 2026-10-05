# Protobuf and QUIC framing

Noosphere uses Protobuf only for typed serialization. QUIC streams provide
isolation, correlation, and, for single-message directions, the message
boundary.

The canonical schema is
[`noosphere.proto`](../packages/noosphere/proto/noosphere.proto). Generated
Dart classes and the transport helpers are exported by
`package:noosphere/wire.dart`.

## Version negotiation

Wire compatibility is selected when the QUIC connection is established:

| ALPN | Purpose |
|---|---|
| `noosphere/roast/1` | Authentication, session events, and ROAST RPCs |
| `noosphere/roast-enrollment/1` | Room enrollment RPCs |

There is no per-message wire-version field. `/1` names the current coordinated
preview protocol; the direct-Protobuf format replaces the earlier preview
layout in place. Noosphere does not decode the former envelope format, so all
peers must be upgraded together. The `LoginRequest.protocol_version` remains a
domain-protocol check and is not a transport framing version.

## One stream per RPC

Every RPC owns one QUIC bidirectional stream. Its request direction is:

```text
[operation: QUIC varint][concrete request protobuf bytes] FIN
```

The operation ID is defined in `RoastOperation` or `EnrollmentOperation` and
maps directly to one generated request type and one generated response type.
For example, `RoastOperation.login` maps `LoginRequest` to `LoginResponse`.
IDs are stable integers rather than protobuf enum ordinals.

| ROAST ID | Request | Success response |
|---:|---|---|
| 1 | `LoginRequest` | `LoginResponse` |
| 2 | `SignedAuthChallenge` | `RespondToChallengeResponse` |
| 3 | `Bytes` (session ID) | `ExtendSessionResponse` |
| 4 | `DkgRequest` | `RequestNewDkgResponse` |
| 5 | `DkgToReject` | `RejectDkgResponse` |
| 6 | `DkgCommitment` | `SubmitDkgCommitmentResponse` |
| 7 | `DkgRound2` | `SubmitDkgRound2Response` |
| 8 | `DkgAcks` | `SendDkgAcksResponse` |
| 9 | `DkgAckRequest` | `RequestDkgAcksResponse` |
| 10 | `SignaturesRequest` | `RequestSignaturesResponse` |
| 11 | `SignaturesRejection` | `RejectSignaturesRequestResponse` |
| 12 | `SignaturesReplies` | `SubmitSignatureRepliesResponse` |
| 13 | `SecretShare` | `ShareSecretShareResponse` |
| 14 | `ConstructedKey` | `AckKeyConstructedResponse` |
| 15 | `StartSession` | persistent `SessionStarted`, then `EventMessage` records |

| Enrollment ID | Request | Success response |
|---:|---|---|
| 1 | `BeginEnrollmentRequest` | `BeginEnrollmentResponse` |
| 2 | `RedeemRoomInviteRequest` | `RedeemRoomInviteResponse` |

The response direction is:

```text
[status: QUIC varint][concrete response protobuf bytes] FIN
```

Status `0` means the body is the concrete response type selected by the
operation. Status `1` means the body is `ProtocolError`. The status prefix is a
two-way result discriminator, not a protobuf envelope; it never contains or
nests request/response messages. FIN delimits the body, so an RPC has no
message-length prefix.

Using a stream as the correlation unit removes request IDs and prevents a
slow RPC from blocking unrelated RPC bytes. A client can open several RPC
streams concurrently while each response remains paired with its request by
QUIC itself.

An unknown operation ID produces an error response and a normal FIN. Older
peers can therefore reject newly added operations without mis-decoding their
protobuf body or closing the connection.

## Persistent event stream

FIN cannot delimit individual records on a long-lived stream. The authenticated
session therefore uses one request followed by a persistent response direction:

```text
client -> server:
[startSession operation varint][StartSession protobuf] FIN

server -> client:
[length varint][SessionStarted protobuf]
[length varint][EventMessage protobuf]
[length varint][EventMessage protobuf]
...
FIN
```

Lengths use the RFC 9000 QUIC variable-length integer encoding. Each length
covers only the following protobuf bytes. `SessionStarted` is always the first
record; every later record is `EventMessage`, so no per-record type envelope is
needed. The shared decoder is incremental because QUIC read calls may split or
combine records arbitrarily.

The server attaches the session and subscribes it to queued/live events before
writing the snapshot record. This preserves the snapshot/subscription boundary
without a `Ready` control message. Closing the QUIC connection is logout; there
is no `Logout` protobuf on the session stream.

## Large objects and media

Large opaque data must not be placed in an RPC protobuf or buffered into the
normal message limit. A dedicated stream uses this layout:

```text
[object operation/type varint]
[small concrete metadata protobuf]
[raw object bytes]
FIN
```

The operation fixes the metadata type and tells the receiver where its typed
header ends. If a future object protocol needs a variable-size header, that
header gets a QUIC-varint length; the raw payload still runs to FIN. No generic
protobuf envelope is introduced.

No current Noosphere operation transfers a large object, so this is a design
constraint for new operations rather than an unused wire message today.

## Limits and failures

`maxMessageLength` bounds a FIN-delimited protobuf body and each persistent
record. Oversized bodies fail before protobuf parsing. Truncated QUIC varints,
truncated persistent records, invalid protobuf bytes, unknown response status,
and unknown operation IDs are protocol errors.

The operation/status prefixes and persistent lengths use the same QUIC-varint
codec. Encoding is minimal; decoding accepts all widths permitted by QUIC.

## Why this design

QUIC already multiplexes reliable ordered byte streams. Adding a generic
protobuf envelope and a fixed length prefix to every one-message stream would
duplicate stream isolation, message correlation, and FIN framing. Direct
protobuf bodies keep operation dispatch explicit and allow independent schema
evolution for each RPC.

A framing layer remains necessary only where a single stream contains multiple
messages: QUIC streams preserve byte order, but not application write/read
boundaries. That is why the persistent event stream retains
`[QUIC varint length][protobuf]` records while ordinary RPC streams do not.

# Deterministic CBOR and QUIC framing

[Architecture overview](README.md)

Noosphere wire version 1 uses concrete typed messages encoded as restricted
deterministic CBOR. The normative schema is
[`CBOR_WIRE.cddl`](../../packages/noosphere_protocol/spec/CBOR_WIRE.cddl),
exported with framing helpers through `package:noosphere_protocol/wire.dart`.

## Protocol selection

| ALPN | Purpose |
| --- | --- |
| `noosphere/roast-cbor/1` | Login, sessions, DKG and signing |
| `noosphere/roast-enrollment-cbor/1` | Invite enrollment |
| `noosphere/public-feed-cbor/1` | Unauthenticated public-feed polling |

These identifiers are incompatible with the former protobuf ALPNs. A CBOR
implementation never serves messages under those identifiers. ALPN wire
versions remain distinct from the domain protocol version carried by
`LoginRequest` and signed DKG objects.

## Deterministic profile

Every message is a definite-length CBOR map with stable nonnegative integer
field keys. Field keys retain the former field numbers where practical. The
encoder follows RFC 8949 section 4.2 core deterministic encoding requirements:

- integers and lengths use their shortest encoding;
- map keys are ordered first by encoded length and then bytewise
  lexicographically;
- byte strings, text strings, arrays and maps use definite lengths;
- required fields are present even when zero, false or empty;
- absent optional fields are omitted; `null` is never accepted as absence;
- variants use required integer discriminator key `1` and typed payload key
  `2`.

The profile admits only integers, byte strings, UTF-8 text strings, arrays,
maps and booleans. Tags, floats, null, undefined, indefinite-length items,
unknown fields or enum values, duplicate/out-of-order keys, trailing bytes and
nonminimal values are rejected. Decoding is bounded to 16 nested containers,
4096 entries per collection and 16 MiB per byte/text value; transport limits
normally reject a message sooner. Extensions require a new explicit wire
compatibility decision because this version rejects unknown fields.

Binary domain encodings, cryptographic values and signed domain inputs remain
opaque CBOR byte strings and are not re-encoded.

Array order is significant. Domain sets retain their established stable domain
encoding before becoming CBOR byte strings; collections represented directly
as arrays are emitted in their protocol-defined sequence. Exact identifier,
cryptographic-object and pagination bounds remain enforced by the existing
domain parsers after the bounded CBOR shape check.

The implementation uses Dart package `cbor` 6.5.1 for value encoding and
decoding. Its encoder selects shortest integer widths but does not sort maps or
force definite containers for every size, and its decoder materializes maps.
Noosphere therefore constructs sorted definite containers itself and runs a
bounded byte-level profile validator before library decoding. Duplicate keys
and ordering violations are rejected before map materialization. Integers that
the library exposes as `BigInt` are range-checked and converted only when they
fit the protocol's signed 64-bit bounds.

## RPC framing

Each RPC uses one bidirectional QUIC stream:

```text
request:  [operation QUIC varint][concrete request CBOR] FIN
response: [status QUIC varint][concrete response or ProtocolError CBOR] FIN
```

The stable operation ID selects one request/response pair. Status `0` means
success and `1` means `ProtocolError`. FIN delimits ordinary messages, so they
need no additional length or request ID. Unknown operations return a protocol
error without guessing the body type.

## Persistent session stream

The session response carries multiple records:

```text
client -> server:
[startSession operation][StartSession CBOR] FIN

server -> client:
[length][SessionStarted CBOR]
[length][EventMessage CBOR]
[length][EventMessage CBOR] ... FIN
```

Lengths remain shortest RFC 9000 QUIC varints and cover only the following
CBOR bytes. `SessionStarted` is always first. Subscription still precedes the
snapshot write, preserving the snapshot/live-event boundary. Existing message
limits, stream order and framing error handling are unchanged.

## Public-feed compatibility

Public-feed page schema version 1 contains deterministic CBOR page bytes. The
checkpoint signature covers exactly:

```text
UTF8("noosphere/public-feed/checkpoint/cbor/v1\0") || pageBytes
```

Legacy protobuf checkpoint bytes and signatures are not accepted or rewritten.
Coordinator snapshot version 1 requires the `cbor` format marker and stores
journal entries as CBOR page version 1. All legacy snapshots are rejected
without a migration shim.

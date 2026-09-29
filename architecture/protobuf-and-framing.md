# Protobuf and framing

[Architecture overview](../architecture.md)

The canonical network schema is
[`noosphere.proto`](../packages/noosphere/proto/noosphere.proto). It uses proto3
messages and enums. There is no gRPC service definition: current RPCs are
implemented directly over Iroh bidirectional QUIC streams.

## Envelope structure

Every ordinary ROAST frame contains one `Envelope`:

```proto
message Envelope {
  uint32 wire_version = 1;
  oneof payload {
    RpcRequest rpc_request = 10;
    RpcResponse rpc_response = 11;
    StartSession start_session = 20;
    SessionStarted session_started = 21;
    Ready ready = 25;
    Logout logout = 27;
    Events event = 28;
    ProtocolError error = 29;
  }
}
```

The `oneof` describes which body is present. The generated Dart API exposes
`whichPayload()`, `whichRequest()`, and `whichResponse()` discriminators.
An envelope without a recognized payload is invalid for the framing API.

`RpcRequest` contains a nonempty caller-generated `request_id` plus one of 14
operations. `RpcResponse` echoes that ID and contains a typed result or error.
The client verifies the ID and expected result variant before decoding data.

## Request mapping

| Domain operation | Protobuf request body | Result content |
| --- | --- | --- |
| `login` | `LoginRequest` | Serialized expiring challenge |
| `respondToChallenge` | `SignedAuthChallenge` | Authentication success; snapshot follows on the session stream |
| `extendSession` | `Bytes` containing session ID | Serialized `Expiry` |
| `requestNewDkg` | `DkgRequest` | Explicit empty success |
| `rejectDkg` | `DkgToReject` | Explicit empty success |
| `submitDkgCommitment` | `DkgCommitment` | Explicit empty success |
| `submitDkgRound2` | `DkgRound2` | Explicit empty success |
| `sendDkgAcks` | `DkgAcks` | Explicit empty success |
| `requestDkgAcks` | `DkgAckRequest` | Repeated serialized signed ACKs |
| `requestSignatures` | `SignaturesRequest` | Explicit empty success |
| `rejectSignaturesRequest` | `SignaturesRejection` | Explicit empty success |
| `submitSignatureReplies` | `SignaturesReplies` | `oneof`: no update, new round, completed signatures |
| `shareSecretShare` | `SecretShare` | Already-known constructed-key events |
| `ackKeyConstructed` | `ConstructedKey` | Explicit empty success |

The concrete mappings live in the
[client adapter](../packages/noosphere_client/lib/src/iroh/client_api.dart) and
[server connection handler](../packages/noosphere_server/lib/src/iroh/connection_handler.dart).
The schema also retains older wrapper messages such as `SignaturesResponse`;
the active envelope RPC uses `SubmitSignatureRepliesResponse` with typed
outcomes instead of that older type-plus-data response.

## Canonical domain bytes inside protobuf

Examples of `bytes` fields include signed request details, Frosty aggregate
key information, commitments, encrypted shares and snapshots. Their contents
are the existing `Writable.toBytes()` encodings:

```text
SignaturesRequestDetails
  -> Signed<SignaturesRequestDetails>.toBytes()
  -> SignaturesRequest.signed_details
  -> RpcRequest.request_signatures
  -> Envelope.rpc_request
  -> protobuf bytes
  -> length-prefixed QUIC stream data
```

The receiving adapter unwraps protobuf, then invokes the relevant domain
decoder. Structural protobuf validity therefore does not imply valid domain
data, a valid cryptographic signature, an authorized session, or a permissible
state transition. Those are separate checks.

Cryptographic signatures bind canonical domain encodings, not the incidental
serialization order of protobuf fields. This lets the transport wrap existing
cryptographic values without redefining their signed representation.

## The `Events` payload

```proto
message Events {
  EventType type = 1;
  bytes data = 2;
}
```

Despite its plural name, one `Events` message represents one domain event.
For example, `SIG_REQ_EVENT` selects `SignaturesRequestEvent.fromBytes(data)`.
`data` is a binary domain payload, not protobuf JSON, a serialized Dart object
graph, or an automatically understood arbitrary map.

The server's [event encoder](../packages/noosphere_server/lib/src/iroh/messages.dart)
sets the enum and writes `event.toBytes()`. The client decoder selects the
corresponding constructor. These explicit switches define the supported
application protocol. A new enum value and new bytes require matching codecs
and handlers; a byte field alone does not supply extensibility.

`SessionStarted.snapshot` contains a serialized `LoginCompleteResponse`:
session ID/expiry, server start time, online peers, pending DKG/signing requests,
pending rounds, completed signatures and encrypted recovery shares. Its live
`events` stream is not serialized; the receiving adapter attaches that stream
when constructing the domain response.

## Frame encoding and incremental decoding

[`framing.dart`](../packages/noosphere/lib/src/framing.dart) defines:

```text
4 bytes: unsigned protobuf body length, big-endian
N bytes: Envelope.writeToBuffer()
```

The default maximum body length is 1,048,576 bytes. The four-byte prefix is
additional. `encodeEnvelope` rejects an unset payload or an oversized body.

`decodeEnvelopes` is an `async*` stream transformer because QUIC read chunks
do not preserve application-message boundaries. It accumulates four header
bytes, validates the advertised size before allocating a body, and yields
each complete envelope immediately. One read can contain several frames;
one frame can span many reads. Retained state is one frame body plus the
current input chunk, rather than a list of all messages.

Failures distinguish oversized frames, truncated headers/bodies, invalid
protobuf and missing payloads. Transport adapters read native chunks up to
64 KiB. Version acceptance is checked by transport code, independently of
the framing decoder.

## Versions and errors

The current wire version, ROAST login version and worker message version are
all 1, but they are separate concepts. Package versions and signed-message
format versions are separate again.

The [version policy](../packages/noosphere/spec/VERSIONING.md) treats this as
an R&D baseline: matching version numbers do not promise compatibility across
different development builds. Current changes update both peers together.
The policy reserves stable field-number evolution and compatibility decisions
for a stable release.

`ProtocolError` defines a code, message and retryable flag, including possible
unknown-outcome and authentication codes. This is a representational vocabulary,
not a guarantee that each error branch selects the most specific code today.
The current server maps many caught errors to `INVALID_REQUEST`; the client
also exposes local timeout/transport failures. A retryable field does not
automatically replay a mutation.

## Generation and other formats

Generated files live in
[`lib/src/generated`](../packages/noosphere/lib/src/generated). Run
`./tool/generate_protocol.sh` from `packages/noosphere`; `--check` regenerates
into temporary storage and compares the result. The script uses the local
pinned Dart protoc plugin and retains `.pb.dart`, `.pbenum.dart` and
`.pbjson.dart`. There are no generated gRPC service stubs.

Protobuf is not used for every boundary. Worker messages are Dart maps/DTOs,
room enrollment uses its own little-endian-prefixed binary protocol, and the
server persistence snapshot is versioned JSON with binary components. Each
format has its own purpose and decoder.

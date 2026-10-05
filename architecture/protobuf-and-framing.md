# Protobuf and framing

[Architecture overview](../architecture.md)

The canonical network schema is
[`noosphere.proto`](../packages/noosphere/proto/noosphere.proto). It uses proto3
messages and enums. There is no gRPC service definition: current RPCs are
implemented directly over Iroh bidirectional QUIC streams.

## Envelope structure

Every ROAST or enrollment frame contains one `Envelope`:

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
    EventMessage event = 28;
    ProtocolError error = 29;
  }
}
```

The `oneof` describes which body is present. The generated Dart API exposes
`whichPayload()`, `whichRequest()`, and `whichResponse()` discriminators.
An envelope without a recognized payload is invalid for the framing API.

`RpcRequest` contains a nonempty caller-generated `request_id` plus one of 16
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
| `beginEnrollment` | `BeginEnrollmentRequest` | Serialized `EnrollmentChallenge` |
| `redeemRoomInvite` | `RedeemRoomInviteRequest` | Serialized `RoomSnapshot` |

The concrete mappings live in the
[client adapter](../packages/noosphere_client/lib/src/iroh/client_api.dart) and
[server connection handler](../packages/noosphere_server/lib/src/iroh/connection_handler.dart).
The enrollment operations use the
[enrollment client](../packages/noosphere_client/lib/src/iroh/room_enrollment_api.dart)
and [enrollment handler](../packages/noosphere_server/lib/src/iroh/enrollment_connection_handler.dart)
on the dedicated enrollment ALPN, before a ROAST session exists.
The envelope RPC uses `SubmitSignatureRepliesResponse` with typed outcomes.
Unused legacy response wrappers have been removed from the schema.

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

## The `EventMessage` payload

```proto
message EventMessage {
  oneof event {
    ParticipantStatusEvent participant_status = 1;
    NewDkgEvent new_dkg = 2;
    // ...one typed field for every supported event...
    SignaturesProgressEvent signatures_progress = 15;
  }
}
```

One `EventMessage` represents one domain event. The `oneof` discriminator and
selected generated message replace the former
type-enum-plus-opaque-bytes representation. For example,
`signatures_request` contains `signed_details`, `creator_id` and a typed
`SignaturesProgress` message.

The server's [event encoder](../packages/noosphere_server/lib/src/iroh/messages.dart)
and the client decoder use the shared converters in
[`event_wire.dart`](../packages/noosphere/lib/event_wire.dart). These explicit,
exhaustive switches define the supported application protocol. A new oneof
message requires matching domain conversion and handling; protobuf does not
supply protocol behavior by itself.

For a concrete `SignaturesRequestEvent event`, the server's mapping is
conceptually this code (the real `encodeEvent` handles every supported variant):

```dart
final message = protocol.EventMessage(
  signaturesRequest: protocol.SignaturesRequestEvent(
    signedDetails: event.details.toBytes(),
    creatorId: event.creator.toBytes(),
    progress: encodeProgress(event.progress),
  ),
);
final envelope = protocol.Envelope(
  wireVersion: noosphereIrohWireVersion,
  event: message,
);
final frame = encodeEnvelope(envelope);
// The connection handler awaits send.writeAll(frame).
```

Every event's own fields are now described in `noosphere.proto`. Nested
cryptographic objects such as `Signed<SignaturesRequestDetails>`, FROST
commitments, ACKs and ciphertexts remain `bytes` containing their canonical
domain encoding. Their signatures and hashes bind those encodings, so the
protobuf transport must not redefine them. Identifiers, request IDs, public
keys and signatures are also byte strings with lengths enforced while
constructing the domain value.

The receiving path has separate checks:

| Stage | Check and result |
| --- | --- |
| Frame decoder | Enforces envelope size, gathers a complete length-prefixed body, parses protobuf and requires a recognized envelope payload |
| Session adapter | Checks wire version and accepts event/error envelopes on the established session stream |
| Event mapping | Requires a selected `EventMessage.event` variant, converts its typed fields, and decodes canonical nested values |
| Participant state machine | Checks identities, signed contents, expiry, round/request context and cryptographic contributions as appropriate to the event |
| Host approval | Decides whether a valid proposal should be accepted for the application's purposes |

Nested domain `fromBytes` readers enforce bounded whole-value decoding,
including trailing-data checks. A missing event oneof is rejected, and
`KeepaliveEvent` is represented by an explicit empty protobuf message. There is
no general signature over the protobuf `EventMessage` wrapper: signed proposals and
other attestations bind their specified domain hashes, while Iroh authenticates
the transport endpoints. For example, proposal progress is checked as a
coordinator report, not as part of the requester's proposal signature.

A framing, envelope or domain-decoding failure in `_pumpEvents` is reported
as a stream error and closes that event stream. A protocol-validation failure
inside `Client._handleEvent` is reported through `Client.events` and disconnects
the client session. These paths do not retry the offending event; a reconnecting
runtime establishes a new session and snapshot.

The [event chapter](events.md#from-a-dart-event-to-iroh-bytes-and-back) traces the
producer, recipient selection, both codecs and the receiving state transition,
including a worked signing-proposal sequence.

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

The current Iroh wire version and ROAST login protocol version are both 1,
but they are separate concepts. Package versions and signed-message format
versions are separate again. The internal worker uses same-build Dart message
types and generation IDs; it has no independently negotiated wire version.

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

Enrollment domain failures also set the optional `room_failure_code` to the
`RoomFailureCode` index. Presence distinguishes `unknownRoom` (zero) from an
error without a room code. `RoomEnrollmentProtocolException` preserves that
index, uses `0xffff` when it is absent, and exposes the protobuf error. A
request that could be decoded receives a correlated `RpcResponse.error`;
framing, wire-version and envelope-shape failures use `Envelope.error`.

## Generation and other formats

Generated files live in
[`lib/src/generated`](../packages/noosphere/lib/src/generated). Run
`./tool/generate_protocol.sh` from `packages/noosphere`; `--check` regenerates
into temporary storage and compares the result. The script uses the local
pinned Dart protoc plugin and retains `.pb.dart`, `.pbenum.dart` and
`.pbjson.dart`. There are no generated gRPC service stubs.

Worker messages are typed Dart envelopes carrying encoded fields and public
DTOs, and the server persistence snapshot is versioned JSON with binary
components. Those local boundaries have their own decoders; both network ALPNs
share protobuf framing.

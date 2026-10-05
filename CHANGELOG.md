# Changelog

## Unreleased

### Flutter integration

- Route a co-located signer directly through its active room coordinator when
  the pinned endpoint ID and group fingerprint match. Keep Iroh for remote
  participants and avoid a second local endpoint and QUIC loopback connection.

### Protocol

- Replace the generic protobuf `Envelope`/RPC oneofs with one QUIC bidi stream
  per operation, direct concrete protobuf bodies, FIN-delimited RPC messages,
  and QUIC-varint length framing only for persistent session events. This
  replaces the preview wire format in place without legacy decoding.
- Add `package:noosphere/wire.dart` as the shared protobuf, framing, event-codec
  and wire-constant entry point used by both transport adapters.
- Replace the streamed event type/opaque-bytes wrapper with a typed protobuf
  `oneof` covering every event. This is a coordinated preview wire break;
  clients and servers must be upgraded together.
- Split signature metadata codecs behind one supported-type registry while
  preserving wire bytes, authenticated requests and login replay.
- Mark 0.1.0 as a coordinated protocol preview and add fixed wire fixtures.
- Document retained native-value ownership and pin Frosty 5.0.0.
- Move YAML configuration parsing to the standalone server CLI. Remove shared
  map/YAML conversion APIs and YAML dependencies from the domain and client.
- Bound domain decoding to the supplied byte slice; reject trailing data,
  non-canonical length encodings, invalid booleans and duplicate map keys.
- Correct serialized size measurement at variable-integer width boundaries.
- Protect cached serializations, signing hashes, signing payloads and protocol
  collections against mutation. `GroupConfig.participants` is now a read-only
  `Map` in canonical identifier order.
- Reject unknown metadata in signing requests; preserve it only as a standalone
  opaque value.
- Remove unused protobuf wrappers `RepeatedBytes`, `Empty`,
  `SignaturesResponse` and `SignaturesResponseType`. Active envelope fields and
  valid payload encodings are unchanged.
- Add canonical group-transition proposals, bounded host migration policies,
  exact DKG plan bindings, and participant identity-key approvals.
- Add versioned pubkey-bound room invites, canonical enrollment transcripts,
  room lifecycle snapshots, and the transport-independent enrollment API.

## 0.1.0

### Flutter integration

- Separate the worker command channel, provider registry, role lifecycle and
  DTO projection. Use typed internal envelopes and isolated codecs/limits.
- Retain nodes and providers after failed cleanup so explicit stop can retry;
  acknowledge failed coordinator switches with `lockSigner` before restarting.
- Deliver replacement-session snapshots before events and report attachment
  failures without leaving unobserved asynchronous errors.
- Extract the example session controller and proposal widgets; close sessions
  disposed during startup and verify historical HD/Taproot completions.

- Preserve host providers when startup succeeds but its snapshot exceeds the
  worker message limit; report `start_result_too_large` with a stop/retry path.
- Serialize identity operations without caching failed restore futures.
- Expose embedded server completion and report failed serving loops through
  worker health events and snapshots.
- Document the coordinated preview compatibility policy and native ownership
  boundary; pin Frosty to the tested version.

- Provide Linux and macOS direct-node and isolate-worker APIs for Noosphere
  participants and embedded coordinators.
- Keep identity, client, room and coordinator persistence with host providers.
- Bind approval to immutable proposal bytes and preserve client storage ordering
  across worker replacement when the host reuses a provider instance.
- Reject overlapping lifecycle changes to one setup with `setup_busy`, and
  reject duplicate role starts before changing host providers.
- Expose public progress, completion, key and session replacement events.
- Include a desktop example and unit and native integration tests.

### Protocol

- Establish the transport-independent Noosphere protocol package.
- Move the canonical protobuf schema, generated messages and bounded framing
  implementation from the client package.
- Own the shared ROAST domain model, group configuration, serialization
  utilities and Iroh transport settings used by both client and server.
- Preserve the existing wire format and protocol tests.

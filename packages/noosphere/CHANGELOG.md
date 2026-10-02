## Unreleased

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

- Establish the transport-independent Noosphere protocol package.
- Move the canonical protobuf schema, generated messages and bounded framing
  implementation from the client package.
- Own the shared ROAST domain model, group configuration, serialization
  utilities and Iroh transport settings used by both client and server.
- Preserve the existing wire format and protocol tests.

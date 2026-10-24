# Protobuf to CBOR implementation checklist

Replace Protobuf completely with CBOR in Noosphere. The result must be typed,
strictly validated, simple, and deterministic. Complete the steps below in order,
and mark items complete only after implementing and verifying them.

## 1. Establish scope and compatibility boundaries

- [x] Read applicable repository instructions and architecture documentation,
  especially [deterministic CBOR and framing](architecture/cbor-and-framing.md),
  [public feed](architecture/public-feed.md), and
  [development and testing](architecture/development-and-testing.md).
- [x] Inventory Protobuf requests, responses, events, enrollment messages,
  public-feed messages, dependencies, generated files, and generation tooling.
- [x] Identify any persisted or signed data containing Protobuf bytes and
  explicitly address its compatibility requirements.
- [x] Preserve domain behavior, operation IDs, QUIC framing, message limits,
  stream ordering, and the snapshot/live-event boundary.
- [x] Preserve existing custom binary domain encodings, cryptographic payloads,
  and domain-separated signing inputs wherever they do not depend on Protobuf.
  Carry these unchanged as CBOR byte strings.
- [x] Introduce new ALPN identifiers for the incompatible wire format. Never
  serve CBOR under existing Protobuf identifiers.
- [x] Explicitly version public-feed page encoding and its signing context:
  current signed checkpoints contain Protobuf page bytes.
- [x] Keep wire-format versioning distinct from domain protocol versions; change
  each version only where its contract changes.
- [x] Do not implement dual-format compatibility or migration shims unless
  explicitly required by the user's instructions.

## 2. Define the wire schema

- [x] Use CBOR maps with explicit, stable, nonnegative integer field keys.
- [x] Preserve existing Protobuf field numbers where practical, and never reuse
  retired field keys for different meanings.
- [x] Assign explicit integer IDs to enums and event variants. Never serialize
  Dart enum ordinals.
- [x] Encode binary data as CBOR byte strings.
- [x] Specify every field's type, range, requiredness, and length constraints.
- [x] Encode required fields even when their values are zero, false, or empty.
- [x] Omit absent optional fields. Do not accept CBOR null as an alternative
  spelling of absence.
- [x] Represent variants with an explicit discriminator and its corresponding
  typed payload.
- [x] Reject unknown fields, enum values, and variants for this version.
  Document that extensions require an explicit compatibility/version decision.
- [x] Specify timestamp units, integer bounds, and collection-order semantics.
  Preserve sequence order and define stable order for unordered collections.
- [x] Write a concise CDDL schema and readable protocol documentation, and keep
  both consistent with the codecs.

## 3. Select and verify the CBOR implementation

- [x] Evaluate a maintained Dart CBOR library against the required encoding,
  decoding, supported targets, and resource-limit behavior.
- [x] Verify its actual behavior; do not assume an option named "canonical"
  implements the chosen deterministic profile.
- [x] Confirm duplicate map keys can be rejected before they are collapsed into
  a Dart map.
- [x] Confirm integer conversions preserve precision on supported targets.
- [x] Confirm size, nesting, and collection limits can be enforced during
  parsing, before excessive allocation or recursion.
- [x] Prefer library capabilities plus a small validation layer limited to this
  protocol. Do not implement a general-purpose CBOR parser or serialization
  framework.

## 4. Implement the deterministic encoding profile

Use [RFC 8949 core deterministic encoding requirements](https://www.rfc-editor.org/rfc/rfc8949.html#section-4.2.1)
with the restrictions below.

- [x] Use the shortest integer and length encodings.
- [x] Use definite-length strings, arrays, and maps only.
- [x] Sort map keys by their encoded bytes as required by the RFC.
- [x] Disallow floating-point values, CBOR tags, null, undefined, and other
  unused types.
- [x] Ensure each valid typed message has exactly one wire encoding, including
  consistent default-value and optional-field handling.
- [x] Ensure output is independent of map insertion order.
- [x] Document the exact profile rather than referring only to "canonical CBOR".

## 5. Implement typed codecs and strict decoding

- [x] Keep application code working with concrete Dart types. Restrict raw CBOR
  values and maps to the codec boundary.
- [x] Reuse domain types where their semantics match the wire contract. Add
  small immutable wire types only where needed.
- [x] Represent alternatives with sealed types or another exhaustive typed
  representation; do not replace oneof messages with bags of optional fields.
- [x] Give each operation concrete request and response codecs, preserving the
  relationship between operation IDs and their types.
- [x] Avoid dynamic, unchecked casts, reflection, and speculative abstractions.
- [x] Use small shared validation helpers without obscuring message definitions.
- [x] Enforce existing message-size limits and appropriate nesting,
  collection-count, and field-length limits before constructing typed values.
- [x] Reject duplicate keys, nonminimal encodings, indefinite lengths, incorrect
  map ordering, trailing bytes, and unsupported CBOR types.
- [x] Reject missing required fields, wrong types, invalid discriminator/payload
  combinations, and integers outside the declared bounds.
- [x] Preserve distinctions such as absent versus explicitly zero.
- [x] Retain domain validation for identifiers, cryptographic objects,
  timestamps, and pagination.
- [x] Convert malformed input into controlled protocol errors.
- [x] If using re-encoding comparisons, treat them as supplementary checks;
  they do not replace duplicate detection or parsing resource limits.

## 6. Migrate callers and remove Protobuf

- [x] Migrate RPC request and response serialization on both client and server.
- [x] Migrate session startup and streamed event serialization.
- [x] Migrate enrollment request and response serialization.
- [x] Migrate public-feed request, page, and signed-checkpoint serialization,
  including offline verification paths.
- [x] Apply the new protocol identifiers consistently on both ends and verify
  that incompatible peers are rejected.
- [x] Preserve transport framing and existing signed domain bytes throughout.
- [x] Remove generated Protobuf classes and exports, schema files, generation
  scripts, and obsolete build or CI steps.
- [x] Remove Protobuf runtime and generator dependencies and update lockfiles.
- [x] Remove fixnum only if no remaining usage requires it.
- [x] Update examples, package descriptions, architecture documentation, and
  protocol specifications to describe the final implementation.
- [x] Keep the diff focused. Do not add unrelated refactors, configurable
  serialization modes, or new code generation infrastructure.

## 7. Verify behavior and byte compatibility

- [x] Add round-trip coverage for every request, response, event, and variant.
- [x] Add fixed byte vectors for representative messages and signed public-feed
  pages, including their signing inputs.
- [x] Cross-check representative golden vectors with an independent CBOR
  implementation that uses the same deterministic profile.
- [x] Test identical output for different map insertion orders.
- [x] Test missing versus zero-valued optional fields and required default values.
- [x] Test duplicate keys, unknown fields, unknown enums, wrong types, missing
  required fields, and malformed variants.
- [x] Test trailing bytes, nonminimal integers and lengths, incorrect map
  ordering, indefinite lengths, and unsupported types.
- [x] Test integer boundaries and configured size, nesting, collection-count,
  and field-length limits.
- [x] Run relevant RPC, enrollment, session-streaming, and public-feed integration
  tests, preserving existing ordering and framing coverage.
- [x] Test rejection of incompatible protocol versions and public-feed formats.
- [x] Verify unchanged bytes for existing signed domain payloads outside the
  Protobuf migration.
- [x] Run formatting, static analysis, and relevant repository checks. Broaden
  testing where failures or cross-package changes justify it.
- [x] Search for remaining Protobuf imports, generated-file references,
  dependencies, and obsolete generation steps; remove active leftovers.

## 8. Report completion

- [x] Summarize the typed codec design and deterministic encoding profile.
- [x] List compatibility changes, including ALPN identifiers, public-feed
  versions, signing contexts, and any affected persisted data.
- [x] Report checks performed and their results, including independent golden
  vector validation.
- [x] Identify any remaining limitations or checks that could not run.
- [x] Do not claim size or performance improvements without measurements.

## Acceptance criteria

- [x] Application code uses concrete types with exhaustive variant handling.
- [x] Every accepted message obeys the documented schema and deterministic
  profile, with bounded parsing and controlled errors for invalid input.
- [x] Existing non-Protobuf signed domain payloads remain byte-for-byte unchanged.
- [x] The new wire format and signed public-feed format are explicitly versioned.
- [x] Protobuf is fully removed from active code and build tooling.
- [x] Documentation and meaningful tests describe and verify the final behavior.

## Verification record

Completed on branch `cbor-wire-migration` on 2026-10-24. The full shared
protocol suite passes (105 tests); client integration passes (27 tests, with
one environment-dependent discovery test skipped); Flutter tests pass (76
tests); and the relevant server RPC, enrollment, network-error, stream-policy,
and public-feed paths pass when run sequentially. Representative deterministic
CBOR vectors were independently reproduced with Python `cbor2`.

All newly introduced CBOR wire, public-feed, signing-context, and persistence
versions are 1. Legacy protobuf and snapshot formats are rejected without
migration or compatibility shims.

One pre-existing public-feed test cannot complete as written because it starts
a second live server with the same single-owner `ServerApiHandler`; it fails
with `server handler already has a session owner`. The CBOR-specific public-feed
codec, signature, tampering, paging, and transport checks pass. No size or
performance improvement is claimed.

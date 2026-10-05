# Protocol extensions

[Architecture overview](../architecture.md)

> **Status: proposed, not implemented.** The current protocol still uses a
> fixed `EventMessage.event` protobuf `oneof`, sealed domain events and
> exhaustive client/worker switches. This chapter describes a possible
> extension architecture rather than APIs available in this checkout.

Noosphere can make optional protocol features easier to add without turning
the cryptographic protocol into an unrestricted message bus. The proposed
design keeps DKG, ROAST, key recovery and other security-critical events in the
core typed protocol, while providing one negotiated extension lane for
application-defined features.

## The envelope in simple terms

An `ExtensionEvent` is a standard shipping box. Noosphere understands the
label on the box, while the registered extension understands its contents:

```text
ExtensionEvent
├─ extension_id: who defines the payload format
├─ version: which version of that format is in use
├─ event_type: which event happened
├─ event_id: optional deduplication identifier
└─ payload: bounded, extension-specific encoded data
```

For example:

```text
extension_id = "net.peercoin.noosphere.multisig-minting"
version      = 1
event_type   = 1  // minting opportunity found
event_id     = hash of the canonical minting candidate
payload      = encoded MintingOpportunityFound message
```

Noosphere would check that the extension was negotiated, enforce limits and
deliver the envelope to a registered decoder. The multisig-minting extension
would decode and validate `MintingOpportunityFound`. Noosphere would not
interpret Peercoin staking rules or treat the event itself as authorization to
sign.

In this example, one participant runs a stake finder for a UTXO controlled by
the group's shared FROST key. When it finds a valid minting opportunity, it
submits the canonical candidate to the coordinator through an authenticated
extension RPC. The coordinator emits the extension event to the other group
participants. Each participant independently verifies the finder, shared key,
stake input, chain context, candidate time and exact data to be signed. A valid
candidate then enters the ordinary signing proposal and ROAST workflow; the
extension transports discovery and context but does not bypass signing policy
or participant approval.

The central schema changes once to add the stable envelope:

```proto
message ExtensionEvent {
  string extension_id = 1;
  uint32 version = 2;
  uint32 event_type = 3;
  bytes payload = 4;
  bytes event_id = 5;
}

message EventMessage {
  oneof event {
    // Existing core events retain their field numbers.
    ExtensionEvent extension = 16;
  }
}
```

After that, an extension can define its own protobuf schema without adding a
new field to the core `EventMessage` for every application event.

## Goals and non-goals

The proposal aims to:

- let an importing application define optional events without forking the
  central Noosphere event schema;
- preserve typed decoding and explicit validation inside every extension;
- negotiate support before an extension event is emitted;
- keep payload, resource and isolate boundaries explicit;
- allow extensions to be shared by a Flutter application and its coordinator;
- retain coordinated core releases for security-critical protocol changes.

It does not aim to:

- accept arbitrary Dart objects over the network;
- allow unregistered or unnegotiated events;
- make the event stream a durable queue;
- let extensions bypass signing approval or mutate private FROST state;
- dynamically download executable Dart plug-ins;
- make protobuf parsing equivalent to authentication or authorization.

## Core events and extension events

The two lanes have different trust and evolution requirements:

| Core typed event | Extension event |
| --- | --- |
| Defined directly in the central protobuf `oneof` | Uses the stable `ExtensionEvent` field |
| Handled exhaustively by the core client | Dispatched through a negotiated registry |
| Appropriate for DKG, ROAST and key recovery | Appropriate for optional application features |
| Requires a coordinated Noosphere release | Can live in a shared application extension package |
| May change core cryptographic state | Must use constrained extension contexts |

Login/session lifecycle, DKG contributions, ROAST rounds, signature results,
FROST share recovery and changes to signing authorization should remain core
events. Peercoin stake discovery and construction of a minting candidate are
application-specific responsibilities that can use the extension lane, while
the resulting threshold signature remains a core ROAST operation. A mature
extension can later be promoted into the core protocol.

## Extension manifest and event keys

Every extension needs a stable identifier, supported version range and payload
limit:

```dart
final class ProtocolExtensionManifest {
  const ProtocolExtensionManifest({
    required this.id,
    required this.minVersion,
    required this.maxVersion,
    required this.maxPayloadBytes,
  });

  final String id;
  final int minVersion;
  final int maxVersion;
  final int maxPayloadBytes;
}
```

A reverse-domain identifier such as
`net.peercoin.noosphere.multisig-minting` avoids collisions. Every event inside
the extension receives a positive numeric type. The effective wire key is:

```text
(extension ID, negotiated version, event type)
```

An extension must not reuse the same key for different semantics. Removing an
event reserves its number within that extension version.

## Typed payload codecs

The core envelope contains bytes, but application and protocol code should use
typed codecs rather than manipulating those bytes directly:

```dart
abstract interface class ExtensionEventCodec<T extends Object> {
  int get eventType;
  int get maxPayloadBytes;

  Uint8List encode(T event);
  T decode(Uint8List payload);
}
```

An extension may define a small protobuf file for its own payloads:

```proto
message MintingOpportunityFound {
  bytes group_key = 1;
  bytes finder_id = 2;
  uint64 minting_time = 3; // Unix seconds used by the candidate.
  bytes candidate = 4;    // Canonical extension-defined candidate bytes.
  bytes finder_signature = 5;
}
```

The canonical candidate must contain enough information to identify the stake
input and reconstruct or verify every digest that the group will be asked to
sign. The finder signature binds those bytes, the group key and minting time to
the authenticated participant identity. Recipients still validate the
candidate against their own trusted Peercoin chain view rather than accepting
the finder's claim.

The extension owns generation and compatibility tests for those bindings. The
core registry enforces both the global message limit and the smaller
extension/event limit before decoding.

A custom envelope is preferable to `google.protobuf.Any`: it gives Noosphere
explicit identifiers, negotiated versions, predictable limits and a registry
suited to Dart AOT builds without relying on runtime type URLs or reflection.

## Capability negotiation

The server must never send an event merely because it has a codec installed.
The authenticated session handshake should negotiate extension support:

```proto
message ExtensionCapability {
  string extension_id = 1;
  uint32 min_version = 2;
  uint32 max_version = 3;
}

message NegotiatedExtension {
  string extension_id = 1;
  uint32 version = 2;
}
```

The client advertises supported ranges. The coordinator selects at most one
compatible version of each extension and returns the negotiated set. That set
should be bound to the authenticated login transcript so it cannot be changed
independently of participant authentication.

For each session the coordinator records a mapping such as:

```text
net.peercoin.noosphere.multisig-minting -> version 1
```

Rules are strict:

- the coordinator does not emit an unnegotiated extension;
- an unknown event type in a negotiated version is a protocol error;
- a malformed or oversized payload is a protocol error;
- an optional unsupported extension is omitted;
- an unsupported required extension prevents the session or group operation.

Because an older client advertises no extensions, a newer coordinator can
remain compatible by never sending it an `ExtensionEvent`. This must be tested;
protobuf's ability to preserve an unknown field is not by itself a negotiation
mechanism.

## Optional and required extensions

Extensions need an explicit requirement policy:

```dart
enum ExtensionRequirement {
  optional,
  requiredForSession,
  requiredForGroup,
}
```

- `optional` covers features that can be skipped without changing protocol
  correctness.
- `requiredForSession` rejects login when the two peers cannot agree on a
  compatible version.
- `requiredForGroup` requires every participant to use the same compatible
  extension profile.

An extension that changes authorization, membership or shared state must not
silently skip unsupported participants. A group-critical extension profile
should be part of durable authenticated group/room policy, including its ID,
major version and configuration hash.

## Registries and dispatch

Client and server runtimes construct registries during startup. A registry
rejects duplicate extension IDs, incompatible version overlaps, duplicate
event numbers, missing codecs and invalid limits before a session starts.

The core domain event family needs only one permanent variant representing the
validated envelope. Client dispatch then has one permanent extension case:

```dart
case ExtensionEvent():
  await extensionRegistry.handle(
    extensionId: event.extensionId,
    version: event.version,
    eventType: event.eventType,
    payload: event.payload,
    context: clientContext,
  );
```

Adding another extension does not modify this switch. The registry selects its
typed codec and handler from the negotiated event key.

## Server emission and routing

A typed extension bus should wrap the existing session routing primitives:

```dart
await extensionBus.sendToOthers<MintingOpportunityFound>(
  extension: MultisigMintingExtension.manifest,
  eventType: MultisigMintingEventType.opportunityFound,
  value: opportunity,
  callerSessionId: sid,
);
```

The bus finds the codec, applies size limits, verifies recipient capabilities
and constructs the envelope. It should expose explicit routing operations for
one session, one participant, all other sessions, all sessions, and all
negotiated participants.

The extension remains responsible for the business decision to emit. If an
event announces a durable mutation, that mutation should normally be persisted
before publishing. RPC replies and persistent-stream events remain on separate
QUIC streams and have no global arrival order.

If no existing RPC causes the event, the extension also needs an authenticated
request path. That includes its request/response schema, operation identifier,
client/server adapters, authorization, resource limits and tests; an event
envelope alone does not create a participant-to-coordinator command.

For multisig minting, that command is the stake finder's authenticated
`announceMintingOpportunity` request. The server verifies membership, payload
limits, candidate identity/signature and basic request structure before routing
the event. Recipients then perform their own chain-dependent validation.

## Multisig minting flow

The proposed extension composes with the existing signing protocol rather than
reimplementing ROAST:

```text
stake-finder participant
  -> finds a candidate for a UTXO controlled by the shared group key
  -> signs the canonical candidate with its participant identity
  -> announceMintingOpportunity extension RPC

coordinator
  -> authenticates the finder and validates bounded structure
  -> emits MintingOpportunityFound to the other negotiated participants

each receiving participant
  -> verifies finder identity and signature
  -> checks the group key and stake input
  -> validates chain context and minting time
  -> reconstructs and reviews the exact signing digests

signing workflow
  -> creates/reviews SignaturesRequestDetails bound to the candidate ID
  -> participants explicitly accept or reject
  -> existing ROAST rounds produce the threshold signatures
  -> application assembles and submits the completed minting result
```

The candidate ID must be bound into the signed proposal or its validated
metadata so a signature request cannot be substituted between two stake finds.
Duplicate candidate IDs are idempotent; conflicting payloads under one ID are a
protocol error. Expired candidates and candidates for an unknown group key are
rejected without starting ROAST.

## Client validation and effects

The registry decodes structure, then an extension handler validates semantics:

```dart
abstract interface class ExtensionEventHandler<T extends Object> {
  Future<ExtensionHandlingResult> handle(
    ExtensionClientContext context,
    T event,
  );
}
```

The handler checks group and sender context, authorization, signatures,
correlation IDs, expiry, replay, duplicates and legal state transitions. A
successfully decoded protobuf does not authorize an application action.

The result explicitly describes whether processing produced no notification,
a client notification, a safe worker projection, a snapshot-visible state
change or a follow-up protocol operation. Not every network extension needs a
public application event.

Extension handlers receive a constrained context rather than unrestricted
access to `Client` internals. They must not extract FROST shares, replace a
coordinator pin, approve a signature or mutate core DKG/ROAST state.

## Application-defined extension packages

An importing application can define an extension, but both ends that use it
must compile and register the same compatible implementation. A useful package
layout is:

```text
peercoin_multisig_minting_extension/
├── lib/
│   ├── wire.dart
│   ├── client.dart
│   ├── server.dart
│   └── flutter.dart
├── proto/
│   └── multisig_minting.proto
└── test/
```

The Flutter wallet imports the client/Flutter parts. An embedded or standalone
coordinator imports the server part. Installing an extension only in the
Flutter app cannot add behavior to a remote coordinator that does not know it.

## Flutter worker projection

The worker runs protocol objects in another isolate. It must validate an
extension before exposing anything to the host. Raw wire payloads should not
automatically cross that boundary because they may contain malformed or secret
data.

One stable worker DTO can carry a separately encoded, sanitized projection:

```dart
final class WorkerProtocolExtensionEvent extends NoosphereWorkerEvent {
  const WorkerProtocolExtensionEvent(
    super.setupId,
    super.generation, {
    required this.extensionId,
    required this.version,
    required this.eventType,
    required this.payload,
  });

  final String extensionId;
  final int version;
  final int eventType;
  final Uint8List payload;
}
```

The handler creates that public projection only after validation and secret
filtering. The worker defensively copies bytes and applies its existing message
limit. The host-side extension decodes the public projection, not the original
network payload.

Repository-owned extensions can use a statically generated built-in registry.
True app-defined extensions need a top-level, AOT-reachable worker bootstrap
that registers codecs and handlers inside the spawned isolate. Arbitrary
closures or runtime plug-in objects should not be sent through isolate ports.

## Delivery and persistence declarations

Every extension declares its delivery model:

```dart
enum ExtensionDeliveryModel {
  transient,
  idempotent,
  stateBacked,
}
```

- `transient` may be lost during disconnection and is suitable only for
  nonessential hints.
- `idempotent` carries an event ID and requires receivers to deduplicate
  application effects.
- `stateBacked` represents durable state that must also appear in reconnect
  snapshots and restoration logic.

The current event stream has no durable offsets, universal replay or generic
acknowledgements. An extension cannot claim durable delivery merely because it
uses that stream. A state-backed extension needs namespaced persistence,
snapshot encoding, restoration behavior and schema migration rules.

## Security and failure behavior

The implementation should fail closed:

- duplicate registry entries fail startup;
- unnegotiated or unknown events fail the affected protocol session;
- payload limits are checked before allocation-intensive decoding;
- codec failures become sanitized protocol errors;
- handlers cannot access unrelated extension state;
- public worker projections contain no private key, FROST share or decrypted
  secret material;
- required extension failures never silently degrade to optional behavior.

Extension payloads inherit Iroh transport confidentiality but remain visible to
the coordinator. Encryption from the coordinator itself requires an explicit
extension design. An extension ID or protobuf schema does not authenticate the
payload's claimed author; the handler must bind identity to the authenticated
session or verify an appropriate signature.

## Versioning

The extension envelope is a long-lived core wire contract. Existing field
numbers must not be renumbered or reused, and removed fields must be reserved.
Each extension separately defines its major-version compatibility policy.

The current repository remains a coordinated public preview. Introducing the
envelope and negotiation still requires one coordinated release. Later
optional extension additions can avoid central wire changes because a server
sends them only after successful negotiation. Changes to core DKG, ROAST or
authorization semantics continue to require an explicit core protocol-version
decision.

## Developer workflow

After the envelope infrastructure exists, adding an optional extension event
should require only:

1. Add the event to the extension's payload schema.
2. Regenerate that extension's bindings.
3. Register its typed codec and limits.
4. Implement its client validation/handler.
5. Add the coordinator emission point and recipient policy.
6. Optionally add a sanitized worker projection.
7. Test negotiation, malformed input, routing, effects and reconnect behavior.

It should not require editing the central `noosphere.proto`, core event
encoder/decoder switches, central client switch, worker DTO switch or core
golden fixtures for every extension.

A scaffold tool could generate a module skeleton and a reusable conformance
suite. That suite should check identifier/type uniqueness, version negotiation,
payload bounds, codec round trips, unknown/unnegotiated rejection, malformed
payloads, worker projection safety and the declared reconnect behavior.

## Implementation phases

1. **Stable envelope and negotiation:** add `ExtensionEvent`, manifests,
   registries, authenticated capability negotiation, limits and repository-owned
   transient extensions.
2. **Client and worker projections:** add handling results, a stable sanitized
   worker DTO and worker message accounting.
3. **State-backed extensions:** add namespaced persistence, snapshot
   contributions, migrations and deduplication support.
4. **Application worker bootstrap:** allow a statically compiled top-level
   application entry point to register third-party extension modules inside the
   worker isolate.

This hybrid model keeps the cryptographic core closed and exhaustively typed
while making optional negotiated features module-local and application-owned.

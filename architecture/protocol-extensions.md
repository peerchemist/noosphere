# Protocol extensions

[Architecture overview](../architecture.md)

> **Status: proposed, not implemented.** The current protocol has a fixed
> protobuf `EventMessage` oneof, sealed domain events and exhaustive handlers.

The proposal keeps DKG, ROAST, recovery and authorization in the coordinated
core while adding one negotiated lane for optional application features.

## Envelope and boundary

```text
ExtensionEvent
├─ extension_id   stable reverse-domain owner
├─ version        negotiated payload version
├─ event_type     positive extension-local number
├─ event_id       optional deduplication key
└─ payload        bounded extension-defined bytes
```

The core would validate the envelope and dispatch it to a registered codec.
The extension would decode and validate the payload. Adding a new extension
would not add another core protobuf field.

| Core event | Extension event |
| --- | --- |
| Login, DKG, ROAST, recovery | Optional application context/discovery |
| Exhaustive core handler | Negotiated registry dispatch |
| May change cryptographic state | Constrained extension context |
| Coordinated Noosphere release | Shared application extension package |

Extensions are not arbitrary Dart objects, dynamically downloaded plugins,
durable queues or a way around signing approval.

## Manifest, codecs and negotiation

Every extension declares:

- a stable reverse-domain ID;
- supported version range;
- maximum payload size;
- numbered event types that are never reused with different meaning; and
- whether support is optional, required for one session or required for the
  whole group.

The effective event key is `(extension ID, negotiated version, event type)`.
A typed codec owns each payload schema and applies an event-specific limit
inside the global message limit.

During authenticated session setup, the client advertises extension/version
ranges and the coordinator chooses at most one compatible version. Negotiated
capabilities must be bound to authentication. The server must not emit an
unnegotiated extension; unknown event types, malformed payloads and oversized
payloads are protocol errors. Group-critical extensions cannot silently skip
unsupported members.

An older client advertises none, allowing a newer coordinator to omit optional
events. Protobuf unknown-field behavior is not capability negotiation.

## Registry and routing

Client/server registries are constructed at startup and reject duplicate IDs,
overlapping registrations, duplicate event numbers and invalid limits. Core
dispatch needs one permanent extension case; the registry selects the typed
codec and handler.

A typed extension bus should route to one session, one participant, all others
or all negotiated participants. If an extension needs participant-to-server
commands, it also needs authenticated RPC operation IDs, request/response
schemas, authorization, limits and tests. An event envelope alone does not add
a command path.

Handlers derive the caller from the authenticated session, never from a sender
field in the payload. If a payload repeats the sender, it must match that
binding.

## Security and delivery

An extension handler receives only constrained context and cannot access
private FROST state, bypass approvals or mutate another extension's storage.
Payload parsing is not authorization. Each extension must define signatures,
group/key binding, expiry, replay protection and semantic validation.

Delivery models must be explicit:

- **transient:** current session delivery only;
- **snapshot-backed:** current extension state included on reconnect; or
- **durable:** namespaced persistence plus acknowledgments, retry and
  deduplication.

The existing event stream alone provides only transient delivery. Event IDs
support deduplication only when the extension defines storage and conflict
rules. Persistence must commit before announcing durable mutations.

Each extension owns its major-version compatibility policy. The core envelope
is a long-lived contract: existing field numbers cannot be repurposed, and
payload limits must be checked before decoding.

## Example: multisig minting

A Peercoin minting extension illustrates the boundary:

1. A participant finds a candidate for an output controlled by the shared key
   and signs canonical candidate bytes with its participant identity.
2. An authenticated extension RPC submits it to the coordinator.
3. The coordinator validates membership and bounded structure, then routes a
   typed discovery event.
4. Recipients verify author, group key, stake input, chain context, time and
   exact signing digests against their own chain view.
5. A normal signing proposal binds the candidate ID and uses the existing
   approval and ROAST flow.

The extension transports discovery and context; it does not authorize a
signature or submit the resulting transaction. Candidate IDs must be
idempotent, with conflicting payloads rejected. The signed candidate should
bind extension/version, room/group, finder, key, input, time and canonical
candidate hash to prevent cross-context replay.

## Application and Flutter integration

An extension package can provide shared models/codecs plus separate client and
server handlers. Both ends must install it; installing only in the UI cannot
teach a coordinator to route it.

The Flutter worker cannot receive arbitrary closures or objects. Extensions
need AOT-reachable registration and explicit public DTO projection. Raw payload
bytes should be decoded and sanitized inside the worker, with message-size
accounting updated for every new DTO.

## Implementation order

1. Add the stable envelope, capability negotiation, manifests and registries.
2. Support bounded transient events and authenticated extension RPCs.
3. Add snapshot-backed/durable contracts only for extensions that need them.
4. Add explicit worker registration and public projection.

Tests must cover negotiation mismatch, unknown types, size limits, malformed
payloads, sender binding, replay/deduplication, routing, reconnect, persistence
ambiguity and worker conversion. Until this infrastructure exists, adding a
network event remains a coordinated core protocol change.

# Packages and source layout

[Architecture overview](../architecture.md)

The root [pubspec](../pubspec.yaml) declares a Dart workspace containing
`packages/*` and `example`. Workspace resolution connects the local packages;
the repository's directory name is not part of the package API.

## Dependency direction

| Package | Location | Owns |
| --- | --- | --- |
| `noosphere` | [`packages/noosphere`](../packages/noosphere) | Domain types, shared configuration, binary codecs, protobuf, framing, room and transition models |
| `noosphere_client` | [`packages/noosphere_client`](../packages/noosphere_client) | Participant state machines, client storage contract, Iroh client, reconnects and enrollment client |
| `noosphere_server` | [`packages/noosphere_server`](../packages/noosphere_server) | Coordinator state machines, server storage contract, Iroh server, rooms and CLI host |
| `noosphere_flutter` | [`lib`](../lib) | Native initialization, direct node, isolate worker, identity provider and Flutter lifecycle |
| Example application | [`example`](../example) | Demonstration UI and explicitly temporary storage |

Both participant and coordinator depend on the shared package. The server's
dependency on the client is a development dependency for tests and examples.
Server production code does not import the participant implementation. The
shared package does not depend on Flutter or Iroh's concrete endpoint API.

## Public entry points

The root [`noosphere_flutter.dart`](../lib/noosphere_flutter.dart) is the normal
application import. It exports worker/node APIs, participant domain APIs,
selected `coinlib` and Iroh public types, and an explicit selection of server
and transport APIs. It does not export every internal transport helper.

| Shared-package import | Main exports |
| --- | --- |
| `package:noosphere/domain.dart` | Domain events, request contract, responses, signing types, Frosty, rooms and transitions |
| `package:noosphere/wire.dart` | Generated protobuf messages/enums, operation IDs, QUIC-varint framing, event conversion and wire constants |
| `package:noosphere/config.dart` | `GroupConfig` and its binary codec |
| `package:noosphere/iroh.dart` | Versioned ALPN strings and relay policy |
| `package:noosphere/common.dart` | Binary helpers, bounded domain reader, expiring maps |
| `package:noosphere/room.dart` | Invites, enrollment contract/transcript and snapshots |
| `package:noosphere/group_transition.dart` | Transition proposal, policy, key plan and approval |

Domain and protobuf names can overlap, for example `DkgAckRequest`. Transport
code uses import prefixes such as `protocol` or explicit `hide` clauses. A
domain object is not interchangeable with a generated message.

[`noosphere_client.dart`](../packages/noosphere_client/lib/noosphere_client.dart)
exports the participant API and shared domain types.
[`iroh_transport.dart`](../packages/noosphere_client/lib/iroh_transport.dart)
adds the direct transport API, endpoint wrapper, configuration, reconnecting
runtime and enrollment transport. Wire messages and codecs are imported
directly from `package:noosphere/wire.dart`. `internals.dart` is implementation
access, not an application state-management API.

[`noosphere_server.dart`](../packages/noosphere_server/lib/noosphere_server.dart)
exports the handler, server, configuration, rooms and persistence contracts.
Each runtime package has a separate `testing.dart`; memory-only persistence is
kept there so production callers make their storage choice explicitly.

## Participant implementation

[`client.dart`](../packages/noosphere_client/lib/src/client/client.dart) owns
the `Client`, its state, caches, event controller and locks. Its private
implementation is divided into Dart `part` files:

| Part | Responsibility |
| --- | --- |
| `client_session.dart` | Authentication, snapshot restoration, session extension |
| `client_dkg.dart` | DKG approval, cryptographic rounds and ACKs |
| `client_signing.dart` | Signing approval, nonce preparation, replies and verification |
| `client_key_sharing.dart` | Explicit encrypted recovery-share exchange |
| `client_events.dart` | Incoming domain-event validation and handling |

These parts contain private extensions in the same Dart library. They do not
create separate services or state owners. `state/` holds internal session,
DKG and signing models. Public projections such as `DkgInProgress` and
`SignaturesRequest` are distinct from those mutable internals.

## Coordinator implementation

[`api_handler.dart`](../packages/noosphere_server/lib/src/server/api_handler.dart)
owns `ServerApiHandler`, storage readiness and persistence failure handling.
Its session, DKG, signing and key-sharing logic is likewise split into parts.
`server/state/` holds the runtime/persistent aggregates and coordination models.

`src/iroh/` translates the shared request contract into network activity:
`server.dart` owns the endpoint; `connection_handler.dart` maps RPCs and drives
the session stream; `connection_context.dart` tracks authenticated bindings;
`dispatcher.dart` serializes mutations by group and uses the shared event codec.
Enrollment has a separate connection handler.

`src/room/manager.dart` owns room transitions. `bin/` is a concrete CLI host.
Its filesystem identity and snapshot stores in `bin/src/` are host adapters,
not hidden persistence defaults of the reusable server library.

## Flutter implementation

[`worker.dart`](../lib/src/worker.dart) is the public host facade.
`worker/command_channel.dart` owns isolate startup, correlation, limits and
shutdown. `worker/provider_registry.dart` reserves application providers and
serializes setup lifecycle changes; `worker/worker_host_setup.dart` dispatches
storage/key requests through per-provider queues.

[`worker_runtime.dart`](../lib/src/worker_runtime.dart) is the isolate entry
point and command router. Its parts implement setup lifecycle, correlated
calls back to the host, and remote storage adapters. Setup lifecycle uses an
injectable node factory; `worker/dto_mapper.dart` owns public projections and
`worker/session_delivery.dart` orders snapshots and replacement-session events.

`worker_protocol.dart` re-exports typed internal envelopes, configuration and
storage codecs, size accounting and a FIFO executor from `worker/`.
`worker_models.dart` defines public sendable DTOs. `iroh_node.dart` composes the
roles; `initialization.dart`, `server_identity_store.dart`, and `lifecycle.dart`
handle platform integration. The example separates session ownership from
screen state, proposal widgets and diagnostics.

## Native and supporting code

The pinned Iroh packages are `iroh_quic 1.0.3` for Dart cores and
`iroh_flutter 1.0.3` for Flutter integration. `coinlib 6.0.1` supplies secp256k1,
hashes, Schnorr signatures, transaction models and binary utilities. Frosty 5.x
supplies FROST cryptographic values and operations. Native assets build/load
the relevant C and Rust libraries.

Noosphere orchestrates these libraries; it does not implement its own QUIC
stack or elliptic-curve arithmetic. The [Iroh](iroh-transport.md) and
[isolate](flutter-and-isolates.md) chapters explain native object ownership.

`linux/`, `macos/`, and the example runners contain desktop/native integration.
`build/` and `.dart_tool/` are generated output. `spec/` contains protocol rules
and some explicit future designs. Server `docs/` also contains historical
migration notes that should not override current implementation behavior.

# Packages and source layout

[Architecture overview](README.md)

Noosphere is a Dart workspace. Dependencies flow from role-specific packages
to the shared protocol package:

| Package | Responsibility |
| --- | --- |
| [`noosphere_protocol`](../../packages/noosphere_protocol) | Domain types, configuration, codecs, protobuf, framing, rooms and transition models |
| [`noosphere_client`](../../packages/noosphere_client) | Participant state machine, storage contract, Iroh client and reconnects |
| [`noosphere_server`](../../packages/noosphere_server) | Coordinator state machine, persistence, Iroh server, rooms and CLI |
| [`noosphere_flutter`](../../packages/noosphere_flutter) | Isolate worker, initialization and Flutter lifecycle |
| [`demo`](../../apps/demo) | Demonstration UI with intentionally temporary storage |
| [`integration_host`](../../apps/integration_host) | Native runners for library end-to-end tests |

Client and server depend on `noosphere_protocol`; the shared package has no concrete
Flutter or Iroh endpoint dependency. The server references the client only in
development tests and examples.

## Public entry points

Applications normally import
[`noosphere_flutter.dart`](../../packages/noosphere_flutter/lib/noosphere_flutter.dart). Lower-level users can
import the role packages directly.

| Import | Purpose |
| --- | --- |
| `package:noosphere_protocol/domain.dart` | Requests, responses, events and signing models |
| `package:noosphere_protocol/wire.dart` | Protobuf, operation IDs, framing and event conversion |
| `package:noosphere_protocol/config.dart` | `GroupConfig` |
| `package:noosphere_protocol/iroh.dart` | ALPN and relay-policy values |
| `package:noosphere_protocol/room.dart` | Room state, participant-bound enrollment invites and clickable invite links |
| `package:noosphere_protocol/group_transition.dart` | Transition proposal and approval models |
| `package:noosphere_client/noosphere_client.dart` | Transport-independent participant API |
| `package:noosphere_client/iroh_transport.dart` | Iroh client and reconnecting runtime |
| `package:noosphere_server/noosphere_server.dart` | Coordinator, rooms and persistence contracts |

Domain and generated protobuf classes can share names but are not
interchangeable. Memory-only persistence is exposed through each package's
`testing.dart`, keeping production storage choices explicit.

## Implementation map

- The private root manifest owns workspace resolution and the shared lockfile.
  Libraries live in `packages/`; runnable Flutter applications live in `apps/`.
- Shared implementation lives under `noosphere_protocol/lib/src/domain/`, `src/wire/`,
  `src/common/`, `src/config/`, `src/room/` and `src/group_transition/`.
  Generated protobuf remains under `src/generated/`. Public entry-point
  libraries export these implementations. Original paths within the package,
  such as `api/events.dart`, remain forwarding exports; shared-package imports
  now use the `package:noosphere_protocol/` namespace.
- Client `part` files divide session, DKG, signing, recovery sharing and event
  handling while sharing one `Client` state owner.
- Server `part` files divide the same protocol areas under
  `ServerApiHandler`; `src/iroh/` handles connections and dispatch, while
  `LocalCoordinatorApi` exposes the same serialized handler in-process.
- [`worker.dart`](../../packages/noosphere_flutter/lib/src/worker.dart) is the Flutter host facade;
  [`worker_runtime.dart`](../../packages/noosphere_flutter/lib/src/worker_runtime.dart) runs inside the
  isolate. `worker/` contains correlation, provider queues, DTO mapping and
  session delivery.
- Each application owns its `linux/` and `macos/` runners. Demo UI tests live
  with the demo; library integration tests live with the integration host.
  `.dart_tool/` and `build/` are generated.
- `deploy/coordinator/` contains the container and its Dart-only workspace
  manifest. `tool/` contains workspace release and consumer checks, while
  protocol generation remains in `packages/noosphere_protocol/tool/`.

Noosphere orchestrates pinned Iroh, Coinlib and Frosty dependencies. It does
not implement QUIC or elliptic-curve arithmetic. See [Iroh transport](iroh-transport.md)
and [Flutter and isolates](flutter-and-isolates.md) for ownership boundaries.

# Packages and source layout

[Architecture overview](../architecture.md)

Noosphere is a Dart workspace. Dependencies flow from role-specific packages
to the shared protocol package:

| Package | Responsibility |
| --- | --- |
| [`noosphere`](../packages/noosphere) | Domain types, configuration, codecs, protobuf, framing, rooms and transition models |
| [`noosphere_client`](../packages/noosphere_client) | Participant state machine, storage contract, Iroh client and reconnects |
| [`noosphere_server`](../packages/noosphere_server) | Coordinator state machine, persistence, Iroh server, rooms and CLI |
| [`noosphere_flutter`](../lib) | Isolate worker, initialization and Flutter lifecycle |
| [`example`](../example) | Demonstration UI with intentionally temporary storage |

Client and server depend on `noosphere`; the shared package has no concrete
Flutter or Iroh endpoint dependency. The server references the client only in
development tests and examples.

## Public entry points

Applications normally import
[`noosphere_flutter.dart`](../lib/noosphere_flutter.dart). Lower-level users can
import the role packages directly.

| Import | Purpose |
| --- | --- |
| `package:noosphere/domain.dart` | Requests, responses, events and signing models |
| `package:noosphere/wire.dart` | Protobuf, operation IDs, framing and event conversion |
| `package:noosphere/config.dart` | `GroupConfig` |
| `package:noosphere/iroh.dart` | ALPN and relay-policy values |
| `package:noosphere/room.dart` | Room state, participant-bound enrollment invites and clickable invite links |
| `package:noosphere/group_transition.dart` | Transition proposal and approval models |
| `package:noosphere_client/noosphere_client.dart` | Transport-independent participant API |
| `package:noosphere_client/iroh_transport.dart` | Iroh client and reconnecting runtime |
| `package:noosphere_server/noosphere_server.dart` | Coordinator, rooms and persistence contracts |

Domain and generated protobuf classes can share names but are not
interchangeable. Memory-only persistence is exposed through each package's
`testing.dart`, keeping production storage choices explicit.

## Implementation map

- Client `part` files divide session, DKG, signing, recovery sharing and event
  handling while sharing one `Client` state owner.
- Server `part` files divide the same protocol areas under
  `ServerApiHandler`; `src/iroh/` handles connections and dispatch, while
  `LocalCoordinatorApi` exposes the same serialized handler in-process.
- [`worker.dart`](../lib/src/worker.dart) is the Flutter host facade;
  [`worker_runtime.dart`](../lib/src/worker_runtime.dart) runs inside the
  isolate. `worker/` contains correlation, provider queues, DTO mapping and
  session delivery.
- `linux/`, `macos/` and example runners contain platform integration.
  `.dart_tool/` and `build/` are generated.

Noosphere orchestrates pinned Iroh, Coinlib and Frosty dependencies. It does
not implement QUIC or elliptic-curve arithmetic. See [Iroh transport](iroh-transport.md)
and [Flutter and isolates](flutter-and-isolates.md) for ownership boundaries.

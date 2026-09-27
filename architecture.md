# Architecture

## Source organization

The root `noosphere_flutter` package is the wallet-facing library. The packages
under `packages/` own the shared protocol, participant and coordinator code.
Tests of domain types and group configuration live in `noosphere/test`; client
model tests live in `noosphere_client/test`. Client/server interaction tests
remain in the server package, which depends on the client only for development.

`Client` and `ServerApiHandler` keep their public methods and state ownership.
Their private implementations are grouped into Dart library parts for sessions,
DKG, signing, key sharing and client event handling. These parts use private
extensions, so they introduce no public API or additional state owners. Client
locks remain attached to the same client or operation state, and every server
operation uses the same preparation and persistence path.

The Flutter worker separates command handling from setup lifecycle, host
request correlation and persistence adapters in `lib/src/worker/`. Host-side
provider queues remain shared across worker lifetimes within the host isolate;
moving their declarations into a library part does not change that lifetime.

## Storage ownership

- Noosphere does not provide or own a persistent storage backend.
- Noosphere exposes domain-specific host interfaces for loading and persisting
  the state its protocols require. It does not define a generic storage layer.
- The embedding host (a Flutter application or a headless service) implements
  durable, encrypted storage behind that interface. Sygnature is one such host.
- The noosphere runtime may keep caches and active challenges in memory.
- Every security-sensitive state transition must be persisted successfully
  through the host interface before the new state is published or used.
- After a restart, noosphere reconstructs its state machines exclusively from
  the records returned by the host through the storage interface.

This boundary keeps storage policy, encryption, and key custody in the host
application while leaving record semantics and state-machine validation in
noosphere.

## Identity and adapter boundaries

- `IrohServer.start` requires a host-supplied `SecretKey`; identity loading and
  creation are owned by the explicit host provider instance and its lifecycle.
- `IrohConfig` describes transport/runtime configuration and contains no storage
  paths. The CLI owns `secret-key-path` and its file-backed identity provider in
  `packages/noosphere_server/bin/src/identity_file.dart`.
- Flutter uses its host-owned `ServerIdentityStore`. The application must prevent
  multiple processes from independently creating or replacing one identity;
  Flutter's existing in-memory identity registry only coordinates its host isolate.
- `RoomManager.open` requires an explicit `RoomPersistence`. Memory-only
  implementations live behind the packages' separate `testing.dart` entry
  points and are not exported by production entry points.
- The Flutter worker keeps `RoomPersistence` on the host and proxies `loadAll`
  and `write`. A write reply is sent only after the provider completes. Room and
  client storage operations share the setup's serial queue. A timed-out provider
  may still complete; timeout does not cancel its transaction. After a room
  write failure the worker blocks further room writes until the server role is
  reopened and its manager reloaded. The same host provider instance shares an
  ordering queue across worker lifetimes, so replacement reads wait for old
  writes. Hosts using different provider instances or processes must enforce
  that ordering themselves.
- Runtime-only state (connections, timers, challenges and rebuildable caches)
  may remain in memory. Recreating a runtime must not require a surviving cache.

## Implementation status

`ClientStorageInterface`, `RoomPersistence`, `ServerPersistence` and
`ServerIdentityStore` connect the runtime to host-owned persistence. Database
backends, encryption and transaction implementation belong to wrappers.

## Restart behavior

| Record at shutdown | Recovery behavior |
| --- | --- |
| Sessions, connections, challenges, online status and ACK caches | Discarded; clients authenticate again. |
| In-progress DKG | Durably marked interrupted before startup; its name stays blocked until expiry and delayed round messages are rejected. |
| In-progress signing | Durably marked blocked before startup; its request ID cannot be reused and delayed replies cannot advance it. |
| Completed signatures | Restored and delivered again on login until expiry. |
| Unacknowledged encrypted key shares | Restored and delivered again on login. |
| Prepared client signing operation | Remains blocked until a response is known; its nonce replacement and operation record are one atomic host transaction. |
| Durable client rejection | Re-sent after reconnect; cache and events never precede its write. |

Server and room writes use one serialized lane per concrete provider across
worker lifetimes. A timeout does not cancel a host transaction. If a reply is
lost, that runtime blocks further mutations; a replacement waits for the old
write and reloads durable state before accepting requests.

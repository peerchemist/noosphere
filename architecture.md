# Architecture

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

- `IrohServer.start` requires a host-supplied `SecretKey`.
  `startWithSecretKey` remains an equivalent embedding entry point.
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

`ClientStorageInterface`, `RoomPersistence` and `ServerIdentityStore` connect the
runtime to host-owned persistence. Server DKG/ROAST state still needs to be
externalized through domain-specific host interfaces. Persistent server state,
uniform commit-before-publish transitions and complete recovery of in-flight
protocol operations are still required to meet the full storage ownership model
above. Database backends and transaction implementation belong to the wrappers.

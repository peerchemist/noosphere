# Noosphere Server for ROAST Threshold Signatures

This package is an Iroh-native fork of the original `noosphere_server`
package. It retains the coordinator role for FROST distributed key generation
and ROAST threshold signatures, while replacing the original gRPC transport
with authenticated Iroh QUIC connections.

The fork contains no gRPC server, generated gRPC stubs, or gRPC configuration.
Instead, it owns the Iroh endpoint lifecycle, accepts a stable identity from
the application wrapper, and serves the protocol over dedicated ALPNs with
direct connectivity and relay fallback. Applications migrating from the
original package must use the Iroh configuration and bootstrap model described
below.

The `noosphere_server.dart` entry point exports server configuration, the
coordinator API, Iroh server lifecycle, room management and host persistence
contracts. Connection contexts, dispatchers, connection handlers and wire
conversion helpers under `lib/src/iroh/` are internal implementation details.

The package contains no CLI, filesystem persistence or YAML parsing. The
application wrapper constructs `GroupConfig`, `ServerConfig` and `IrohConfig`,
supplies identity keys and implements the persistence contracts.

## Native development setup

This branch requires Dart 3.13, the published Frosty 5.0.1 native-assets
release, and Coinlib 6.0.1. Install Iroh's signed native library with:

```sh
dart pub get
dart run iroh_quic:setup
```

Set `IROH_NATIVE_LIBRARY` to the cached `libirohdart_ffi.so` if it is not on the
platform loader path. Frosty and Coinlib provide their native libraries through
Dart native assets.

## Embedding the server

Applications that manage the Iroh identity themselves can start the server
without filesystem access:

```dart
final server = await IrohServer.start(
  config,
  secretKey: persistedSecretKey,
  persistence: durableServerPersistence,
);
unawaited(server.serve());
```

`start(config, secretKey: key, persistence: provider)` requires an identity and
domain-specific server persistence supplied by the host, and performs no
identity storage I/O. A host may deterministically derive that identity or load
it according to its own policy before starting the server.
`IrohConfig` no longer accepts
`secretKeyPath`; remove that argument from embedding code and load the key in
your wrapper instead.

The wrapper must implement `ServerPersistence.write` as an atomic durable
replacement and must fail startup when loading fails. Database, secure-storage,
backup and retention policy belong entirely to that wrapper.

`RoomManager.open` requires an explicit `RoomPersistence` provider. Tests and
examples can import `package:noosphere_server/testing.dart` and pass
`InMemoryRoomPersistence()` explicitly. It is not exported by
`noosphere_server.dart`; production hosts implement durable persistence.

## In-process participants

An embedded coordinator can serve a participant in the same process without a
second Iroh endpoint or a loopback QUIC connection. `IrohServer.openLocalApi`
opens a local session only for a group already hosted by that server. Calls use
the same per-group dispatcher queue as remote Iroh participants, and retain the
ordinary challenge authentication, session lifecycle, persistence, and event
ordering.

The Flutter facade selects this path when the client's pinned coordinator ID
equals the active server ID and its group fingerprint identifies an active
base or frozen-room handler. Iroh remains active for every remote participant.

## Protocol and migration

The shared domain types, CDDL schema, typed wire messages and framing
live in the sibling `noosphere_protocol` package. The server has no production
dependency on `noosphere_client`; that package is used only by end-to-end tests
and examples. The 3.0.0 server and 4.0.0 client remove gRPC completely. Migrate
by replacing
`GrpcClientApi`/`GrpcConfig` with `IrohClientApi`/`IrohConfig`, pinning the
server endpoint ID and persistently loading or deterministically deriving the
same server identity key. Canonical domain
bytes are carried inside CBOR byte strings; the transport and session semantics
are breaking changes. Enrollment and ROAST use separate versioned ALPNs,
operation-prefixed QUIC streams, concrete CBOR bodies, and FIN boundaries.

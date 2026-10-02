# Noosphere Server for ROAST Threshold Signatures

**Coordinated public preview.** Deploy matching tested package versions across
all peers. Protocol v1 does not promise compatibility between preview builds;
see the [version policy](../noosphere/spec/VERSIONING.md).

This package is an Iroh-native fork of the original `noosphere_server`
package. It retains the coordinator role for FROST distributed key generation
and ROAST threshold signatures, while replacing the original gRPC transport
with authenticated Iroh QUIC connections.

The fork contains no gRPC server, generated gRPC stubs, or gRPC configuration.
Instead, it owns the Iroh endpoint lifecycle, uses a persistent Iroh identity,
and serves the protocol over dedicated ALPNs with direct connectivity and relay
fallback. Applications migrating from the original package must use the Iroh
configuration and bootstrap model described below.

The `noosphere_server.dart` entry point exports server configuration, the
coordinator API, Iroh server lifecycle, room management and host persistence
contracts. Connection contexts, dispatchers, connection handlers and wire
conversion helpers under `lib/src/iroh/` are internal implementation details.

YAML parsing belongs only to the standalone CLI in `bin/src/config.dart`.
Embedded callers construct `GroupConfig`, `ServerConfig` and `IrohConfig`
directly. The shared and client libraries have no YAML conversion API.

## Run the server

Copy `config/iroh-server.example.yaml`, replace the group and participant keys,
and keep `secret-key-path` on durable storage. The file contains relay,
deadline and resource-limit settings with production defaults.

```sh
dart run noosphere_server:iroh_server --config config.yaml
```

At startup the CLI prints:

```text
Iroh endpoint ID is <full-hex-id>
IROH_SERVER_READY <full-hex-id> <base64url-address>
```

Distribute the full endpoint ID through a trusted channel so clients can pin
it independently from address hints. Preserve the secret key file across
restarts: replacing it changes the endpoint ID. SIGINT and SIGTERM stop
accepting connections and perform bounded graceful shutdown.

The default relay policy permits direct connectivity and n0 relay fallback.
Set `relay.policy` to `disabled`, `staging`, or `custom`; a custom policy also
requires a `relay.urls` list.

## Container

The multi-stage image consumes the protocol, client and server packages from
the same workspace revision. It pins the Dart and Rust toolchains, lets Dart's
native-asset hooks build Frosty and Coinlib from the locked dependencies,
installs Iroh's signed upstream prebuilt, and bundles the AOT-compiled CLI with
all three required native libraries.

```sh
podman build -f packages/noosphere_server/Containerfile -t noosphere-server .
podman run --rm \
  -v noosphere-identity:/var/lib/noosphere \
  -v "$PWD/config.yaml:/config/server.yaml:ro,Z" \
  noosphere-server
```

The named `/var/lib/noosphere` volume preserves the server identity. No fixed
inbound port is exposed because Iroh binds dynamic UDP sockets and can use the
configured relay. Direct-only container deployments must publish the actual
UDP socket through deployment-specific networking.

Run the build from the monorepository root so all local package sources are in
the Docker build context.

## Native development setup

This branch requires Dart 3.13, the published Frosty 5.0.0 native-assets
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
identity storage I/O. Persist a new identity before starting the server.
`IrohConfig` no longer accepts
`secretKeyPath`; remove that argument from embedding code and load the key in
your wrapper instead.

The standalone CLI still accepts `secret-key-path` in its YAML. Its provider
lives under `bin/src/`, serializes cooperating processes with a file lock and
writes the identity with mode 0600 on POSIX. Database, secure-storage and backup
policy for other hosts belongs to those hosts.

The CLI stores protocol snapshots under `state-directory` (default:
`<config-path>.state`). Embedders must implement `ServerPersistence.write` as
an atomic durable replacement and must fail startup when loading fails.

`RoomManager.open` requires an explicit `RoomPersistence` provider. Tests and
examples can import `package:noosphere_server/testing.dart` and pass
`InMemoryRoomPersistence()` explicitly. It is not exported by
`noosphere_server.dart`; production hosts implement durable persistence.

## Protocol and migration

The shared domain types, protocol schema, generated message classes and framing
live in the sibling `noosphere` package. The server has no production
dependency on `noosphere_client`; that package is used only by end-to-end tests
and examples. The 3.0.0 server and 4.0.0 client remove gRPC completely. Migrate
by replacing
`GrpcClientApi`/`GrpcConfig` with `IrohClientApi`/`IrohConfig`, pinning the
server endpoint ID and persisting the server identity key. Canonical domain
bytes are carried inside protobuf messages; the transport and session semantics
are breaking changes. Enrollment and ROAST share the protobuf envelope and
framing on separate ALPNs.

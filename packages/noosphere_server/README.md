# Noosphere Server for ROAST Threshold Signatures

This package coordinates FROST distributed key generation and ROAST threshold
signatures over authenticated Iroh QUIC connections.

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
podman build -f packages/noosphere_server/Dockerfile -t noosphere-server .
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

This branch requires Dart 3.13, Frosty 4.0.0 from the pinned FRB 2.12 commit
and Coinlib 6.0.1. Install Iroh's signed native library with:

```sh
dart pub get
dart run iroh_quic:setup
```

Set `IROH_NATIVE_LIBRARY` to the cached `libirohdart_ffi.so` if it is not on the
platform loader path. Frosty and Coinlib must likewise be able to locate
`libfrosty_rust` and the standard secp256k1 0.5.0 `libsecp256k1`.

## Embedding the server

Applications that manage the Iroh identity themselves can start the server
without filesystem access:

```dart
final server = await IrohServer.startWithSecretKey(
  config,
  secretKey: persistedSecretKey,
);
unawaited(server.serve());
```

`startWithSecretKey` does not read or write `IrohConfig.secretKeyPath`. This is
the preferred entry point for Flutter hosts that keep the 32-byte secret in
platform secure storage. The existing `start` method retains file-backed,
mode-0600 identity management for CLI and container deployments.

## Protocol and migration

The protocol schema, generated message classes and framing live in the sibling
`noosphere` package. The 3.0.0 server and 4.0.0 client remove gRPC completely.
Migrate by replacing
`GrpcClientApi`/`GrpcConfig` with `IrohClientApi`/`IrohConfig`, pinning the
server endpoint ID and persisting the server identity key. Existing serialized
domain messages retain their protobuf field numbers; the transport and session
semantics are breaking changes.

The legacy REST adapter is outside this migration and is unchanged.

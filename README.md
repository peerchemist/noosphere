# noosphere_flutter

Flutter lifecycle adapter for the Noosphere ROAST client and server. It can run
a reconnecting client, an embedded server, or both roles without copying the
core protocol, Protobuf, framing, DKG, or signing implementations.

The production default remains a durable external server with Flutter clients.
An embedded server is available only while its Linux or macOS process is
alive.

## Supported toolchain and pins

- Dart `^3.13.0` and Flutter `>=3.47.0`.
- Linux desktop with GTK 3 and CMake 3.13 or newer.
- macOS 12.0 or newer.
- `noosphere_roast_server >=3.0.0 <4.0.0`.
- `noosphere_roast_client >=4.0.0 <5.0.0`.
- `iroh_flutter 1.0.3`; its `iroh_quic 1.0.3` dependency remains the core API.
- `coinlib_flutter >=4.0.0 <5.0.0`.
- `frosty` and `frosty_flutter` from commit
  `dd921490f0cd6696328e89b18de767d87ed680a4` until a published Frosty 4.x
  release is known to use Flutter Rust Bridge 2.12.
- `record_use ^1.1.1`; the reachable initialization entry point is marked with
  `@RecordUse` for Dart 3.13's recorded-use/native-link pipeline.

Only Linux and macOS runners are present. Android, iOS, Windows, and web are
not supported in this release.

## Required application override

Dependency overrides do not propagate from packages. Every consuming
application must pin both Frosty packages to the same commit:

```yaml
dependency_overrides:
  frosty:
    git:
      url: https://github.com/peercoin/frosty.git
      ref: dd921490f0cd6696328e89b18de767d87ed680a4
      path: frosty
  frosty_flutter:
    git:
      url: https://github.com/peercoin/frosty.git
      ref: dd921490f0cd6696328e89b18de767d87ed680a4
      path: frosty_flutter
```

This repository's `pubspec_overrides.yaml` additionally points both Noosphere
packages at the sibling repositories during local development. The published
constraints stay in `pubspec.yaml`.

## Initialization and roles

```dart
await NoosphereFlutter.initialize();

final node = await NoosphereNode.start(
  server: EmbeddedServerOptions(
    serverConfig: serverConfig,
    identityStore: identityStore,
  ),
  client: ClientNodeOptions(
    clientConfig: clientConfig,
    bootstrapAddress: trustedAddress,
    pinnedServerId: trustedServerId,
    storage: durableClientStorage,
    getPrivateKey: getPrivateKeyFromSecureStorage,
  ),
);

final initialClient = node.client?.current;
final replacements = node.client?.sessions;

await node.close();
```

Initialization is idempotent and concurrent callers share the same in-flight
future. Native library paths are intentionally not configurable: the Flutter
plugins bundle and load the libraries.

For both roles, the server starts first and the client uses its own endpoint.
The client requires an independently trusted pinned Iroh ID. Its
`bootstrapAddress` may contain only that ID and rely on Iroh discovery, or add
direct/relay address hints. Listen to `ReconnectingIrohClient.sessions` and
replace any cached `Client` when a new authenticated session arrives.
Reconnection never retries an in-flight mutating DKG or signing RPC.

`NoosphereLifecycleObserver` optionally attempts a bounded close on the
terminal `detached` lifecycle state. It does not close on `inactive`, because a
desktop window may merely have lost focus. Applications remain responsible for
explicitly calling `close()` during logout and shutdown.

## Persistence and key custody

Implement `ServerIdentityStore` with the OS keychain or keystore. It stores
exactly 32 bytes losslessly. Node startup uses
`IrohServer.startWithSecretKey`; the core config's
`host-managed://iroh-secret` sentinel is never read or written and no external
`chmod` process is launched by this package.

Production client calls must provide both `ClientStorageInterface` and
`GetPrivateKey`. Do not put participant private keys in preferences or logs.
A durable client store must implement `prepareSignaturesOperation` as one
database transaction that atomically:

1. stores the prepared operation; and
2. replaces every corresponding nonce index;

before the network request can proceed. A crash or ambiguous network outcome
must leave that prepared record present so the operation cannot be replayed.
`InMemoryClientStorage` does not satisfy production durability requirements.

## Example and verification

The `example/` app has client-only, embedded-server-only, and both-role modes.
It connects through Iroh discovery using the server's Iroh ID, displays each
ROAST participant public key, and prints public addresses, sessions, events,
and errors to the terminal, never private keys. Its in-memory persistence is
called out visibly in the UI.

```sh
flutter analyze
flutter test test
flutter test integration_test/native_transport_test.dart -d linux
flutter test integration_test/roast_2_of_2_test.dart -d linux

cd example
flutter analyze
flutter build linux --release
```

Run the equivalent integration test and `flutter build macos --release` on a
macOS runner. The integration test uses real Iroh QUIC transport to verify
authentication, initial snapshot delivery, live events, identity-preserving
restart, reconnect session replacement, non-replay of a disconnected mutation,
and clean shutdown.

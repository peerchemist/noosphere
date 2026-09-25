# Noosphere

Reference implementation of the Noosphere protocol. This repository is a Dart
workspace containing the canonical protocol schema, participant and
coordinator implementations, and the Flutter facade used by end-user apps.

| Package | Responsibility |
| --- | --- |
| `noosphere` | Shared ROAST domain model, configuration, protobuf messages and framing |
| `noosphere_client` | Participant state, persistence and Iroh client transport |
| `noosphere_server` | Coordinator state, Iroh server and standalone CLI |
| `noosphere_flutter` | Flutter lifecycle and isolate facade for both roles |

Both `noosphere_client` and `noosphere_server` depend on `noosphere` directly.
The server has no production dependency on the client; it references the client
only from integration tests and examples through a dev dependency.

The root package is `noosphere_flutter`; the repository directory can be
renamed without changing workspace resolution.

## Flutter facade

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
- `noosphere_server >=3.0.0 <4.0.0`.
- `noosphere_client >=4.0.0 <5.0.0`.
- `iroh_flutter 1.0.3`; its `iroh_quic 1.0.3` dependency remains the core API.
- `coinlib 6.0.1`, which builds secp256k1 through Dart native assets.
- `frosty` from `peerchemist/frosty` branch `refactor/native-assets`, which
  builds its Rust library through Dart native assets. The deprecated
  `coinlib_flutter` and the former `frosty_flutter` plugin are not used.
- `record_use ^1.1.1`; the reachable initialization entry point is marked with
  `@RecordUse` for Dart 3.13's recorded-use/native-link pipeline.

Only Linux and macOS runners are present. Android, iOS, Windows, and web are
not supported in this release.

## Required application override

Dependency overrides do not propagate from packages. Every consuming
application must select Frosty's native-assets branch until it is published:

```yaml
dependency_overrides:
  frosty:
    git:
      url: https://github.com/peerchemist/frosty.git
      ref: refactor/native-assets
      path: frosty
```

This workspace keeps the override once at its root. Local Noosphere packages
are resolved as workspace members while their version constraints remain
explicit in each `pubspec.yaml`.

## Worker facade (recommended for Flutter UI)

```dart
await NoosphereFlutter.initialize();

final worker = await NoosphereWorker.start();
final subscription = worker.events.listen((event) {
  // Subscribe before startSetup: every client session begins with a snapshot.
});

final snapshot = await worker.startSetup(
  setupId: 'primary-wallet',
  identityStorageId: 'main-coordinator', // stable across worker instances
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

await worker.requestDkg('primary-wallet', proposal);

// Consent is bound to the exact public proposal received from the worker.
await worker.acceptDkg('primary-wallet', reviewedDkg);
await worker.acceptSignatures('primary-wallet', reviewedSigningRequest);

// Stop local key use without stopping an embedded coordinator.
await worker.lockSigner('primary-wallet');

await worker.close();
await subscription.cancel();
```

`NoosphereWorker` owns a long-lived Dart isolate and can own several setup IDs.
Each setup has independent server and signer roles. Calling `startSetup` again
for an existing setup can add the missing role; `stopSetup` can stop `server`,
`signer`, or `both`. Share one worker between accounts derived from the same
setup instead of creating an isolate per wallet.

The transport is versioned and carries primitives, byte arrays and deliberate
public DTOs only. Native handles, `Client` objects, callbacks and database
objects never cross the isolate boundary. Replies carry command and worker
generation IDs; stale replies are ignored, payload size and outstanding-command
counts are bounded, and pending commands fail if the isolate exits. A
replacement reconnecting session emits `WorkerSessionReplacedEvent` followed
by a fresh `WorkerSnapshotEvent`; mutating RPCs are never replayed.
Graceful close is idempotent. Forced or unexpected native-worker termination
marks in-process restart unsafe; restart the application rather than assuming
native sockets/tasks were released.

Subscribe to `events` before starting setups. A session snapshot is ordered
before later events from that session. The stream is a broadcast controller
bridge because the native source is imperative; events are not accumulated into
a list.

`NoosphereFlutter.initialize()` remains idempotent and initializes root-isolate
Flutter plus native bindings for direct-node callers and host code that handles
Frosty storage values. `NoosphereWorker.start()` only prepares the root Flutter
binding; its isolate calls `NoosphereFlutter.initializeNative()` without
touching `WidgetsFlutterBinding`. Native library paths remain internal so the
macOS Iroh/Frosty FRB symbol namespaces stay isolated.

The original direct API remains available:

```dart
final node = await NoosphereNode.start(
  server: serverOptions,
  client: clientOptions,
);
final initialClient = node.client?.current;
final replacements = node.client?.sessions;
await node.close();
```

The client always requires an independently trusted pinned Iroh ID. Its
`bootstrapAddress` may contain only that ID and rely on Iroh discovery, or add
direct/relay hints. Direct API consumers must replace cached `Client` objects
from `ReconnectingIrohClient.sessions`.

Flutter clients default to two concurrent RPC streams. The long-lived session
event stream is separate. Embedded servers accept four simultaneous streams per
client connection by default: one event stream, two RPC streams, and one slot
of transition headroom. Both limits remain configurable through
`ClientNodeOptions` and `EmbeddedServerOptions`; the server limit is an
independent protection against a faulty or hostile client.

`NoosphereLifecycleObserver` and `NoosphereWorkerLifecycleObserver` optionally
attempt a bounded close on terminal `detached`. They do nothing on `inactive`,
because a desktop window may merely have lost focus. Explicitly await node or
worker shutdown during logout/application shutdown whenever possible.

## Persistence and key custody

Implement `ServerIdentityStore` with the OS keychain or keystore. It stores
exactly 32 bytes losslessly. Give each coordinator store a stable
`identityStorageId`; creation is serialized by this ID across worker instances.
Node startup uses `IrohServer.startWithSecretKey`; the core config's
`host-managed://iroh-secret` sentinel is never read or written and no external
`chmod` process is launched by this package.

Production client calls must provide both `ClientStorageInterface` and
`GetPrivateKey`. The worker keeps these application-owned providers on the host
isolate and invokes them through correlated requests. Storage operations for a
setup are serialized. `prepareSignaturesOperation` remains one proxy call, and
the worker waits for durable completion before sending the network request.

A provider timeout reports an unknown outcome and is never blindly retried.
Reconcile the durable prepared-operation record before allowing another signing
attempt. Key requests are scoped internally to setup ID, `KeyPurpose`, and
worker generation. Returning a key is not user consent: approve only the exact
`WorkerDkgStatus` or `WorkerSigningRequest` reviewed by the user. Canonical
proposal bytes are echoed on approval and stale or changed proposals are
rejected. Secret bytes are absent from public events, logs and errors. Ordinary
Dart-managed memory cannot guarantee reliable zeroization.

A durable client store must implement `prepareSignaturesOperation` as one
database transaction that atomically:

1. stores the prepared operation; and
2. replaces every corresponding nonce index;

before the network request can proceed. A crash or ambiguous network outcome
must leave that prepared record present so the operation cannot be replayed.
`InMemoryClientStorage` does not satisfy production durability requirements.

`shareKeySecret` is deliberately absent from `NoosphereWorker`; recovery needs
a separate explicit workflow. DKG temporary secrets and embedded-server
protocol sessions are in memory. After an unexpected exit, recreate sessions
from durable state, reconcile completed keys/prepared signing records, and do
not assume an unfinished mutation continued.

An isolate is not an OS service, native-crash boundary, or security boundary.
Closing the desktop app stops its embedded coordinator. Android/iOS background
execution remains outside this package's Linux/macOS scope.

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
flutter test integration_test/worker_roast_test.dart -d linux

cd example
flutter analyze
flutter build linux --release
```

Run the equivalent integration test and `flutter build macos --release` on a
macOS runner. The integration test uses real Iroh QUIC transport to verify
authentication, initial snapshot delivery, live events, identity-preserving
restart, reconnect session replacement, non-replay of a disconnected mutation,
and clean shutdown.

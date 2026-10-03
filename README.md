# Noosphere

**Coordinated public preview.** Deploy matching tested package versions across
all peers. Protocol v1 does not promise compatibility between preview builds;
see the [version policy](packages/noosphere/spec/VERSIONING.md).

Reference implementation of the Noosphere protocol. This repository is a Dart
workspace containing the canonical protocol schema, participant and
coordinator implementations, and the Flutter facade used by end-user apps.

| Package | Responsibility |
| --- | --- |
| `noosphere` | Shared ROAST domain model, configuration, protobuf messages and framing |
| `noosphere_client` | Participant state, persistence and Iroh client transport |
| `noosphere_server` | Coordinator state, Iroh server and standalone CLI |
| `noosphere_flutter` | Flutter lifecycle and isolate facade for both roles |

Pubkey-bound room enrollment is documented in
[`packages/noosphere/spec/ROOM_ENROLLMENT.md`](packages/noosphere/spec/ROOM_ENROLLMENT.md).

Both `noosphere_client` and `noosphere_server` depend on `noosphere` directly.
The server has no production dependency on the client; it references the client
only from integration tests and examples through a dev dependency.

The root package is `noosphere_flutter`; the repository directory can be
renamed without changing workspace resolution.

Wallets import `package:noosphere_flutter/noosphere_flutter.dart` for the
worker and node APIs, domain models, configuration and host persistence
interfaces. This entry point explicitly selects its server and transport
exports; connection handlers, dispatchers and wire conversion helpers remain
implementation details. Direct RPC and endpoint consumers import
`package:noosphere_client/iroh_transport.dart` explicitly.

## Threshold HD derivation

The `noosphere` domain package owns threshold-key HD derivation so wallet
applications and signing participants cannot implement different key paths.
`thresholdBip86DerivationPath` builds the unhardened threshold equivalent of
the BIP-86 purpose, coin, account, change and address-index hierarchy, while
`deriveThresholdGroupKey` derives its public group key. `SingleSignatureDetails`
uses the same underlying helper when deriving participant and aggregate signing
information.

FROST has no aggregate private key, so hardened BIP-32 derivation is not
possible. Consuming wallets provide their registered coin type and account
indexes, persist the exact returned path and remain responsible for converting
the derived group key into a chain-specific address.

## Flutter facade

Flutter lifecycle adapter for the Noosphere ROAST client and server. It can run
a reconnecting client, an embedded server, or both roles without copying the
core protocol, Protobuf, framing, DKG, or signing implementations.

The production default remains a durable external server with Flutter clients.
An embedded server is available only while its Linux or macOS process is
alive.

Using the Flutter package as a headless server may also be possible, but this
has not been tested. Its headless deployment and operational workflow has not
yet been designed or evaluated.

## Supported toolchain and pins

- Dart `^3.13.0` and Flutter `>=3.47.0`.
- Linux desktop with GTK 3 and CMake 3.13 or newer.
- macOS 12.0 or newer.
- `noosphere_server >=3.0.0 <4.0.0`.
- `noosphere_client >=4.0.0 <5.0.0`.
- `iroh_flutter 1.0.3` and its published `iroh_quic 1.0.3` dependency.
- `coinlib 6.0.1`, which builds secp256k1 through Dart native assets.
- `frosty 5.0.0`, which builds its Rust library through Dart native assets.
  The deprecated
  `coinlib_flutter` and the former `frosty_flutter` plugin are not used.
- `record_use ^1.1.1`; the reachable initialization entry point is marked with
  `@RecordUse` for Dart 3.13's recorded-use/native-link pipeline.

Only Linux and macOS runners are present. Android, iOS, Windows, and web are
not supported in this release.

## Worker facade (recommended for Flutter UI)

```dart
await NoosphereFlutter.initialize();

final worker = await NoosphereWorker.start();
final subscription = worker.events.listen((event) {
  // Subscribe before startSetup: every client session begins with a snapshot.
});

final snapshot = await worker.startSetup(
  setupId: 'primary-wallet',
  server: EmbeddedServerOptions(
    serverConfig: serverConfig,
    identityStore: identityStore,
    serverPersistence: durableServerPersistence,
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

// Refresh direct/relay hints after a coordinator moves. Its pinned ID stays fixed.
await worker.updateSignerAddress('primary-wallet', refreshedAddress);

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

When one setup hosts the coordinator and signer for the same group, startup
matches the pinned coordinator ID and group fingerprint against the running
server. The signer then uses the server's serialized in-process API rather than
binding a second Iroh endpoint and connecting back to itself over QUIC. The
server keeps its Iroh endpoint for remote participants. `snapshot.connected`
has the same meaning for local and remote signer sessions.

Await lifecycle calls for a setup before starting another start, stop, or
coordinator switch. Overlapping lifecycle calls for the same setup fail with
`setup_busy`; calls for different setups remain independent.

The internal worker channel carries typed envelopes, encoded fields and
public DTOs. Native handles, `Client` objects, callbacks and database
objects never cross the isolate boundary. Replies carry command and worker
generation IDs; stale replies are ignored, payload size and outstanding-command
counts are bounded, and pending commands fail if the isolate exits. A
replacement reconnecting session emits a fresh `WorkerSnapshotEvent` followed
by `WorkerSessionReplacedEvent`; mutating RPCs are never replayed.
`updateSignerAddress` accepts only an address with the existing pinned
coordinator ID.
For an app-approved change of coordinator identity, use
`worker.switchCoordinator(setupId, newCoordinator: address, persist: saveSelection)`.
It retains the group and FROST keys, stops the old session, checks pending signing
state and awaits durable pin storage before connecting. This is a serialized,
non-atomic sequence; success confirms only the local signer's connection.
See [coordinator switching](packages/noosphere/spec/COORDINATOR_ROTATION.md) for the
host workflow, responsibility boundary and recovery after partial failure.
Graceful close is idempotent. Forced or unexpected native-worker termination
marks in-process restart unsafe; restart the application rather than assuming
native sockets/tasks were released.

Rust tracks Iroh reactive-stream cancellation tokens process-wide while Dart
statics are isolate-local. The worker therefore reads the public endpoint
address snapshot on a short timer instead of opening an Iroh reactive stream.
Direct nodes retain the ordinary published Iroh API, and consuming apps need no
dependency override or patched package.

Subscribe to `events` before starting setups. A session snapshot is ordered
before later events from that session. The stream is a broadcast controller
bridge because the native source is imperative; events are not accumulated into
a list. A locally completed DKG emits `WorkerKeyUpdatedEvent` only after its
FROST key has been durably stored. The event's public `key` includes the group
key, name and description but no secret share. The same event is also used when
secret-sharing changes a stored key; use `WorkerSnapshotEvent.snapshot.keys`
for the complete key set at session start.

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

The combined call selects the in-process path automatically when the client pin
and group match the server it just started. To attach a signer after creating
and freezing a room, pass the already-running server explicitly:

```dart
final signerNode = await NoosphereNode.start(
  client: roomClientOptions,
  localCoordinator: coordinatorNode.server,
);
assert(signerNode.client!.isLocal);
```

If the coordinator ID or group fingerprint does not match, startup uses the
ordinary Iroh transport. Detection never relies on IP addresses or discovery.

The client always requires an independently trusted pinned Iroh ID. Its
`bootstrapAddress` may contain only that ID and rely on Iroh discovery, or add
direct/relay hints. Direct API consumers must replace cached `Client` objects
from `NoosphereClientConnection.sessions`; local sessions normally remain
valid for the lifetime of their embedded server.

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
exactly 32 bytes losslessly. Identity ownership and concurrent creation are
coordinated by the explicit provider instance shared by the host lifecycle.
Node startup supplies the identity to `IrohServer.start`.
`IrohConfig` has no storage path and no placeholder path is needed. File-backed
identity management belongs to the standalone CLI host.

Back up an embedded server identity explicitly and send the returned bytes
directly to encrypted storage. The value is the 32-byte secret key, not the
public Iroh endpoint ID: never log it, and do not treat plain base64 as
encryption. Dart-managed memory cannot guarantee reliable zeroization.

```dart
final backup = await node.exportIrohServerIdentity();
await encryptedBackupVault.write('main-coordinator', backup);

// In a replacement process, restore before starting the node or worker setup.
final restored = await encryptedBackupVault.read('main-coordinator');
await restoreStoredIrohServerIdentity(identityStore, restored);

final replacement = await NoosphereNode.start(
  server: EmbeddedServerOptions(
    serverConfig: serverConfig,
    identityStore: identityStore,
    serverPersistence: durableServerPersistence,
  ),
);
```

For a running worker server setup, use
`await worker.exportIrohServerIdentity('main-coordinator')` and protect the
result in the same way. Restore its store before calling `startSetup`. The
standalone headless server already persists the same identity in its
`secret-key-path`; backing up that protected file is sufficient.

Production client calls must provide both `ClientStorageInterface` and
`GetPrivateKey`. The worker keeps these application-owned providers on the host
isolate and invokes them through correlated requests. Storage operations for a
setup are serialized. `prepareSignaturesOperation` remains one proxy call, and
the worker waits for durable completion before sending the network request.
Client storage calls also remain ordered across worker replacement when the
same host provider instance is reused, so a new load waits for an earlier
timed-out write. Separate provider instances or processes need host-managed
transaction ordering.

Pass `roomPersistence` in `EmbeddedServerOptions` to enable durable room state
for both direct nodes and workers. Workers retain this provider on the host
isolate and proxy room reads/writes through the same correlated bridge. A
provider timeout has an unknown outcome; it does not cancel a write. After a
room write failure, restart the server role to reload its state. Reuse the same
host provider instance so the replacement waits for any previous write; hosts
with multiple provider instances/processes must enforce ordering themselves.

The host implements the domain-specific `ClientStorageInterface`,
`RoomPersistence`, `ServerPersistence` and `ServerIdentityStore` using its own
storage backend. `ServerPersistence` stores coordinator DKG/ROAST snapshots. See
[architecture.md](architecture.md) for storage ownership and recovery boundaries.

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
For tests and examples, explicitly import `package:noosphere_flutter/testing.dart`
to use `InMemoryClientStorage` or `InMemoryRoomPersistence`. They are not exported
by `noosphere_flutter.dart`. `RoomManager.open` requires a persistence provider;
there is no implicit in-memory fallback.

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
flutter test integration_test/worker_lifecycle_test.dart -d linux
flutter test integration_test/worker_pending_key_test.dart -d linux
flutter test integration_test/worker_unexpected_exit_test.dart -d linux
flutter test integration_test/worker_forced_shutdown_test.dart -d linux
flutter test integration_test/worker_process_relaunch_test.dart -d linux \
  --dart-define=NOOSPHERE_RELAUNCH_PHASE=prepare
flutter test integration_test/worker_process_relaunch_test.dart -d linux \
  --dart-define=NOOSPHERE_RELAUNCH_PHASE=recover

cd example
flutter analyze
flutter build linux --release
```

Run the equivalent integration tests and `flutter build macos --release` on a
macOS runner. The direct transport test covers authentication, snapshots and
events. Worker tests cover verified threshold signatures, signer lock,
independent setups, session replacement, identity restart, unexpected native
exit and bounded forced shutdown. The ROAST test prints command latency and
frame timing samples for a 32-input signing batch, including a snapshot queued
as the worker enters synchronous Frosty work. For a foreground profile, run:

```sh
flutter drive --profile -d linux \
  --driver=tool/integration_test_driver.dart \
  --target=integration_test/worker_roast_test.dart
```

Run the unexpected-exit and forced-shutdown tests in fresh processes; they
deliberately make further native worker starts unsafe in those processes. The
two process-relaunch phases must run in order and as separate commands.

## Release preparation

The shared package needs standalone staging because the root `.pubignore`
excludes `packages/` from the facade archive and pub inherits that exclusion
when run inside a subpackage:

```sh
release_dir=$(./tool/stage_noosphere_release.sh)
cd "$release_dir"
dart pub publish --dry-run
```

The helper copies current source to a temporary directory and removes only the
staged manifest's workspace resolution. It does not publish. Validate the facade
with `dart pub publish --dry-run` from the repository root. Release compatible
shared, client and server versions before the facade.

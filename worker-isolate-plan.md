# ROAST worker isolate implementation plan

Status: v1 implemented locally on 2026-09-24. Linux unit, native 2-of-2,
native 2-of-3, analysis and release-build checks pass. Manual macOS execution
has also been confirmed. Fault injection, crash/restart acceptance, the full
macOS test/build matrix and performance measurements remain acceptance work.
Scope: make noosphere_flutter own a long-lived worker for the existing ROAST
client/server runtime on Linux and macOS.

The consuming wallet should own screens, user approval policy and its concrete
storage implementation. This package should own worker startup, commands,
events, role lifetimes and shutdown. Keep the protocol and cryptography in the
existing Noosphere and Frosty packages.

## Why move the whole runtime

The installed iroh_quic 1.0.3 already executes network operations on a shared,
multithreaded Rust Tokio runtime (rust/src/runtime.rs). Moving only its Dart
wrapper adds little scheduling benefit.

Frosty's rust/src/api/main.rs marks dkg_part_1/2/3, sign_part_1/2 and
aggregate_signature with #[frb(sync)]. These calls block their calling Dart
isolate until they return. Protocol decoding and Dart state transitions also
execute in that isolate. Keep these operations together in the worker so their
execution does not occupy the UI isolate. Measure actual latency; synchronous
execution alone is not evidence of an observed frame-rate problem.

```text
Main isolate
  Flutter UI, lifecycle, approval policy, host storage/key providers
       | commands, correlated replies, public events
ROAST worker isolate
  NoosphereNode(s), clients, server handlers, protocol and crypto state
       | FFI
Rust runtimes
  Iroh/Tokio and Frosty
```

One worker may own several setup nodes. Accounts derived from one shared key
reuse their setup's node. Do not create an isolate per derived wallet.

## 1. Separate initialization

- [x] Refactor lib/src/initialization.dart into root-isolate Flutter preparation
  and worker-compatible native initialization. Preserve the current public
  NoosphereFlutter.initialize() behavior for direct-node callers.
- [x] Keep WidgetsFlutterBinding.ensureInitialized() on the root isolate. The
  worker entry point must not invoke that path indirectly through
  NoosphereNode.start(). Introduce an explicit initialization seam rather than
  inferring that a static initialized flag is shared between isolates.
- [x] Audit coinlib_flutter.loadCoinlib(), Iroh.init() and
  frosty_flutter.loadFrosty() for worker use. Initialize each isolate's Dart/FRB
  bindings as required while respecting process-wide native runtime state.
  Verify the case where the consuming app already loaded coinlib on the root.
- [x] Preserve the macOS library-scoped Iroh framework lookup: Iroh and Frosty
  export colliding FRB symbols. Keep paths internal; do not introduce arbitrary
  user-configurable native-library paths.
- [x] If platform channels are required in the worker, explicitly pass the
  root isolate token and initialize the background messenger. Verify each plugin
  operation; do not assume unsolicited platform events work there.
- [x] Keep initialization concurrency-safe within each isolate and retain the
  current failure semantics. Preserve @RecordUse reachability for release builds.
- [ ] Prove create/use/close/restart of native objects in a worker on Linux and
  macOS before committing the public API. Audit native stream token uniqueness
  and cleanup across worker restarts and any concurrent direct-node usage.

## 2. Add a typed worker facade

- [x] Add a facade, provisionally NoosphereWorker, that uses Isolate.spawn and
  a ready/error startup handshake. Keep NoosphereNode available for direct use.
- [x] Define versioned, explicitly sendable messages with command IDs, setup IDs
  and worker-generation IDs. Use primitives, byte buffers and deliberate DTOs;
  do not send Client, endpoint/FRB handles, database objects or arbitrary captured
  callbacks across ports.
- [x] Support start/stop setup, server/client/both roles, public status snapshot,
  DKG request/accept/reject and signature request/accept/reject. Proposed names
  are not a commitment to expose every core operation automatically.
- [x] Keep reconstruction-capable shareKeySecret outside the default wallet
  facade. Adding it requires an explicit separate recovery workflow.
- [x] Emit public DTOs for participant presence, coordinator address, session
  status, DKG progress, signing requests/results and sanitized failures. Never
  forward raw core events without reviewing whether they contain secret data.
- [x] Correlate replies and guarantee that each pending command completes or
  fails when its worker exits. Ignore replies from an older worker generation.
- [x] Bound message sizes and outstanding commands. Preserve proposal/result
  events; coalesce only replaceable status updates. Define snapshot plus event
  ordering so consumers cannot miss state changes while subscribing.
- [x] Handle reconnectingClient.sessions inside the worker, replacing the old
  Client and event subscriptions without exposing session-bound objects to UI.

## 3. Bridge storage and key access explicitly

Existing ClientNodeOptions accepts ClientStorageInterface and GetPrivateKey;
EmbeddedServerOptions accepts ServerIdentityStore. These are application-owned
objects/callbacks, not a worker transport contract.

- [x] For the first implementation, provide worker-side proxies backed by
  correlated requests to host-side storage/key providers. This lets applications
  retain existing platform secure-storage and database integrations without
  transferring their live objects into the worker.
- [x] Give each database one owner. Serialize conflicting mutations by setup/key
  as needed; do not open independent mutable caches in both isolates. A future
  worker-owned database adapter is a separate option, not required for v1.
- [x] Forward prepareSignaturesOperation as ONE storage operation covering its
  prepared record and nonce replacements. Reply only after the host transaction
  is durably committed. The worker must wait before sending the network request.
- [x] A timeout, worker exit or lost storage reply leaves the outcome uncertain.
  Reconcile durable prepared state; never blindly retry signing or discard a
  prepared record because the command caller disappeared.
- [x] Scope key requests to the setup, participant, KeyPurpose and current worker
  generation. UI authorization must bind the exact DKG/signing proposal; key
  retrieval alone is not user consent to an arbitrary proposal.
- [x] Return secret bytes only over the explicit internal custody/storage
  channel when necessary. Do not include them in public events, logs or error
  text. Minimize copies and references; do not promise reliable zeroization of
  ordinary Dart-managed buffers.
- [x] Preserve durable 32-byte coordinator identity storage. Prevent competing
  load-or-create operations by stable storage identity, not only object identity
  in an isolate-local Expando.
- [ ] Test shutdown while storage/key requests are pending, host-provider failure
  and user cancellation without deadlocking either isolate.

## 4. Define role and lifecycle behavior

- [x] Let server and local signer have independent lifetimes. Locking the wallet
  must stop the signer from using cached shares, while optionally retaining a
  coordinator serving other peers. Reuse separate server-only/client-only nodes
  if that is simpler than changing NoosphereNode's combined close semantics.
- [x] Treat lifecycle events as explicit commands from the root isolate. Losing
  desktop window focus must not stop coordination. Await explicit logout and
  application shutdown; detached remains a best-effort bounded fallback.
- [x] Implement idempotent graceful close: stop accepting new work, resolve or
  fail pending commands, close clients and servers, cancel subscriptions and
  ports, then acknowledge worker exit.
- [ ] Reserve forced isolate termination for a bounded shutdown fallback. A
  killed isolate does not prove native sockets/tasks were released; test cleanup
  and reject unsafe restarts when the previous owner may still be alive.
- [ ] On unexpected worker exit, mark operations interrupted. Recreate sessions
  from durable state, but never replay an in-flight mutating DKG/signing RPC.
- [x] Do not advertise transparent continuation of unfinished DKG. The current
  ClientStorageInterface does not persist its temporary secrets. Reconcile any
  completed key before offering a new ceremony.
- [x] Document that server protocol state is currently in memory: restoring the
  Iroh identity is not restoration of outstanding signing/DKG sessions.

An isolate shares the application process. It does not provide an OS background
service, native-crash containment or a security boundary against compromised
code in that process. Closing the app stops embedded coordination. Android/iOS
background execution and other unsupported platforms remain separate work.

## 5. Keep integration small

- [x] Export the facade and DTOs through lib/noosphere_flutter.dart. Keep worker
  transport details out of consuming application widgets.
- [x] Adapt the example's client-only, server-only and combined modes to exercise
  the worker facade; keep its in-memory-storage limitation clearly visible.
- [x] Document how an application supplies storage/key providers and binds
  reviewed proposals to approval commands. Explain how to lock only the signer.
- [x] Preserve the existing direct-node API and tests. Retain dependency pins
  and consuming-app overrides until independently validated replacements exist.

Wallet account derivation conventions, account-index allocation, enrollment
invitations and application backup UX belong to separate tasks. This plan
provides the execution boundary they can use; it does not implement them.

## 6. Acceptance checks

- [ ] Real native worker startup, Iroh authentication, event delivery, clean
  shutdown and identity-preserving restart on both Linux and macOS.
- [ ] Native initialization when coinlib is already loaded by the root isolate;
  macOS Iroh/Frosty symbol isolation; repeated worker starts without leaked tasks,
  stream-token collisions or stale events.
- [x] Real 2-of-2 DKG and signing through the worker facade. Verify signatures,
  not just successful command replies. Exercise 2-of-3 quorum as well.
- [ ] Reconnect replaces sessions/subscriptions and does not replay a mutation.
- [ ] Locking prevents further local signing while a separately hosted server
  continues serving other participants.
- [ ] Fault injection before/after storage commit and before/after RPC response:
  unknown outcomes remain blocked/reconciled and nonces are never reused.
- [ ] Worker exit with pending commands/storage requests, partial startup failure
  and repeated close calls produce bounded completion and sanitized errors.
- [ ] Multiple setup nodes share one worker; stopping one does not close others.
- [ ] Record UI frame timing and worker command latency during DKG and signing,
  including a multi-input batch. Also measure whether a slow crypto operation
  delays other setup nodes enough to require later scheduling improvements.
- [ ] flutter analyze, existing unit tests, native integration tests and Linux/
  macOS release builds pass with the new worker-based example.

Suggested implementation order: native initialization spike; typed facade and
transport-only tests; storage/key proxies; DKG/signing; role lifecycle and crash
recovery; example, documentation and release verification.

References:

- [Flutter isolates](https://docs.flutter.dev/perf/isolates)
- [FRB synchronous calls](https://cjycode.com/flutter_rust_bridge/guides/concurrency/sync-dart)
- Current entry points: lib/src/initialization.dart, lib/src/node.dart,
  lib/src/client_options.dart, lib/src/server_options.dart,
  lib/src/server_identity_store.dart and lib/src/lifecycle.dart.

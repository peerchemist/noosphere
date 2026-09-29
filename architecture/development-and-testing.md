# Configuration, hosts, builds and verification

[Architecture overview](../architecture.md)

This chapter describes the development surfaces in this checkout. Toolchain
pins and platform support below come from repository manifests and CI, rather
than a claim about all platforms supported by upstream dependencies.

## Configuration boundaries

`GroupConfig` defines the shared roster. `ClientConfig` adds the local
participant ID and client TTL policy. `ServerConfig` adds coordinator challenge,
session, DKG, signing, completion and ACK-cache lifetimes. Iroh transport options
are separate from those domain policies.

| Policy | Client default | Server default |
| --- | --- | --- |
| Minimum requested DKG TTL | 30 minutes | 29 minutes |
| Maximum DKG TTL | 7 days | 7 days |
| Minimum requested signing TTL | 30 seconds | 25 seconds |
| Maximum signing TTL | 14 days | 14 days |
| Login challenge TTL | Server-issued | 20 seconds |
| Logical session TTL | Server-issued, automatically extended | 1 minute |
| Completed-signature minimum retention | Application keeps its own history | 1 day |
| DKG ACK cache TTL | Stored key ACKs are durable host records | 1 minute |
| Keepalive event frequency | Receives/ignores when configured | Disabled unless supplied |

The slightly smaller server minimums allow time to pass between proposal
construction and receipt. Client/server policy values can be overridden by the
host; the two sides still validate their own boundaries.

[`MapReader` and `MapWritable`](../packages/noosphere/lib/config/map_serial.dart)
provide typed map/YAML access, useful failures and TTL conversion. YAML lifetime
fields use milliseconds. This configuration format is not the network protobuf
schema or the durable snapshot schema.

Two current codec details matter when moving configuration between layers:

- `ClientConfig`'s compact binary codec writes group, participant and maximum
  DKG TTL, not every configurable TTL. Worker option encoding explicitly sends
  all four TTLs rather than assuming this compact codec covers them.
- `ServerConfig.map()` currently writes `max-signatutres-request` with that
  spelling, while `fromMapReader` reads `max-signatures-request`. Set the
  correctly spelled input field explicitly if configuring a nondefault maximum;
  do not assume the map round trip preserves that particular override.

[`IrohConfig`](../packages/noosphere_server/lib/src/config/iroh.dart) describes
ALPN, relay policy, timeouts, resource limits and optional native library path.
It contains no identity-storage filename. Flutter uses typed
`ClientNodeOptions`/`EmbeddedServerOptions` with provider objects. The lower
core and Flutter transport defaults differ as detailed in
[Iroh transport](iroh-transport.md).

## Standalone CLI host

[`bin/iroh_server.dart`](../packages/noosphere_server/bin/iroh_server.dart)
accepts a required `--config`/`-c` YAML path. It initializes Frosty, reads domain
and Iroh settings, loads/creates the coordinator identity and starts a server
with a file-backed `ServerPersistence`.

The CLI, rather than `IrohConfig`, reads `secret-key-path` and optional
`state-directory`. The latter defaults to `<config path>.state`. Its sample
configuration is
[`iroh-server.example.yaml`](../packages/noosphere_server/config/iroh-server.example.yaml).

[`identity_file.dart`](../packages/noosphere_server/bin/src/identity_file.dart)
shares concurrent in-process work by absolute path and uses an exclusive lock
file for cooperating processes. New identities are staged with restrictive
permissions, written with flush, then renamed into place. Existing malformed
identity data fails rather than being silently replaced.

[`FileServerPersistence`](../packages/noosphere_server/bin/src/server_state_file.dart)
names records using base64url-encoded group IDs, writes each snapshot to a
temporary file with flush and renames it into place. It is a concrete CLI host
adapter, not an encrypted database or a multi-process transaction manager.
Embedding applications implement the same contract using their own backend.

The CLI prints public group/endpoint information and an `IROH_SERVER_READY`
line used by process tests. It watches SIGINT/SIGTERM, closes the server and
awaits serving completion. It does not wire a room manager or a general remote
management API into this executable.

## Container and native builds

The [Containerfile](../packages/noosphere_server/Containerfile) builds the
standalone executable using Dart and Rust stages, compiles native assets and
installs the Iroh native library into the output bundle. The runtime image
launches `iroh_server --config`, with a persistent-data volume location.
Container deployment still needs a real group configuration and persistent
identity/state paths; shipping the binary does not select production policy.

The root manifest requires Dart `^3.13.0` and Flutter `>=3.47.0`. The repository
provides Linux and macOS desktop runners and CI. The root README specifies
macOS 12 or newer. Android, iOS, Windows and web are not supported by this
repository's current release integration.

Coinlib and Frosty use Dart native assets. Iroh's Flutter plugin supplies
desktop integration; standalone core tests use `iroh_quic:setup` and native
library configuration. Root initialization also handles macOS symbol lookup
and worker-specific binding setup; see [Flutter and isolates](flutter-and-isolates.md).

## Example application

[`example/lib/main.dart`](../example/lib/main.dart) is a consumer of the worker
facade, with signer-only, coordinator-only and combined modes. It subscribes to
worker events, retains a public snapshot for display, requests/approves DKG and
signing, and displays public participant/group information.

The example supplies `InMemoryClientStorage`, `InMemoryServerPersistence` and
an example identity store. Those illustrate the host boundary but are not a
durable wallet implementation. Its UI state is in the application, not injected
into the Noosphere core. The server Taproot example demonstrates a fuller
transaction signing flow; client examples demonstrate direct/reconnecting
transport consumption.

## Test map

| Location | Architectural behavior covered |
| --- | --- |
| [`packages/noosphere/test`](../packages/noosphere/test) | Domain codecs, hashes, metadata validation, HD paths, protobuf oneofs, incremental framing, room and transition values |
| [`packages/noosphere_client/test/client`](../packages/noosphere_client/test/client) | Stored key updates, atomic preparation contract and conservative recovery behavior |
| [`packages/noosphere_client/test/iroh`](../packages/noosphere_client/test/iroh) | Endpoint pinning, endpoint ownership and reconnect backoff |
| [`server/api_handler_test.dart`](../packages/noosphere_server/test/server/api_handler_test.dart) | Session, DKG, ROAST and recovery-share coordinator behavior |
| [`client_test.dart`](../packages/noosphere_server/test/client_test.dart) | Participant/coordinator interaction, malformed events, storage failures and ambiguous signing outcomes |
| [`iroh_dispatcher_test.dart`](../packages/noosphere_server/test/iroh_dispatcher_test.dart) | Same-group serialization, independent groups, release before socket writes and binding checks |
| [`iroh_authentication_test.dart`](../packages/noosphere_server/test/iroh_authentication_test.dart) | Connection-bound challenges, session timing and invalid proofs |
| [`iroh_client_api_test.dart`](../packages/noosphere_server/test/iroh_client_api_test.dart) | Real adapter RPCs, snapshots/events, reconnects and resource limits |
| [`room_manager_test.dart`](../packages/noosphere_server/test/room_manager_test.dart) | Invite possession, replay, capacity, frozen rosters and ambiguous writes |
| [`server_recovery_test.dart`](../packages/noosphere_server/test/server_recovery_test.dart), [`server_process_restart_test.dart`](../packages/noosphere_server/test/server_process_restart_test.dart) | Persisted protocol state and process restart |
| [`test`](../test) | Flutter initialization/node lifecycle, identity custody, worker correlation, limits and provider ordering |
| [`integration_test`](../integration_test) | Native transport, actual DKG/signatures, worker lifecycle, room signing, coordinator rotation and process relaunch |

`integration_test/worker_roast_test.dart` includes a larger signing batch and
timing observations; it exercises UI responsiveness alongside synchronous
cryptographic work. The forced-shutdown and unexpected-exit suites deliberately
poison further native worker starts in their processes and therefore need
separate executions. Process-relaunch preparation and recovery run in order as
separate processes.

Tests are evidence for particular behavior, not proof of every possible
cryptographic or storage failure. A production host also needs to verify its
own durable provider implementations against the contracts in this guide.

## Generation and verification commands

From `packages/noosphere`:

```sh
./tool/generate_protocol.sh --check
dart analyze
dart test
```

From the repository root:

```sh
flutter analyze
flutter test test
flutter test integration_test/native_transport_test.dart -d linux
flutter test integration_test/worker_roast_test.dart -d linux
flutter test integration_test/message_signing_2_of_2_test.dart -d linux
flutter test integration_test/coordinator_rotation_test.dart -d linux
```

The [CI workflow](../.github/workflows/ci.yaml) contains native setup, headless
Linux display handling, macOS executions, client/server package verification
and example/container builds. Not every test file in the repository is listed
as a separate CI step; consult the workflow for what is actually scheduled.

For documentation-only changes, verify relative links, model/API names,
examples and claimed defaults against source. Rebuilding native artifacts is
not needed to validate a changed explanation. For protocol changes, regenerate
protobuf and exercise complete request/event/snapshot round trips in addition
to isolated serialization.

## Reading specifications accurately

The shared [specifications](../packages/noosphere/spec) describe protocol rules,
security boundaries and version policy. Group-transition orchestration is
explicitly a proposed workflow despite implemented proposal/approval models.

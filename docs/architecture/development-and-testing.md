# Configuration, builds and verification

[Architecture overview](README.md)

This chapter collects the operational facts needed to configure, build and
verify the implementation; protocol semantics live in the other chapters and
the shared specifications.

## Configuration

`GroupConfig` defines the roster. Client/server configs add local identity and
domain TTL policy; Iroh configs add transport limits and timeouts.

| Policy | Client default | Server default |
| --- | ---: | ---: |
| Minimum DKG TTL | 30 min | 29 min |
| Maximum DKG TTL | 7 days | 7 days |
| Minimum signing TTL | 30 s | 25 s |
| Maximum signing TTL | 14 days | 14 days |
| Challenge TTL | — | 20 s |
| Session TTL | Extended automatically | 1 min |
| Completed result retention | Host-owned | 1 day minimum |

The server's slightly smaller minimums allow transit time. Each side validates
its own bounds.

Libraries use typed values and binary codecs; application wrappers decide how
configuration is loaded. Flutter options explicitly encode all client TTLs.

## Hosts and platforms

Coordinator deployments are application wrappers around `IrohServer`. The
wrapper supplies identity keys, typed configuration and persistence providers;
Noosphere does not ship a filesystem-backed executable or deployment image.

The workspace targets Dart `^3.13.0`, Flutter `>=3.47.0`, Linux and macOS. The
current repository does not support Android, iOS, Windows or web. The example
uses worker APIs with in-memory providers and is not a durable wallet.

## Verification

| Area | Main tests |
| --- | --- |
| Shared protocol | `packages/noosphere_protocol/test` |
| Participant and storage safety | `packages/noosphere_client/test` |
| Coordinator, Iroh and rooms | `packages/noosphere_server/test` |
| Flutter node/worker | `packages/noosphere_flutter/test` |
| Native end-to-end flows | `apps/integration_host/integration_test` |
| Demo UI and lifecycle | `apps/demo/integration_test` |

Representative commands:

```sh
flutter pub get
cd packages/noosphere_protocol
./tool/generate_protocol.sh --check
dart analyze
dart test

cd ../noosphere_flutter
flutter analyze
flutter test test

cd ../../apps/integration_host
flutter test integration_test/native_transport_test.dart -d linux
flutter test integration_test/worker_roast_test.dart -d linux

cd ../demo
flutter test integration_test/example_session_test.dart -d linux
```

CI verifies the complete Linux workspace in one job: the shared protocol,
client, server, Flutter facade, native end-to-end flows, release consumer,
and example application. Native integration tests run directly through Flutter
on Linux. Protocol changes should test codecs plus complete
request/event/snapshot paths. Documentation-only changes need link and source-claim
validation, not native rebuilds.

`./tool/validate_release_consumer.sh` stages the runtime packages outside the
workspace, creates a fresh Flutter consumer, analyzes it and starts/closes an
embedded server. It validates source consumption and native loading, not a
hosted release set.

Specifications in [`packages/noosphere_protocol/spec`](../../packages/noosphere_protocol/spec)
distinguish current rules from proposals; group-transition orchestration is
not implemented despite its existing domain models.

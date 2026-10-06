# Configuration, builds and verification

[Architecture overview](../architecture.md)

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

Only the standalone server parses YAML. Shared libraries use typed values and
binary codecs; YAML milliseconds are not a network or snapshot format. Flutter
options explicitly encode all client TTLs.

## Hosts and platforms

The standalone [`iroh_server`](../packages/noosphere_server/bin/iroh_server.dart)
loads YAML, a filesystem Iroh identity and file-backed coordinator snapshots.
It writes through temporary files and rename, but is neither an encrypted store
nor a multi-process database. It does not expose room management.

The Containerfile builds that host and its native dependencies. Deployments
must still provide durable identity/state paths and real group configuration.

The workspace targets Dart `^3.13.0`, Flutter `>=3.47.0`, Linux and macOS. The
current repository does not support Android, iOS, Windows or web. The example
uses worker APIs with in-memory providers and is not a durable wallet.

## Verification

| Area | Main tests |
| --- | --- |
| Shared protocol | `packages/noosphere/test` |
| Participant and storage safety | `packages/noosphere_client/test` |
| Coordinator, Iroh and rooms | `packages/noosphere_server/test` |
| Flutter node/worker | `test` |
| Native end-to-end flows | `integration_test` |

Representative commands:

```sh
cd packages/noosphere
./tool/generate_protocol.sh --check
dart analyze
dart test

cd ../..
flutter analyze
flutter test test
flutter test integration_test/native_transport_test.dart -d linux
flutter test integration_test/worker_roast_test.dart -d linux
```

CI defines the complete scheduled matrix, including macOS, server packages,
examples and containers. Protocol changes should test codecs plus complete
request/event/snapshot paths. Documentation-only changes need link and
source-claim validation, not native rebuilds.

`./tool/validate_release_consumer.sh` stages the runtime packages outside the
workspace, creates a fresh Flutter consumer, analyzes it and starts/closes an
embedded server. It validates source consumption and native loading, not a
hosted release set.

Specifications in [`packages/noosphere/spec`](../packages/noosphere/spec)
distinguish current rules from proposals; group-transition orchestration is
not implemented despite its existing domain models.

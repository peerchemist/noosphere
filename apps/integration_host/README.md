# Native integration host

This private Flutter application owns the Linux and macOS runners used to
exercise the Noosphere libraries with native bindings. Demo-specific UI tests
live in [`apps/demo/integration_test`](../demo/integration_test).

Resolve dependencies with `flutter pub get` at the repository root, then run
from this directory:

```sh
flutter test integration_test/native_transport_test.dart -d linux
flutter test integration_test/worker_roast_test.dart -d linux
flutter test integration_test/worker_dkg_dropout_test.dart -d linux
```

On macOS, use `-d macos`. Linux CI runs these commands under `xvfb-run -a`.
The DKG dropout test covers two distinct cases:

1. During round one, an accepted co-signer persists its opaque state through
   the calling application's callback and publishes its commitment. Its signer
   role is then stopped, discarding all process-local client state. On restart,
   Noosphere reports that the ceremony cannot resume; the test application
   reads its test-only JSON file and explicitly calls `importDkgSecret`. The
   3-of-3 ceremony then completes with the same group key for every signer.
2. A third signer remains unavailable for four minutes and then returns. The
   ceremony remains pending rather than being reset or expired merely because
   that signer was offline.

The JSON file models application-owned persistence only. It is not part of
`ClientStorageInterface` and is not a production storage recommendation.

The process-relaunch test requires separate `prepare` and `recover` runs; see
the [CI workflow](../../.github/workflows/ci.yaml).

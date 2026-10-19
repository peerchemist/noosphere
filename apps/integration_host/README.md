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
The DKG dropout test intentionally waits four minutes before reconnecting its
third signer.
The process-relaunch test requires separate `prepare` and `recover` runs; see
the [CI workflow](../../.github/workflows/ci.yaml).

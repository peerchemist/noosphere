# noosphere_flutter

Flutter facade for Noosphere participants and embedded coordinators. The
`NoosphereWorker` API runs protocol state and cryptography in an isolate while
the host supplies identity keys, persistence and application policy.

Import `package:noosphere_flutter/noosphere_flutter.dart` for the public API.
Memory-only persistence for tests and demonstrations is available through
`package:noosphere_flutter/testing.dart`.

See the [repository overview](../../README.md),
[Flutter architecture](../../docs/architecture/flutter-and-isolates.md), and
[demo application](../../apps/demo).

From this directory, run `flutter test test`. Native end-to-end tests run from
[`apps/integration_host`](../../apps/integration_host).

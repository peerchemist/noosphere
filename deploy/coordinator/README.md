# Standalone coordinator image

Build from the repository root:

```sh
podman build --file deploy/coordinator/Containerfile --tag noosphere-server .
```

The build copies this directory's `pubspec.yaml` into the image's workspace
root. It explicitly selects `noosphere_protocol`, `noosphere_client` and
`noosphere_server`, using the repository lockfile without requiring Flutter.
Run `flutter pub get` at the repository root when updating that lockfile.

See the [coordinator deployment instructions](../../README.md#standalone-coordinator-container)
for configuration, persistent volumes and networking. CLI source and its
example YAML remain in [`packages/noosphere_server`](../../packages/noosphere_server).

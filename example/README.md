# noosphere_flutter example

Linux/macOS example for client-only, embedded-server-only, and both-role
Noosphere nodes.

The example intentionally uses in-memory client storage and an in-memory server
identity store, and displays that limitation prominently. Enter a server ID
obtained through an independent trusted channel and its base64-encoded bootstrap
address for client roles. Both-role mode retains a dedicated client endpoint.

```sh
flutter run -d linux
# or, on macOS:
flutter run -d macos
```

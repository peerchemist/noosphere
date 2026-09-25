## 0.1.0

- Add Linux and macOS Flutter lifecycle adapters for Noosphere client and
  embedded-server roles.
- Add host-managed embedded-server identities and reconnecting client sessions.
- Add a desktop example, lifecycle/unit tests, and real-Iroh integration tests.
- Add a long-lived, multi-setup `NoosphereWorker` isolate facade with typed
  snapshots/events, correlated commands, host storage/key/identity proxies,
  reconnect handling, and independent server/signer lifetimes.
- Split root Flutter preparation from worker-safe native initialization while
  preserving the direct `NoosphereNode` API.
- Default Flutter clients to two concurrent RPC streams and embedded servers
  to four streams per client connection.

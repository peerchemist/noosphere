# noosphere_flutter example

Linux/macOS example for client-only, embedded-server-only, and both-role
Noosphere nodes.

The example intentionally uses in-memory client storage and an in-memory server
identity store, and displays that limitation prominently. Enter a server ID
obtained through an independent trusted channel and its base64-encoded bootstrap
address for client roles. Both-role mode retains a dedicated client endpoint.

The app prints verbose diagnostics, including its demo ROAST and Iroh private
keys, to the terminal. Never use this logging with production keys.

## First two-computer 2-of-2 test

1. On computer A choose **Computer A · server + participant 1** and press
   **Start**.
2. Copy the displayed server endpoint ID and bootstrap address.
3. On computer B choose **Computer B · participant 2**, paste both server
   values, and press **Start**.
4. After both clients show one online peer, press **Create 2-of-2 key** on A.
5. Press **Accept DKG** on B and wait until the same generated group key is
   displayed on both computers.
6. On A enter a 32-byte hash (the default test value is valid) and press
   **Request 2-of-2 signature**.
7. Verify the displayed hash on B, then press **Accept signature**.
8. Both computers should display the same Schnorr signature and
   `Signature valid: true`.

The demo uses deterministic participant keys so independently built copies
share the same test `GroupConfig`. All identities, DKG shares, and signing
state are in memory and are lost when the app exits.

```sh
flutter run -d linux
# or, on macOS:
flutter run -d macos
```

# noosphere_flutter example

Linux/macOS example for client-only, embedded-server-only, and both-role
Noosphere nodes.

The example intentionally uses in-memory client storage and an in-memory server
identity store, and displays that limitation prominently. Enter an Iroh ID
obtained through an independent trusted channel for client roles. Iroh
discovery resolves that Iroh ID to direct or relay addresses.

The app prints verbose connection and protocol diagnostics to the terminal,
but never private keys.

## First two-computer 2-of-2 test

1. On computer A choose **Computer A · server + participant 1** and press
   **Start**.
2. Copy the displayed Iroh ID.
3. On computer B choose **Computer B · participant 2**, paste the Iroh ID, and
   press **Start**.
4. After both clients show one online peer, press **Create 2-of-2 key** once on
   A.
5. Press **Accept DKG** on B and wait until the same generated group key is
   displayed on both computers. The corresponding Peercoin testnet and mainnet
   Taproot addresses are derived and displayed automatically.
6. On A enter a 32-byte hash (the default test value is valid) and press
   **Request 2-of-2 signature**.
7. Verify the displayed hash on B, then press **Accept signature**.
8. Both computers should display the same Schnorr signature and
   `Signature valid: true`.

The demo displays each participant's ROAST public key and uses deterministic
participant keys so independently built copies share the same test
`GroupConfig`. All identities, DKG shares, and signing state are in memory and
are lost when the app exits.

```sh
flutter run -d linux
# or, on macOS:
flutter run -d macos
```

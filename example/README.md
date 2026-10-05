# noosphere_flutter example

Linux/macOS example for client-only, embedded-server-only, and both-role
Noosphere nodes.

The example intentionally hardcodes the public BIP-39 test-vector mnemonic
`abandon abandon abandon abandon abandon abandon abandon abandon abandon
abandon abandon about`. **Never use this mnemonic for real funds.** Every copy
of the example derives the same identities:

```text
hardcoded mnemonic + empty passphrase
└─ 512-bit BIP-39 seed
   ├─ Peercoin BIP-44 m/44'/6'/0'/0/0 → participant 1 secp256k1 key
   ├─ Peercoin BIP-44 m/44'/6'/0'/0/1 → participant 2 secp256k1 key
   └─ BIP-85 m/83696968'/128169'/32'/0' → Iroh Ed25519 identity
```

This mirrors the production ownership model: the wrapping wallet supplies its
BIP-39 seed-derived identity material when it constructs the node. The library
does not generate or persist the Iroh secret. A real multi-device setup should
use each participant wallet's own mnemonic and publish the resulting participant
public keys in its `GroupConfig`.

Enter Computer A's Iroh ID through an independent trusted channel for client
roles. Iroh discovery resolves that Iroh ID to direct or relay addresses.

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

The demo displays the derivation paths and each participant's ROAST public key.
The mnemonic-derived identity keys are deterministic so independently built
copies share the same test `GroupConfig` and Iroh endpoint ID. DKG creates the
threshold group key and private shares at runtime; those DKG shares and all
session/signing state are held only in memory and are lost when the app exits.

```sh
flutter run -d linux
# or, on macOS:
flutter run -d macos
```

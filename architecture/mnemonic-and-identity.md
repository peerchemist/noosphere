# Mnemonic and identity workflow

[Architecture overview](../architecture.md)

An application may derive both its participant identity and stable Iroh server
identity from one BIP-39 seed, using separate domain-specific paths. The
mnemonic and passphrase remain application-owned.

```text
BIP-39 mnemonic + passphrase
  -> 64-byte seed
     -> application wallet path -> secp256k1 participant identity
     -> BIP-85 m/83696968'/128169'/32'/index' -> Iroh Ed25519 secret

DKG (independent) -> FROST shares + group public key
```

The participant key authenticates login, proposals, DKG attestations and share
encryption. `deriveIrohSecretKeyFromBip39Seed` derives 32 bytes through BIP-85's
raw-entropy application; the same seed, passphrase and index recreate the same
endpoint ID. Use a stable, distinct index for each endpoint operated
simultaneously.

FROST shares are not mnemonic children. They are created jointly by DKG and
need their own durable storage/recovery. Recovering the mnemonic restores the
participant and Iroh identities, not a completed threshold key.

For a direct node, the host-derived Iroh key is passed to server startup. For a
worker, derivation runs on the host and only the 32-byte Iroh secret crosses the
isolate boundary. The package has no embedded identity store.

## Safety rules

- Preserve the mnemonic, optional passphrase and setup-to-index mapping.
- Changing any of them changes the endpoint ID and invalidates existing pins
  and coordinator-bound room records.
- Never use mnemonic text, the BIP-39 seed, a wallet key or a FROST share
  directly as the Iroh secret.
- Never log private identity material or FROST shares. Endpoint IDs are public.
- Domain separation prevents key reuse, not common-root compromise.
- Dart memory cannot guarantee zeroization; release sensitive references
  promptly.

The derivation follows [BIP-39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
and BIP-85 [raw entropy](https://github.com/bitcoin/bips/blob/master/bip-0085.mediawiki#hex).

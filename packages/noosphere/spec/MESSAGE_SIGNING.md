# BIP-340 message signing

Status: implemented. This document specifies the message-signing API and its
wire and verification requirements.

## Scope and existing support

Provide a wallet-style sign/verify message feature using the existing
ROAST/FROST signing flow. The output is a BIP-340 signature under the untweaked
group public key. Version 1 uses the base group key with an empty HD derivation
path.

The cryptographic support already exists: `frosty.SignDetails` accepts a
32-byte message with `mastHash: null`, and coinlib verifies the resulting
Schnorr signature. `integration_test/roast_2_of_2_test.dart` already exercises
untweaked threshold signing. This feature adds message hashing, metadata,
request construction, and portable verification around that flow.

Ethereum message types, EIP-712, Solidity verification, BIP-322 address proofs,
and legacy Bitcoin/Peercoin `signmessage` compatibility are outside this scope.
The format below is a Noosphere application protocol using BIP-340, not a
message envelope defined by BIP-340 itself.

## Message format and digest

Introduce `SignedMessagePayload` in the shared `noosphere` package with a
format version, message text, and computed 32-byte digest. Initially the only
supported format version is `1`.

For version 1, compute:

```text
tag    = SHA256(UTF8("Noosphere/SignedMessage/v1"))
digest = SHA256(tag || tag || UTF8(text))
```

Concatenation uses raw bytes, not hexadecimal strings. This is application
pre-hashing; BIP-340's internal challenge calculation remains unchanged.

The text is encoded exactly as UTF-8, without trimming, Unicode normalization,
or newline conversion. Reject malformed Unicode rather than silently replacing
it. Empty text is valid. Limit text to 1 KiB (1024 UTF-8 bytes), excluding
serialization overhead. Check the declared byte length before allocating or
decoding incoming text, and decode UTF-8 strictly.

Canonical payload encoding is a one-byte format version followed by the text
using the existing domain string length-prefix encoding. Reject unsupported
versions. Keep the digest implementation in this model so signing and
verification cannot diverge. Copy or protect mutable byte values exposed by
the model.

The format version selects the hashing rules and tag. This application format
version is independent of the ROAST transport version.

## Request metadata and signing

Add `MessageSignatureMetadata` to the metadata decoder with type ID `2`
(`0` and `1` already identify empty and Taproot transaction metadata).
Its encoding is the metadata type byte followed by `SignedMessagePayload`.

`verifyRequiredSigs()` must require:

- Exactly one requested signature.
- Its message equals the digest reconstructed from the payload.
- Its `mastHash` is `null`, so no Taproot tweak is applied.
- Its HD derivation path is empty for version 1.

Introduce a convenience factory with this proposed API:

```dart
SignaturesRequestDetails.forMessage(
  text: 'Hello!',
  groupKey: groupKey,
  expiry: expiry,
)
```

The factory constructs the payload, matching metadata, and one
`SingleSignatureDetails` with the supplied group key, an empty derivation path,
and:

```dart
SignDetails(message: payload.digest, mastHash: null)
```

Do not use `SignDetails.keySpend()`: even without a MAST root it applies a
Taproot tweak. The explicit constructor avoids giving arbitrary message
signing a transaction-specific name such as `scriptSpend`.

Use the existing `requestSignatures`, `acceptSignaturesRequest`, and completion
events. Preserve the existing ROAST coordination, nonce lifecycle, persistence,
and final signature checks.

Participants must display the text from validated `MessageSignatureMetadata`
before approval. The existing request-level `SignaturesRequestDetails.message`
is only the requester's explanation; it does not become the text signed by the
threshold group. Its existing 1 KiB limit remains independent of the signed
payload limit. Applications must not treat unknown metadata as a recognized
message-signing request or automatically approve it as one.

Request expiry controls the signing session. It does not expire the resulting
message signature and is not included in this message digest.

## Result and local verification

Add `SignedMessage` containing:

- Format version and original text.
- The base group public key in 32-byte BIP-340 x-only encoding.
- The 64-byte BIP-340 signature (`r || s`).

Construct this result from the completed request's validated metadata, requested
group key, and returned signature. Verify the signature before exporting it.

Provide `verify()` that recomputes the payload digest and calls coinlib's
`SchnorrSignature.verify()` with the supplied public key. Reject unsupported
versions, invalid keys, malformed encodings, and incorrect lengths. A valid
signature establishes validity under that key; callers must separately match
the key to the expected group identity. The signature does not encode the
threshold or identify which participants signed.

Provide JSON import/export with these fields:

```text
format:    "noosphere-signed-message"
version:   1
text:      original message text
publicKey: 64 lowercase hexadecimal characters, without 0x
signature: 128 lowercase hexadecimal characters, without 0x
```

Require these field types and canonical hex encodings on import. JSON is a
transport envelope: key order and JSON escaping do not enter the digest; the
decoded text does. Verification is offline and needs no coordinator, private
shares, or signing transcript.

## Implementation sequence

1. Add `SignedMessagePayload`, shared limits, digest calculation, and bounded
   serialization in `packages/noosphere/lib/api/types/`.
2. Add `MessageSignatureMetadata` and its decoder branch in
   `signature_metadata.dart`, enforcing digest, count, tweak, and derivation
   checks during request construction and decoding.
3. Add `SignaturesRequestDetails.forMessage()` and export the new public types
   through `domain.dart`.
4. Add `SignedMessage`, completion-to-result conversion, offline verification,
   and JSON import/export.
5. Integrate metadata-based text display into the example's approval flow and
   confirm existing client, server, and Flutter worker serialization transports
   the new metadata without losing or substituting the payload.
6. Add the verification coverage below and a README example covering request,
   approval, completion, export/import, and verification.

Follow `VERSIONING.md`: update development clients, servers, and tests together
without bumping the ROAST protocol version or adding legacy decoding branches.

## Verification coverage

- Fixed, independently calculated digest vectors for empty text, ASCII,
  non-ASCII Unicode, and distinct LF/CRLF messages.
- Exact UTF-8 byte-limit boundaries, malformed Unicode/UTF-8, unsupported
  versions, malformed lengths, and serialization round trips.
- Rejection of mismatched metadata/digest, extra signatures, non-null MAST
  hashes (including an empty MAST hash), and non-empty derivation paths.
- Export/import followed by successful offline verification; changed text,
  public key, or signature must fail verification.
- A real ROAST integration test signing text through the new factory and
  verifying the exported result under the original group key. Compare
  verification outcomes, not freshly generated signature bytes against a fixed
  signature, since threshold signing uses fresh nonces.
- Existing request serialization and Taproot signing checks continue to pass.

## References

- [BIP-340](https://bips.dev/340/), particularly domain separation, x-only keys,
  and signature verification.
- [Protocol semantics](PROTOCOL.md).
- [Development versioning](VERSIONING.md).

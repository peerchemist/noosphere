# Noosphere protocol

Canonical ROAST domain types, group configuration, protobuf messages and
transport-independent framing for the Noosphere protocol. Client, server and
Flutter implementations consume this package directly; transport adapter
implementations such as Iroh endpoints remain outside it.

The public libraries separate the semantic and wire layers:

- `wire.dart` contains generated protobuf messages, stable operation IDs,
  QUIC-varint helpers for persistent records, event conversion and wire
  constants. Single-message RPC bodies are delimited by QUIC FIN.
- `domain.dart` contains ROAST requests, responses, events and shared types.
- `config.dart` and `common.dart` contain shared configuration and utilities.
- `iroh.dart` contains the shared ALPN and relay-policy value objects, without
  implementing an Iroh endpoint.

The canonical schema is `proto/noosphere.proto`. Regenerate the checked-in
Dart message classes with:

```sh
./tool/generate_protocol.sh
./tool/generate_protocol.sh --check
```

Protocol behavior beyond the wire schema is documented in `spec/`.

## Value ownership and decoding

Domain `fromBytes` APIs own the supplied byte slice and require a complete
value with no trailing bytes. They reject non-canonical length prefixes,
invalid booleans and duplicate map identifiers. Use `fromReader` only when
decoding a value embedded within a larger record, and use
`NoosphereBytesReader` from `common.dart` to retain the bounded reader behavior.

Noosphere serialized byte views, signing hashes and signing payloads are
read-only. Copy bytes before editing them. `GroupConfig.participants` is a
read-only map in identifier order. This is a shallow ownership guarantee: retained Frosty identifiers,
commitments, shares and ciphertexts, and Coinlib transaction/signing metadata,
keep their dependency ownership contracts. Do not mutate their cached bytes or
call `dispose()` while a Noosphere object or runtime still uses them. A final
field or read-only collection does not transfer or duplicate a native handle.

Prefer the Flutter worker's public DTOs for UI state. To create an independent
native value, copy its serialized bytes and decode with its type's constructor;
manage that new value's lifetime separately. Never duplicate signing nonces for
reuse. Coinlib 6.0.1, Frosty 5.0.0 and the Iroh adapters 1.0.3 are pinned to the
versions exercised by the release tests.

Unknown signature metadata can be preserved as a standalone opaque value, but
cannot be embedded in an accepted signing request. Supporting a new metadata
type requires a bounded codec and semantic validation of the requested digests.

To prepare this package for publication from the workspace, use the repository
root's `tool/stage_noosphere_release.sh`. It stages current source outside the
root `.pubignore` exclusion for `packages/` and does not publish anything.

Signature requests accept an optional free-form explanation:

```dart
final details = SignaturesRequestDetails(
  requiredSigs: requiredSigs,
  expiry: Expiry(const Duration(minutes: 10)),
  message: 'Approve payment for invoice #123',
);
await client.requestSignatures(details);
```

The message defaults to an empty string and is authenticated by the requester's
signature. Read it from `event.details.obj.message` on a domain
`SignaturesRequestEvent`, or `event.request.details.message` on a client
`SignaturesRequestClientEvent`. It also remains available in completed requests.
The explanation does not change the payloads being threshold-signed.
Messages are limited to 1 KiB (1024 UTF-8 bytes), exposed as
`SignaturesRequestDetails.maxMessageBytes`. Oversized messages are rejected on
construction and decoding.

## Sign and verify a message

Message signing uses the untweaked BIP-340 group key and signs a versioned,
tagged hash of the exact UTF-8 text. Construct a request with the convenience
factory:

```dart
final request = SignaturesRequestDetails.forMessage(
  text: 'Hello from Noosphere!',
  groupKey: groupKey,
  expiry: Expiry(const Duration(minutes: 10)),
  message: 'Please approve this greeting',
);
await client.requestSignatures(request);
```

Before approval, applications must identify the metadata and show the text from
the validated payload. The request-level `message` above is only an explanation
and is not the threshold-signed text.

```dart
if (event case SignaturesRequestClientEvent(:final request)) {
  final metadata = request.details.metadata;
  if (metadata is MessageSignatureMetadata) {
    print('Text to sign: ${metadata.payload.text}');
    // Ask the user, then approve only after an affirmative decision.
    await client.acceptSignaturesRequest(request.details.id);
  }
}
```

Convert a completion into a portable result, export/import it as JSON, and
verify it without a coordinator or signing transcript:

```dart
if (event case SignaturesCompleteClientEvent()) {
  final signedMessage = event.toSignedMessage();
  final exported = signedMessage.toJsonString();
  final imported = SignedMessage.fromJsonString(exported);
  if (!imported.verify()) throw StateError('invalid message signature');
}
```

Verification proves validity under `imported.publicKey`; callers must still
match that key to the expected group identity. Signed text is limited to 1 KiB
of strict UTF-8 and is not trimmed, normalized, or newline-converted.

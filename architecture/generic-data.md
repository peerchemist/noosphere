# Transmitting generic application data

[Architecture overview](../architecture.md)

The existing event pipeline can carry application content when that content is
part of a supported signing proposal. It does not expose an arbitrary
`publish(topic, object)` API. Distinguish transporting content, authenticating
its sender, threshold-signing its meaning, and persisting the resulting
application action: each is a separate responsibility.

## Available paths

| Need | Current path | What recipients receive |
| --- | --- | --- |
| Sign a short text or JSON document | `SignaturesRequestDetails.forMessage` | Exact text in metadata, proposal events, then a verified threshold signature |
| Sign an arbitrary binary/document digest | `SingleSignatureDetails` with suitable `SignDetails` | Digest and supplied supported metadata; the original document needs its own delivery path |
| Add a human explanation to a signing request | `SignaturesRequestDetails.message` | Requester-authenticated explanation, not an extra threshold-signed message |
| Bind opaque migration policy to consent | `GroupTransitionMigrationPolicy.payload` | Bytes inside a transition proposal; delivery/orchestration is host-owned today |
| Broadcast arbitrary data without a signing operation | No current generic RPC/event API | Requires an explicit protocol extension or a separate application channel |

## Why `Events.data` can contain bytes but is not a generic bus

The protobuf shape is `Events { EventType type; bytes data; }`. Bytes can
represent JSON, another protobuf message, CBOR, compressed content or a custom
binary record in principle. In the current implementation, however, `type`
selects one of the fixed Noosphere domain decoders. Supplying JSON under
`SIG_REQ_EVENT` will attempt to decode it as `SignaturesRequestEvent` and fail.

`Event` and the public event families are sealed. Consumers cannot add an
arbitrary subclass in a different Dart library and expect existing exhaustive
switches, authentication, routing and persistence to support it.

## A working path: signed JSON as message text

For a small application document, encode the exact document as a string and
use the existing message-signing operation. This example uses only current
public APIs. It assumes the setup has a stored FROST key and the caller has
already approved creating this request:

```dart
import 'dart:convert';
import 'package:noosphere_flutter/noosphere_flutter.dart';

Future<void> requestDocumentSignature({
  required NoosphereWorker worker,
  required String setupId,
  required ECCompressedPublicKey groupKey,
  required String operationId,
}) async {
  final text = jsonEncode({
    'schema': 'example.document-approval',
    'version': 1,
    'operationId': operationId,
    'documentId': 'invoice-1042',
    'decision': 'approved',
  });

  final request = SignaturesRequestDetails.forMessage(
    text: text,
    groupKey: groupKey,
    expiry: Expiry(const Duration(minutes: 10)),
    message: 'Approve invoice 1042',
  );
  await worker.requestSignatures(setupId, request);
}

Map<String, Object?> decodeDocumentProposal(WorkerSigningRequest event) {
  final proposal = event.decodeProposal();
  final metadata = proposal.metadata;
  if (metadata is! MessageSignatureMetadata) {
    throw const FormatException('Expected a message-signing proposal');
  }
  final decoded = jsonDecode(metadata.payload.text);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  if (decoded['schema'] != 'example.document-approval' ||
      decoded['version'] != 1) {
    throw const FormatException('Unsupported application schema');
  }
  return decoded.cast<String, Object?>();
}

SignedMessage verifiedDocumentResult(WorkerSigningResultEvent event) =>
    event.toSignedMessage();
```

The sample schema check is just a starting point. The host validates all fields,
authorities, intended group/key, operation ID and replay rules before asking
for approval. After review it calls
`worker.acceptSignatures(setupId, reviewedRequest)` with the same proposal DTO.

The payload follows the ordinary signing pipeline:

```text
application JSON string
  -> SignedMessagePayload + MessageSignatureMetadata
  -> requester-signed SignaturesRequestDetails
  -> requestSignatures RPC
  -> SignaturesRequestEvent in protobuf Events.data
  -> verified client proposal
  -> WorkerSigningRequestEvent.request.proposalBytes
  -> host decodes exact JSON text
  -> accepted ROAST rounds
  -> WorkerSigningResultEvent.toSignedMessage()
```

The initiating participant is implicitly accepting its own request; others
review the proposal independently. This is a signing workflow with signing
costs, consent and threshold requirements, not a free-form notification channel.

`forMessage` constructs exactly one untweaked, underived signature over the
tagged digest of the text. `MessageSignatureMetadata.verifyRequiredSigs`
enforces the association between the text and requested digest. A verified
`SignedMessage` is portable outside Noosphere and can be exported as JSON.

## Exact bytes, limits and authorization scope

Signed-message text and the separate explanation are each limited to 1,024
UTF-8 bytes. The 1 MiB network envelope maximum does not enlarge either model
limit. A JSON document's whitespace, key order and Unicode representation
affect its signed digest. The receiver verifies the original text, not a
parse-and-reencode variant.

If several applications must independently reproduce the same document bytes,
define a canonical application codec. The sample `jsonEncode` call establishes
one exact representation for this request, not a cross-language canonical JSON
standard. Version the schema and include an application domain and a unique
operation identifier inside the signed text when those are part of authorization.

The final threshold signature authenticates the payload text, not all the
outer signing request fields. In particular, the outer request expiry,
request ID, creator and human explanation are not automatically covered by
the text's final signature. If an authorization needs an expiry, intended
recipient, network or group fingerprint, include that context in the text
itself and enforce it when consuming the result.

The coordinator sees this text. Transport encryption protects the network
connection, not confidentiality from the coordinator that receives the request.
Sensitive application documents need an appropriate additional confidentiality
design, rather than assuming `bytes` or JSON is encryption.

## Signing arbitrary binary data

The lower-level request can sign a chosen digest using `SingleSignatureDetails`
and `SignDetails`. The application must define its canonical document bytes,
domain separation and hash algorithm, and provide enough authenticated context
for signers to inspect the requested action.

Sending a hash does not send its preimage. The current `EmptySignatureMetadata`
does not transport an arbitrary document or verify its meaning. Deliver the
document through an application channel, or implement a supported metadata
codec that can validate its relation to the digest. Signers must independently
recompute the hash before accepting.

`SignaturesRequestDetails.message` is also not a substitute. It is bound to
the requester's identity signature, but can describe an action different from
the digests in `requiredSigs`. A final threshold signature does not turn the
explanation into a signed authorization.

## Why not use `UnknownSignatureMetadata` as an extension API?

[`UnknownSignatureMetadata`](../packages/noosphere/lib/api/types/signature_metadata.dart)
preserves opaque bytes only when decoded as a complete standalone value. Its
validation method returns false, and embedded decoding rejects unknown types.
The format has no length for an unknown metadata body, so a reader cannot
distinguish that body from the expiry and explanation following it in a
signing request. Unknown metadata therefore cannot authorize signing or serve
as an application messaging extension.

A supported metadata extension needs an explicit bounded encoding, decoder,
type assignment and semantic validation tying data to `requiredSigs`. It also
needs full signed-request, event, snapshot and worker round-trip tests.

## Existing opaque host policy bytes

`GroupTransitionMigrationPolicy` already provides a deliberately opaque
`kind`, positive `version`, and 1–65,535-byte payload. Those bytes are included
in the canonical transition proposal and its consent hash. Noosphere does
not interpret accounts, assets or fee limits inside them; the application does.

This is an example of the intended ownership boundary for generic domain data.
It does not provide transport automatically: there is currently no transition
proposal RPC or worker orchestration/event family that distributes it.

## Designing a general application event extension

The following is a design outline, not an API already present in this checkout:

1. Define a bounded application-message model containing schema/type, version,
   message ID, group context, sender, recipients, expiry and payload bytes.
   Choose canonical bytes for any identity signature.
2. Add an authenticated request to `ApiRequestInterface`, protobuf request and
   result variants, and both Iroh RPC adapters. Bind claimed sender and group
   to the authenticated session and enforce recipient membership and limits.
3. Add a domain event and `EventType` value. Update server encoding and client
   decoding, then verify the payload before exposing a client event.
4. Add a public client event and, if needed, a sanitized worker event/command.
   Update message-size accounting and use bytes/DTOs rather than arbitrary
   runtime objects across isolates.
5. Define delivery semantics. For durable delivery, add host persistence,
   replay/deduplication rules, acknowledgments and ordering. Current transient
   event buffering supplies none of these automatically.
6. Specify what the application does with the verified content. Receiving data
   must not silently change the coordinator pin, approve signing, or execute an
   application action without the relevant policy.
7. Test malformed/oversized payloads, authorization, signature binding,
   duplicate IDs, reconnect, worker conversion and any persistence ambiguity.

An alternative is a separate application protocol/ALPN on an Iroh endpoint
owned by the host. That also requires explicit framing, authentication and
delivery policy, but keeps its lifecycle and events separate from ROAST. The
current `IrohServer` only routes its implemented ROAST/enrollment protocols;
registering an arbitrary ALPN there is not an existing plugin hook.

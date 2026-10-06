# Transmitting generic application data

[Architecture overview](../architecture.md)

Noosphere can carry data that belongs to a supported signing proposal. It is
not a generic `publish(topic, object)` bus. Transport, sender authentication,
threshold authorization and durable application effects are separate concerns.

## Current choices

| Need | Use |
| --- | --- |
| Sign short text or JSON | `SignaturesRequestDetails.forMessage` |
| Sign an arbitrary digest | `SingleSignatureDetails` with an application-defined codec and delivery path |
| Explain a signing request | `SignaturesRequestDetails.message` |
| Bind migration policy | `GroupTransitionMigrationPolicy.payload` |
| Broadcast without signing | Separate application channel or a future extension |

`EventMessage` is a fixed typed `oneof`; nested byte fields hold specific
canonical values, not arbitrary payloads. Domain/client/worker event families
are sealed, so adding a Dart subclass does not add wire routing or validation.

## Signed text and JSON

`forMessage` carries exact UTF-8 text in typed metadata and requests one
untweaked threshold signature over its tagged digest. Recipients inspect that
text, validate the application schema and policy, then approve the exact
proposal. The resulting `SignedMessage` is portable and independently
verifiable.

Text and the separate explanation are each limited to 1,024 UTF-8 bytes. JSON
whitespace, key order and Unicode representation affect the digest; define a
canonical application codec when different implementations must reproduce the
same bytes. Put authorization context such as domain, version, operation ID,
network, recipient and expiry inside the signed text when it must survive as
part of the final signature.

The coordinator can read the text. Iroh encrypts the connection, not content
from the coordinator endpoint.

## Digests and metadata

Signing a digest does not deliver its preimage. Signers need an authenticated
way to obtain and recompute the original document. The request explanation is
only requester-authenticated and can differ from the threshold-signed digest.

`UnknownSignatureMetadata` is not an extension mechanism: it is rejected when
embedded in signing requests and has no bounded body framing there. A new
metadata type needs a type assignment, bounded codec, semantic binding to
`requiredSigs`, and request/event/snapshot/worker tests.

`GroupTransitionMigrationPolicy` intentionally carries opaque, versioned host
bytes, but current transition orchestration does not transport them by itself.

## Future application events

A general event feature needs a bounded typed payload, authenticated RPC,
session-bound sender, recipient authorization, event codec, client/worker
projection and explicit delivery semantics. Durable delivery additionally
needs storage, acknowledgments and deduplication; current event buffering does
not supply them.

The proposed negotiated envelope and module registry are described in
[protocol extensions](protocol-extensions.md). A separate host-owned Iroh ALPN
is another option, but is not an existing `IrohServer` plugin hook.

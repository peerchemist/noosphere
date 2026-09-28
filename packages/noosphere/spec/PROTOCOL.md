# Noosphere protocol

Noosphere coordinates authenticated participants through distributed key
generation and threshold-signing sessions. This document is the home of the
transport-independent protocol semantics. The protobuf schema defines the wire
messages, but not by itself their valid ordering or state transitions.

The current reference implementation supports participant and coordinator
roles. A process may run either role or both. Iroh/QUIC is the reference
transport, not part of the protocol semantics.

The existing client and server behavior remains normative during the initial
monorepo migration. Authentication, session, DKG, signing, expiry, reconnect,
replay and error rules will be transcribed here without changing their current
wire behavior.

## Message signing

[BIP-340 message signing](MESSAGE_SIGNING.md) specifies the wallet-style
message format, request metadata, public API, and implementation. It uses
the existing untweaked ROAST signing flow and is separate from the request
explanations described below.

## Signature request explanations

`SignaturesRequestDetails.message` carries a free-form UTF-8 explanation for
the entire request, independently of its signature metadata. An omitted message
is the empty string. The canonical details encoding appends the message after
the expiry, using the same variable-length byte prefix as other domain strings.
The prefix is present even for an empty message.

The message must not exceed 1024 UTF-8 bytes (excluding its length prefix).
Constructors reject oversized messages; readers reject an oversized declared
length before reading or decoding the message, including for completed requests.

The message is covered by the requester's signature and contributes to the
request ID. Changing it invalidates that signature, but does not change the
individual payloads being threshold-signed. Request events, login replay and
completed requests carry the message as part of the signed details.

This revises the development wire format in place under `VERSIONING.md`;
participants and coordinators must use the same build.

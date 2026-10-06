# Noosphere protocol

Noosphere coordinates authenticated participants through distributed key
generation and threshold-signing sessions. This document is the home of the
transport-independent protocol semantics. The protobuf schema defines the wire
messages, but not by itself their valid ordering or state transitions.

The current reference implementation supports participant and coordinator
roles. A process may run either role or both. Iroh/QUIC is the reference
transport, not part of the protocol semantics.

The [architecture guide](../../../architecture.md) describes authentication,
sessions, DKG, signing, expiry, reconnect, replay and error handling in the
current implementation. Enrollment and ROAST use operation-prefixed QUIC
streams with concrete protobuf request/response bodies on separate versioned
Iroh ALPNs. FIN delimits single-message bodies; only persistent multi-message
streams use QUIC-varint lengths. Canonical domain encodings define signed
payloads inside those messages.

## Message signing

[BIP-340 message signing](MESSAGE_SIGNING.md) specifies the wallet-style
message format, request metadata, public API, and implementation. It uses
the existing untweaked ROAST signing flow and is separate from the request
explanations described below.

The proposed workflow for coordinator-initiated membership changes, signer
consent and automatic migration is described in
[`GROUP_TRANSITIONS.md`](GROUP_TRANSITIONS.md). It is a design proposal, not
current protocol behavior.

The Flutter [coordinator switching helper](COORDINATOR_ROTATION.md),
`NoosphereWorker.switchCoordinator`, applies an app-approved endpoint change to
one signer, persisting the pin through a host callback. It preserves the existing
ROAST wire protocol and group keys and does not establish group-wide approval
or perform a group transition.

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

Participants and coordinators must use compatible implementations of this
wire format.

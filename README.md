# Noosphere

Noosphere is a protocol and Dart implementation for organizing peer groups
around shared threshold keys. It combines FROST distributed key generation
with ROAST coordination so a group can create a key and authorize transactions
or messages without any participant holding the complete private key during
normal operation.

The protocol has two roles:

- **Participants** hold independent identity keys, review proposals and keep
  their own FROST key shares.
- A **coordinator** authenticates the participants, orders the work, routes
  protocol messages and collects enough valid contributions to complete an
  operation. It does not need a participant share and cannot produce a
  threshold signature by itself.

A group first runs distributed key generation (DKG). Every participant receives
a private share while the group receives one public key. Later, any permitted
threshold of the group can use ROAST to produce Schnorr signatures despite
participants being asynchronous or temporarily unavailable. A request may
contain multiple signatures, such as one for every input of a transaction.

Noosphere currently understands two principal kinds of signing request:

- **Transactions**, where typed metadata binds the transaction, signing
  digests, group keys and derivation paths that participants must verify.
- **Messages**, where the exact UTF-8 text is converted to a domain-separated
  digest and signed by the untweaked group key. The result is a portable
  BIP-340 signature that can be verified without the coordinator or signing
  transcript.

The importing application remains responsible for identity presentation, user
consent, key custody, durable storage and application policy. For a wallet,
that also includes constructing, validating, broadcasting and tracking
transactions. Noosphere coordinates cryptographic authorization; it does not
decide what the group should authorize.

## Encrypted peer-to-peer communication

Noosphere uses [Iroh](https://iroh.computer) as its reference network transport. Iroh provides
authenticated, encrypted peer-to-peer QUIC connections, endpoint identity,
discovery and direct connectivity with relay fallback. Participants pin the
coordinator's Iroh identity independently of its changing network addresses.

Protocol traffic is coordinator-routed rather than a participant gossip
network. A participant sends an authenticated request to the coordinator, and
the coordinator delivers the resulting events to the relevant participants
over their persistent Iroh sessions. Participant signatures embedded in those
events provide end-to-end authenticity for signed proposals and contributions.
The coordinator is still trusted for availability and routing: it can delay,
omit or replay traffic, but it cannot silently alter participant-signed content
or sign on behalf of the threshold group.

Iroh is the reference transport, not the definition of the protocol. The
domain model, canonical signed encodings and state transitions remain separate
from their protobuf and QUIC representation.

## Events define the protocol

An `Event` is a typed input from the coordinator to a participant's protocol
state machine. It can announce something to review, carry another
participant's contribution, start a signing round, report progress or deliver
a result. Processing an event may verify cryptographic data, change local
state, write durable state, send a follow-up request and expose a higher-level
notification to the host application.

The core event family covers:

- participant presence and session state;
- DKG proposals, commitments, encrypted round-two shares and acknowledgements;
- signing proposals, ROAST rounds, progress, completion and failure;
- encrypted recovery-share delivery and key-reconstruction notices; and
- transport keepalives.

These events are the vocabulary of Noosphere. Their allowed order, validation
rules and state effects define its behavior. The protobuf schema alone does
not: a message that can be decoded may still be invalid for the current group,
request, round or participant.

```text
participant request
  -> coordinator validation and state transition
  -> typed domain Event
  -> protobuf EventMessage on an encrypted Iroh session
  -> participant validation and state transition
  -> optional application-facing notification or follow-up request
```

Network events are a sealed, typed set rather than arbitrary application
messages. Each event has an explicit protobuf variant and protocol meaning.
Applications see later client or worker projections of selected outcomes;
those local notifications are not the network events themselves and the event
stream is not a durable application log.

## Protocol extensions

Security-critical behavior such as login, DKG, ROAST, signature results and
key recovery belongs in the typed core protocol. Transaction and message
metadata are also defined types: unknown metadata cannot be used to smuggle an
unreviewed signing operation or as a generic broadcast channel.

A negotiated extension mechanism is proposed for optional,
application-specific collaboration. It would add one stable `ExtensionEvent`
envelope containing an extension ID, negotiated version, event type,
deduplication ID and bounded payload. Registered extension packages would own
their typed codecs and validation, while Noosphere would enforce capability
negotiation, routing and resource limits.

Extensions are intended to provide context or discovery that composes with the
core protocol. For example, a Peercoin minting extension could announce and
validate a staking candidate, then hand the exact digests to the ordinary
review and ROAST signing flow. An extension must not bypass participant
approval, weaken signing policy or gain direct access to private FROST state.

The extension envelope and registry are a design proposal and are not
implemented in the current protocol. Today, adding a network event requires a
coordinated change to the core event model, wire schema, coordinator and
participant state machines.

Further detail is available in the
[protocol semantics](packages/noosphere/spec/PROTOCOL.md),
[event model](architecture/events.md),
[protocol extension design](architecture/protocol-extensions.md) and
[security model](packages/noosphere/spec/SECURITY.md).

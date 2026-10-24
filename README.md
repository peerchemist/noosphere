# Noosphere Network

Noosphere framework for decentralized off-chain applications.
Noosphere combines peer-to-peer networking, group coordination and threshold
signing. Your app defines the rules; participants approve operations and sign
together without assembling the complete private key.

**[FROST](https://eprint.iacr.org/2020/852)** handles shared keys and signatures,
**[ROAST](https://eprint.iacr.org/2022/550)** coordinates signing, and
**[Iroh](https://www.iroh.computer/)** connects peers. Your app owns the UI, key
custody, storage and chain integration.

## What you can build

- **Shared wallets and treasuries:** require several owners to approve payments.
- **Multi-device wallets:** spread signing authority across devices.
- **Team approvals and attestations:** sign commands, documents or statements as a group.
- **Signing services:** embed participants and coordinators in apps or headless services.

For example, three of five treasury members can authorize a payment. Noosphere
returns the group signature; your app constructs, validates and broadcasts
the transaction. The receiving system must accept the group's public key and
signature scheme.

## How FROST and ROAST fit together

A group has a roster of participants and a signing threshold, such as 3-of-5.
There are two roles:

- **Participants** authenticate with their own identity keys, review proposals,
  and hold their own private FROST shares.
- A **coordinator** authenticates participants, orders protocol operations,
  routes messages and collects contributions. The coordinator role does not
  require a FROST share and cannot sign on the group's behalf by itself.

During **distributed key generation (DKG)**, participants jointly create a
shared public key and a private share for each participant. There is no dealer
that first creates and distributes a complete private key. Participant identity
keys, the coordinator's Iroh identity and the generated FROST shares have
separate purposes; restoring an identity mnemonic does not restore a FROST
share.

**FROST** lets a threshold of participants contribute to one Schnorr signature.
**ROAST** coordinates signing attempts so slow, unavailable or uncooperative
participants need not prevent completion when enough responsive, cooperating
signers remain. It does not remove the threshold requirement or the need for
an available coordinator.

```text
Form a group and choose a threshold
  -> jointly generate a key with DKG
  -> propose a transaction or message
  -> participants review and approve
  -> ROAST coordinates FROST signing contributions
  -> verify the resulting group signature
  -> application records the result and acts on it
```

Noosphere orchestrates the cryptography through Frosty and Coinlib. It also
supports encrypted recovery-share delivery and explicit key-reconstruction
workflows; recovery is separate from normal threshold signing and its policy
belongs to the application.

## What can be signed

The protocol currently defines two principal kinds of signing request:

- **Transactions:** typed metadata binds the transaction, signing digests,
  group keys and derivation paths that participants must verify. One request
  can ask for multiple signatures.
- **Text messages:** the exact UTF-8 text is converted to a domain-separated
  digest and signed with the untweaked group key. The resulting `SignedMessage`
  contains a portable BIP-340 signature that can be verified without the
  coordinator or the signing transcript.

Text messages can carry short JSON documents as well as human-readable text.
The message limit is 1,024 UTF-8 bytes. Applications define their schema and
include any required domain, operation ID, recipient and expiry in the signed
content. Whitespace, key order and Unicode representation affect the signed
bytes, so interoperable JSON workflows need an agreed canonical encoding.

Lower-level digest signing is available through `SingleSignatureDetails`.
Signing a digest does not deliver or explain its original document: the app
must provide an authenticated delivery path and let signers recompute it.
See [application data and signing](docs/architecture/generic-data.md).

## Peer-to-peer communication with Iroh

Iroh provides authenticated, encrypted QUIC connections, endpoint discovery,
direct connectivity and relay fallback. Participants pin the coordinator's
stable Iroh endpoint identity independently of its changing IP or relay
addresses.

The topology is **coordinator-routed**: participants connect to a coordinator,
submit authenticated requests, and receive typed protocol events over
persistent sessions. Participants do not need a full mesh of connections.
A coordinator is embedded in its host application, including an app that also
participates in signing. A co-located participant can use
`LocalCoordinatorApi` to run the same protocol in process.

Iroh authenticates the transport endpoint; separate participant signatures
prove the authorship of signed proposals and contributions. The coordinator
can delay, omit or replay traffic, but cannot silently modify participant-signed
content or manufacture a threshold signature. Transport encryption does not
hide ordinary proposals or message text from the coordinator. DKG and recovery
shares additionally use recipient-specific encryption.

Iroh is the reference transport. Domain models, canonical signed encodings and
protocol state transitions remain separate from deterministic CBOR and QUIC framing.
See [transport details](docs/architecture/iroh-transport.md).

## Stateless library, application-owned persistence

Noosphere is stateless with respect to storage ownership: the library does not
select or operate an application database, own a wallet store, or decide how
secrets are encrypted and retained. The importing application owns durable
state and supplies storage providers and key-access callbacks.

The protocol itself is stateful. Running clients and coordinators maintain
sessions, ceremonies, signing rounds and pending operations in memory. Safe
restart and signing require the host to persist the state specified by the
library's contracts.

| State | Application responsibility |
| --- | --- |
| Identity keys and Iroh secret | Supply secure access and preserve the identities used by peers. |
| FROST shares and recovery material | Protect and persist them independently of identity mnemonics. |
| Signing nonces and prepared operations | Implement atomic writes through `ClientStorageInterface` so crashes or uncertain RPC outcomes cannot cause nonce reuse. |
| Temporary DKG secrets | Store the opaque resume blob through `persistDkgSecret`, restore it explicitly with `importDkgSecret`, and decide when to delete it. |
| Coordinator state | Implement `ServerPersistence` for atomic snapshots of ceremonies, attempts and results. |
| Rooms and invitations | Implement `RoomPersistence` for enrollment state and consumed or revoked invitations. |
| History and external effects | Store approval history, deduplicate results, and track actions such as transaction broadcast. |

Temporary DKG secrets are never included in general client storage or
coordinator snapshots. Noosphere awaits the application's DKG durability
callback before sending the corresponding contribution; a callback failure
prevents submission. After a process restart, the app reads its own secret
store and explicitly imports the saved blob to resume the ceremony.

Reconnection establishes a fresh authenticated session and obtains current
state. It does not blindly replay mutations. DKG can resume with the required
coordinator snapshot and participant secret; unfinished signing attempts are
blocked after coordinator restart. Results can be redelivered, so application
effects must be idempotent. In-memory providers are for tests and demonstrations.
See [state, persistence and recovery](docs/architecture/state-and-persistence.md).

## Enrollment, events and application integration

Rooms let an application collect a roster before key generation. A creator
issues a separate `RoomInvite` for each known participant identity key. The
invite binds a secret token to the room, participant, coordinator endpoint ID
and expiry. Redemption also requires proof of the matching private key, so a
copied link cannot enroll a different signer.

`NoosphereRoomInvite` wraps the invite in an application-owned URI scheme for
clickable links. The app registers the scheme and handles the enrollment UI;
Iroh resolves the coordinator's network route from its endpoint ID. See
[rooms and enrollment](docs/architecture/rooms-and-transitions.md).

Protocol events carry proposals, DKG contributions, signing rounds, progress,
results and recovery notifications. Each has a defined meaning and validation
rules. The app receives client or worker notifications and decides what to
present, approve and retain. The live event stream is not a durable application
history or a general-purpose messaging bus.

Coordinators can optionally enable a separate unauthenticated, read-only
public feed for notifications and transparency. It provides a durable,
redacted journal with signed checkpoints and a lightweight polling client.
See the [public feed integration guide](docs/architecture/public-feed.md).

Negotiated application extensions and end-to-end membership-transition
orchestration are **proposed, not implemented**. Transition models and a
single-signer coordinator-switching helper exist, but do not provide automatic
group governance or migration. See the
[extension design](docs/architecture/protocol-extensions.md) and
[group-transition specification](packages/noosphere_protocol/spec/GROUP_TRANSITIONS.md).

## Packages and getting started

This repository is a Dart workspace with a Flutter facade:

| Package | Purpose |
| --- | --- |
| [noosphere_protocol](packages/noosphere_protocol) | Shared domain types, signed encodings, deterministic CBOR, configuration and room models. |
| [noosphere_client](packages/noosphere_client) | Participant state machine, storage contracts and Iroh client. |
| [noosphere_server](packages/noosphere_server) | Storage-agnostic coordinator state machine, persistence contracts and Iroh server. |
| [noosphere_flutter](packages/noosphere_flutter) | `NoosphereWorker` facade that runs protocol work and cryptography in an isolate. |

For Flutter, start with `package:noosphere_flutter/noosphere_flutter.dart`.
Dart services can import the client and server packages directly. The host
supplies participant identities, trusted group configuration, the coordinator
pin, durable providers and approval handling.

- Run the [desktop demo](apps/demo/README.md) to try DKG and signing across two
  computers. It uses public test identities and temporary storage.
- Follow the [client setup and connection examples](packages/noosphere_client/README.md)
  for a Dart participant, including native-library requirements.
- Use the [server guide](packages/noosphere_server/README.md) to embed a
  coordinator in your application wrapper.
- Read the [architecture guide](docs/architecture/README.md),
  [protocol specification](packages/noosphere_protocol/spec/PROTOCOL.md) and
  [security model](packages/noosphere_protocol/spec/SECURITY.md) for integration
  contracts and trust boundaries.
- See [development and testing](docs/architecture/development-and-testing.md)
  for workspace checks and native integration tests.

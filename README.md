# Noosphere

Noosphere is a protocol and Dart/Flutter library for building applications in
which a group controls one cryptographic signing key. It lets independent
participants create that key together, review requests, and authorize an
operation only when enough participants agree—without assembling the complete
private key during ordinary signing.

It combines **FROST** for distributed key generation and threshold Schnorr
signing, **ROAST** for coordinating signing with asynchronous participants, and
**Iroh** for authenticated, encrypted peer-to-peer communication. The host
application supplies the user experience, approval policy, key custody and
durable storage.

For example, a treasury app can give five people separate key shares and
require three to authorize a payment. Noosphere coordinates their contributions
and returns a signature under the group's public key. The app constructs the
payment, shows each signer what they are approving, and broadcasts the signed
transaction.

## What you can build

Noosphere supplies shared cryptographic authorization that applications can
use for more than payments:

| Application | How Noosphere fits |
| --- | --- |
| Shared wallets and treasuries | Require a threshold of owners to sign compatible transactions; batch signatures for multiple inputs in one request. |
| Personal wallets with multiple devices | Distribute signing authority across devices so one device does not hold the complete signing key. |
| Team approvals and administrative tools | Sign an exact command or policy document after enough authorized members approve; the receiving service verifies the group signature before acting. |
| Collective attestations | Produce a portable group signature over a statement, certificate payload or release manifest that others can verify independently. |
| Document approval workflows | Sign a document digest after the application delivers the document and each signer verifies the bytes and their meaning. |
| Embedded or headless signing services | Integrate participant and coordinator roles into a Dart service or a Flutter application using the same protocol. |

These are application patterns, not bundled products. Wallet integrations must
supply chain-specific transaction construction, validation and broadcasting;
other integrations must define their payload formats, authorization context
and external effects. A group signature only has meaning to a system that
knows the group public key and accepts the signature scheme and signed data.

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
A coordinator can run as a standalone service or be embedded in an app,
including an app that also participates in signing. A co-located participant
can use `LocalCoordinatorApi` to run the same protocol in process.

Iroh authenticates the transport endpoint; separate participant signatures
prove the authorship of signed proposals and contributions. The coordinator
can delay, omit or replay traffic, but cannot silently modify participant-signed
content or manufacture a threshold signature. Transport encryption does not
hide ordinary proposals or message text from the coordinator. DKG and recovery
shares additionally use recipient-specific encryption.

Iroh is the reference transport. Domain models, canonical signed encodings and
protocol state transitions remain separate from protobuf and QUIC framing.
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
| [noosphere_protocol](packages/noosphere_protocol) | Shared domain types, signed encodings, protobuf, configuration and room models. |
| [noosphere_client](packages/noosphere_client) | Participant state machine, storage contracts and Iroh client. |
| [noosphere_server](packages/noosphere_server) | Coordinator state machine, persistence contracts, Iroh server and standalone CLI. |
| [noosphere_flutter](packages/noosphere_flutter) | `NoosphereWorker` facade that runs protocol work and cryptography in an isolate. |

For Flutter, start with `package:noosphere_flutter/noosphere_flutter.dart`.
Dart services can import the client and server packages directly. The host
supplies participant identities, trusted group configuration, the coordinator
pin, durable providers and approval handling.

- Run the [desktop demo](apps/demo/README.md) to try DKG and signing across two
  computers. It uses public test identities and temporary storage.
- Follow the [client setup and connection examples](packages/noosphere_client/README.md)
  for a Dart participant, including native-library requirements.
- Use the [server guide](packages/noosphere_server/README.md) for a headless
  coordinator, or build the container below.
- Read the [architecture guide](docs/architecture/README.md),
  [protocol specification](packages/noosphere_protocol/spec/PROTOCOL.md) and
  [security model](packages/noosphere_protocol/spec/SECURITY.md) for integration
  contracts and trust boundaries.
- See [development and testing](docs/architecture/development-and-testing.md)
  for workspace checks and native integration tests.

## Standalone coordinator container

The coordinator [`Containerfile`](deploy/coordinator/Containerfile) builds the standalone Linux
coordinator from the `noosphere_protocol`, `noosphere_client` and `noosphere_server`
packages at the same workspace revision. The Flutter facade and example are
development hosts rather than server-image runtime dependencies; CI analyzes
and tests them directly on Linux as part of the complete workspace
verification. The container is a deployment artifact, not the integration-test
environment.

Build the image from the repository root so the complete package workspace is
available as the build context:

```sh
podman build --file deploy/coordinator/Containerfile --tag noosphere-server .
```

Docker can be used with the same arguments by replacing `podman` with
`docker`. Copy
[`packages/noosphere_server/config/iroh-server.example.yaml`](packages/noosphere_server/config/iroh-server.example.yaml),
replace the example group and participant keys, and run the image with the
configuration mounted read-only:

```sh
podman run --rm \
  --volume noosphere-data:/var/lib/noosphere \
  --volume "$PWD/config.yaml:/config/server.yaml:ro,Z" \
  noosphere-server
```

The `/var/lib/noosphere` volume preserves both the Iroh identity and protocol
state. No fixed port is exposed because Iroh uses dynamic UDP sockets and can
fall back to the configured relay. A direct-only deployment must publish the
actual UDP socket through its own container-network configuration.

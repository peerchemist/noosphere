# Pubkey-bound room enrollment

Room enrollment is a small protocol in front of the existing ROAST login, DKG
and signing protocol. It does not replace or fork those protocols.

## Public API

The shared package exports `RoomInvite`, `EnrollmentTranscript`,
`EnrollmentChallenge`, `RoomSnapshot` and `RoomEnrollmentApi` from
`package:noosphere/room.dart`.

The coordinator package provides `RoomManager` with `createRoom`, `getRoom`,
`issueRoomInvite`, `revokeRoomInvite`, `beginEnrollment`,
`redeemRoomInvite`, `freezeRoom` and `closeRoom`. `IrohServer.freezeRoom`
freezes and immediately registers the resulting `GroupConfig` with the normal
ROAST dispatcher. Frozen rooms restored at startup are registered likewise.

The participant package provides `RoomEnrollmentClient.joinRoom` and
`IrohRoomEnrollmentApi`. The high-level `IrohRoomEnrollmentApi.joinRoom`
checks the local private key against the invite before opening the connection.
It then verifies the complete server transcript and signs it through
`Signed<EnrollmentTranscript>`.

For Flutter workers, configure `EmbeddedServerOptions.roomPersistence`, then
use `NoosphereWorker.createRoom`, `roomSnapshot`, `issueRoomInvite`,
`revokeRoomInvite`, `freezeRoom`, `closeRoom`, and `joinRoom`. Room snapshots
and rejection diagnostics are emitted as `WorkerRoomEvent` and
`WorkerEnrollmentRejectedEvent`. Worker DTOs contain no private key or invite
token.

## Invite and proof protocol

`RoomInvite` is a base64url-friendly, versioned canonical binary value. It
contains the room/invite IDs, a random 32-byte token, expected compressed
secp256k1 participant key, 32-byte pinned Iroh coordinator ID, connection
hints, and expiry. The participant key is independent of wallet, FROST group,
and Iroh endpoint keys.

The server persists only `SHA256(token)`. The signed transcript is encoded as
length-delimited/fixed-width binary fields in this order:

1. `noosphere/roast-enrollment/1` domain;
2. protocol version;
3. room ID and invite ID;
4. invite-token hash;
5. expected participant public key;
6. pinned coordinator endpoint ID; and
7. fresh 32-byte server nonce.

The transcript signature hash is SHA-256 of those canonical bytes and uses the
existing coinlib Schnorr `Signed<T>` primitive. Challenges are kept only in
memory, have a short TTL, and are removed before proof validation, making every
nonce one-shot even when validation fails.

Enrollment uses `noosphere/roast-enrollment/1`; ordinary protocol traffic
continues on `noosphere/roast/1`. `IrohServer` binds both ALPNs to the same
long-lived endpoint and dispatches on the negotiated ALPN. Freezing does not
rebind the endpoint or generate a new coordinator identity.

## Persistence and migration

`RoomPersistence` stores opaque, versioned room records. An implementation's
`write` method must be atomic and durable. Each record contains room lifecycle,
coordinator endpoint ID, expected count, threshold, token hashes and invite
timestamps, accepted public keys, frozen identifiers, canonical `GroupConfig`,
and its derivable fingerprint. Plaintext invite tokens are never stored.

Existing direct-`GroupConfig` servers require no migration. To enable rooms,
add a `RoomPersistence` implementation while retaining the same
`ServerIdentityStore`. At open time, records whose coordinator ID differs from
the active identity are rejected. Used/revoked invites and frozen rosters are
therefore not reset by restart.

The Flutter worker proxies `rooms.loadAll` and `rooms.write` to the host
isolate, serialized per setup. Applications should back these operations with
the same transactional database discipline as signer persistence.

## Security boundaries and remaining risks

Enrollment prevents invite theft/substitution and enforces a host-selected
participant allowlist; it is not universal Sybil protection. Invite URLs still
contain a secret token and should not be logged. Public rejection events expose
only invite ID, a truncated public-key fingerprint and a reason.

Room records are integrity-sensitive. `RoomPersistence` does not itself add
encryption, authentication, rollback protection, or multi-process locking;
production hosts must provide those properties where their threat model needs
them. Challenges are deliberately not restored after restart, so an in-flight
client must request a new challenge. Connection hints are non-authoritative;
the pinned coordinator endpoint ID remains the trust anchor.

# Data models

[Architecture overview](../architecture.md)

Noosphere separates canonical domain values, generated protobuf messages,
mutable runtime state, durable records and public worker DTOs. Domain values
usually have explicit binary writers/readers; protobuf carries typed network
messages and embeds canonical bytes where signatures require them.

## Identities and groups

| Value | Purpose |
| --- | --- |
| secp256k1 participant key | Login, proposal signatures, attestations and share encryption |
| FROST `Identifier` | Position in one group roster |
| Iroh endpoint ID | Coordinator transport identity and client pin |
| FROST group key/share | Threshold verification key and one participant's secret share |
| `SessionID` | One authenticated logical session |
| `SignaturesRequestId` | First 16 bytes of a request-details signature hash |

These identities are distinct. An Iroh ID is not a participant or FROST key,
and a session or request ID is not authentication by itself.

`GroupConfig` contains a group ID and an identifier-sorted participant-key map
for 2–65,535 participants. Its fingerprint is `SHA256(group.toBytes())`. A
group can create several FROST keys with different thresholds; threshold is a
property of each DKG result, not the roster.

## Ownership and encoding

Treat domain graphs as immutable after construction. Noosphere freezes its
collections and byte views, but Frosty identifiers, commitments, ciphertexts,
nonces and Coinlib transaction graphs may retain native handles or mutable
caches. Do not mutate or dispose them while retained by a model or runtime.
Copy serialized bytes before decoding an independently owned native value.

Worker DTOs contain owned public bytes, scalars and immutable collections;
prefer them for UI state. They deliberately omit private shares and nonces.

`Signable` defines a canonical tagged hash. `Signed<T>` stores the value and a
64-byte participant Schnorr signature. This authenticates protocol authorship;
it is different from the threshold signature produced by ROAST.

`Expiry` stores an absolute time. Canonical domain time uses milliseconds since
epoch, while duration fields and some worker/snapshot fields use microseconds.
Follow each codec rather than assuming one global unit.

## DKG and signing

`NewDkgDetails` defines a name, description, threshold and expiry. DKG models
then carry round-one commitments, encrypted recipient shares and signed ACKs.
Temporary DKG secrets are runtime-only. A DKG ACK attests possession of a key;
it does not bind a complete membership transition.

`SignaturesRequestDetails` contains:

- one or more unique `SingleSignatureDetails` in result order;
- typed `SignatureMetadata`;
- an expiry; and
- an optional requester-authenticated explanation of at most 1,024 UTF-8 bytes.

Each signature detail binds a digest, optional Taproot tweak, group key and
unhardened derivation path. Round starts contain commitment sets; replies carry
an optional current share plus the next commitment. Completion order matches
the requested signature order.

Metadata type `0` is empty, `1` validates Taproot transaction inputs, and `2`
validates one exact signed-message payload. Unknown metadata can be preserved
standalone but is rejected inside a signing request. Metadata validation does
not replace host checks such as recipients, fees, network or business policy.

`SignedMessagePayload` hashes exact UTF-8 text with the
`Noosphere/SignedMessage/v1` tag. `SignedMessage` packages the text, public key
and BIP-340 signature for offline verification.

## Durable and public records

- `FrostKeyWithDetails` contains secret participant key material, ACKs and
  recovery state. It is not a UI object.
- `ClientStorageSnapshot` loads keys, nonces, prepared signing operations and
  rejections consistently. Prepared operations prevent unsafe nonce reuse;
  they are not an automatic replay queue.
- `ServerStateSnapshot` is opaque versioned JSON containing attempts,
  completed results and encrypted recovery shares. It cannot resume live
  cryptographic rounds after restart.
- `RoomInvite` is the participant-bound enrollment credential;
  `NoosphereRoomInvite` only adds an application URI prefix for clickable
  delivery. Room models retain the coordinator endpoint ID, not changing IP or
  relay locations. Transition models encode successor plans and opaque host
  policy. See [rooms and transitions](rooms-and-transitions.md).
- Worker snapshots are public runtime projections, not durable client backups.

Threshold HD paths use unhardened `[86, coinType, account, change,
addressIndex]`. The host chooses and persists indexes. Hardened BIP-32
derivation is unavailable because ordinary FROST operation never assembles an
aggregate private key.

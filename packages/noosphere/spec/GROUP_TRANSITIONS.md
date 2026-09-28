# Group membership transitions

Status: proposed design. This document describes the intended workflow and
requirements for a future implementation; it does not describe an existing
`GroupTransition` API or add wire messages.

## Objective

Adding or removing signers, replacing a signer, or changing the signing
threshold should require users to review and accept a membership proposal.
The applications then perform enrollment, DKG, signing, migration and completion
tracking automatically. Users should not manually create rooms, generate keys,
exchange protocol messages or construct migration transactions.

The initial implementation creates a successor group with a new FROST key and
migrates control to it. It does not edit the roster of an existing frozen group
or preserve its FROST public key through resharing.

For example, an existing `A,B,C` group with threshold `2/3` can transition to
`A,B,D,E` with threshold `3/4`. All four destination participants complete the
new DKG. An available old threshold, such as `A+B`, authorizes and signs the
migration. Removed participant `C` need not cooperate.

## Identity reuse

Retained signers reuse their existing participant authentication key pairs.
The application copies their public keys from the old `GroupConfig` into the
proposed roster. They must not be asked to generate new identity keys merely
because membership changes. A new signer supplies an independently verified
identity public key and proves possession during enrollment. Intentional
identity rotation, loss or compromise is a separate explicit change.

Participant identity keys, FROST shares, the FROST group public key and the
coordinator's Iroh identity are distinct. The successor DKG creates fresh FROST
shares and a new group public key, while retained participant identity keys and
the trusted coordinator identity can stay unchanged.

Cross-group identity matching uses participant public keys, not numeric FROST
identifiers. `freezeRoom` assigns identifiers from the new ordered roster, so
the same person can have a different identifier in the successor group.
Existing shares must not be relabeled or copied into that new identifier map.
The successor has a distinct group ID and fingerprint.

## Roles and authority

An authenticated, authorized coordinator management action can trigger a
transition proposal. The coordinator persists progress, coordinates the new
room and requests the required participant actions. Initiating a proposal
does not grant authority to move funds or approve membership on users' behalf.

Signer applications independently verify the proposal and every derived
operation. Coordinator state such as `approved` is not evidence of signer
consent. The old signing threshold must authorize the final transition and
any migration requiring the old key; new participants must consent to joining
and complete the successor DKG. Additional application governance rules may
require more approvals, but cannot reduce the cryptographic old threshold.

The current DKG and signing request APIs are participant-initiated. A future
orchestration layer can ask an authorized participant application to submit
those requests. The coordinator does not need a signer share to lead the flow.

## One review, bounded automatic execution

The normal UI presents the membership difference, old and new thresholds,
affected accounts, fee limits and expiry, followed by one acceptance action.
After acceptance, the application automatically performs the approved
protocol steps. A user acceptance can authorize multiple protocol signatures;
it is not an unrestricted permission to sign arbitrary requests.

Persisted consent must bind a canonical proposal containing at least:

- A unique transition ID, proposal version, expiry and domain separation.
- The old group ID and fingerprint, affected old keys and old thresholds.
- The exact successor identity public keys and target threshold for each key.
- The successor group ID and the rule deriving its canonical identifier map.
- The authorized DKG attempt identities and a binding to their authenticated
  transcripts and results. Display names alone are not sufficient bindings.
- The accounts, network and assets in scope, allowed destination derivations,
  change-output rules and aggregate fee limits, including replacement attempts.
- The migration completion policy and any explicitly permitted retry behavior.

The new FROST key does not exist when the initial proposal is accepted. It may
only be resolved from the DKG authorized by that proposal. Before signing a
migration, each old signer must verify evidence tying the destination key to
the exact approved roster, threshold and DKG result. This also applies to old
signers that are not members of the successor group and therefore did not
participate in its DKG. A coordinator-supplied destination address is not such
evidence. The protocol must define authenticated result attestations binding
the proposal, transcript, roster, threshold and resulting key; existing
key-only DKG ACKs do not bind all of these fields.

The final transition document binds the proposal hash, both group fingerprints,
the old-to-new key mapping, authenticated DKG results and migration policy.
Its domain-separated canonical payload is threshold-signed by the old group.
`SignaturesRequestDetails.message` is only an explanation: it does not change
the payloads being threshold-signed and cannot serve as this authorization.

Changing the roster, threshold, destination constraints or fee limits beyond
the accepted bounds requires fresh consent. Expired or revoked local consent
must not authorize further signatures. Revocation cannot undo a signature
already released or a transaction already submitted, and one signer's refusal
does not veto a transition authorized by an otherwise sufficient old threshold.

Automatic execution remains subject to secure key access. If a device must be
unlocked or an application kept online, the UI must expose that requirement
without presenting internal DKG or ROAST steps as manual user tasks.

## Workflow and durable state

The proposed happy path is:

`proposed -> preparing -> ready -> migrationPending -> active -> retired`

These states belong to the transition record. In particular, `active` means
the successor is the application's authoritative group, while `retired` means
the old group's routine use has been retired.

1. **Proposed:** create the canonical proposal, show the membership difference
   and collect bounded approvals. Keep the current group operational.
2. **Preparing:** enroll the exact approved successor roster, automatically
   prove possession using retained identity keys, freeze the new room and run
   DKG. All successor members must participate in the current DKG protocol.
   Store new shares durably before acknowledging readiness.
3. **Ready:** validate the result against the proposal, collect readiness
   evidence from all successor participants and verify a test signature from
   a new threshold. A test signature alone does not prove that every member
   has durably stored its share. Resolve and sign the final transition document.
4. **Migration pending:** the host prepares policy-compliant migration
   operations, old signer applications validate and sign them automatically,
   and the host submits and monitors them. Coordinate ordinary outgoing
   operations with migration to prevent conflicting spends or missed assets.
5. **Active:** after the host verifies the specified completion evidence,
   durably switch the application's authoritative group and direct new
   requests and receiving addresses to it. Coordinator success alone is not
   sufficient completion evidence.
6. **Retired:** reconcile pending old requests and retire routine old-group
   signing. Close old coordinator routing when appropriate. Keep the history
   and any explicitly scoped recovery capability required for residual assets.

For wallets, migration means transferring all in-scope assets to destinations
derived from the successor keys and checking the required chain confirmations.
For other consumers it can mean replacing an accepted verification key. The
host defines and verifies that application-specific completion condition.
Multiple keys and derived accounts require an explicit coverage map and
per-operation progress; completing one transfer does not complete the group
transition. Continue monitoring old wallet addresses for late deposits, with
an explicit policy for sweeping them or obtaining fresh approval.

Before migration has external effects, failure or expiry can leave the old
group active and the successor inactive. After a signature has been released
or submission may have occurred, do not assume rollback is safe. Represent
interrupted, failed and ambiguous attempts durably and reconcile their actual
outcomes before continuing. Partial migrations must expose remaining work and
must not be marked complete or cause deletion of needed old shares.

Persist proposal hashes, consent, DKG attempt bindings, readiness evidence,
prepared signing operations, submitted transaction identifiers, completion
evidence and activation decisions. Restore progress after restart without
blindly replaying mutations or reusing signing nonces. DKG temporary state is
not currently durable: an interrupted attempt may need a fresh attempt, which
must be covered by explicit retry bounds or receive fresh consent.

Serialize activation for each source group generation and prevent competing
successor migrations. Enforce this in durable host state and signer policy,
including across concurrent processes; an in-memory coordinator flag is
insufficient. Stale proposals and replayed approvals must not authorize a new
transition. Closing a room only stops its coordinator routing; it does not
invalidate previously distributed cryptographic shares.

## Library and host responsibilities

The proposed library orchestration layer owns the transition model,
canonical encodings, consent checks, identity and DKG bindings, participant
coordination, progress events and persistence contracts. It reuses enrollment,
DKG, ACK distribution and ROAST signing, extending their evidence where needed.
Durable storage must support storing a successor without replacing the active
source, and must explicitly record which group generation is authoritative.

The host owns trusted identity presentation, secure key access, durable storage,
account and asset discovery, transaction construction, fee estimation,
broadcasting and external completion verification. Host callbacks drive these
steps automatically under the approved policy; they are not manual user steps.
The Flutter worker facade will need commands and public progress DTOs for the
workflow, including scoped consent and host integration. An illustrative
`GroupTransition` name here does not imply these APIs already exist.

The UI should normally show approval counts, waiting for participants,
migration progress and completion. It should surface a recovery action only
when automatic progress is blocked or a change exceeds the approved policy.

## Availability and recovery limits

The application should encourage migration while enough old signers remain
available, using reachability and the margin above threshold as advisory
signals. Reachability is not proof that a signer is lost or that its stored
share is usable. Being offline must not automatically remove a participant or
authorize a membership change.

Once fewer than the old threshold can cooperate, this workflow cannot recover
control of the old key without a separately established recovery mechanism.
Making a new group is still possible, but does not grant access to old assets.

`shareKeySecret` is not the membership-transition mechanism: it distributes
existing secret shares for reconstruction of the full private key. Neither
identity-key reuse nor automated migration should invoke it implicitly.

Preserving the existing FROST public key requires a separate reviewed resharing
protocol and versioned share epochs throughout storage, requests and sessions.
It is outside this initial design. Even with resharing, an old threshold that
retains its old shares can still sign under the unchanged public key. Moving
assets or verification authority to a new key is what removes that old key's
authority over the migrated resources.

# Resumable DKG with independently connected participants

Status: proposed implementation plan. No protocol or implementation changes are
included in this document.

## Objective and limits

Allow every participant in a FROST DKG ceremony to contribute at different times,
including across coordinator and client restarts. No two participants need to
be connected simultaneously. The resulting key remains usable by the existing
ROAST signing flow.

All members of the fixed DKG roster must still contribute before the ceremony
can succeed. A 2-of-3 signing threshold does not make this a 2-of-3 DKG. A member
that never returns can prevent completion; expiry ends the attempt. Changing
the roster requires a new ceremony. This work does not introduce a different
cryptographic DKG, tolerate permanently missing contributors, or change ROAST
signing rounds.

The coordinator provides durable storage and delivery of public commitments
and recipient-encrypted shares. Intermediate private DKG secrets remain on
participant devices. Participants continue to verify the common commitment
transcript and received shares independently.

## Current implementation constraints

Start with `packages/noosphere_server`:

- `lib/src/server/state/state.dart`: `endSession` resets round-two ceremonies
  and removes the departing participant's round-one commitment. Snapshots do
  not preserve enough information to resume round two.
- `lib/src/server/state/dkg.dart`: round two retains an expected hash and a
  list of contributors, but neither the complete commitments nor ciphertexts.
- `lib/src/server/api_dkg.dart`: recipient validation uses live sessions;
  round-two shares are forwarded only to connected recipients. The final
  upload removes the ceremony before recipients necessarily finish.
- `lib/src/server/api_sessions.dart`: login returns only round-one ceremonies.
- The DKG acknowledgement cache is not a durable, ceremony-specific completion
  record and cannot serve as the sole basis for delivery cleanup.

Related changes are necessary outside the server:

- `packages/noosphere_client/lib/src/client/client_events.dart` also resets
  DKG state on peer logout and treats duplicate shares as errors.
- The client storage contract does not include unfinished DKG state.
- Frosty 5.0.1 exposes `DkgRound1Secret` and `DkgRound2Secret` as opaque native
  objects without a Dart serialization API. Saving the Dart wrapper cannot
  preserve the secret across process restarts.

## Proposed exchange

1. **Collect commitments.** Each member approves the signed proposal, durably
   saves its private round-one state and outgoing commitment, and uploads the
   commitment. Disconnecting leaves that contribution intact.
2. **Freeze the transcript.** Once the complete roster has contributed, retain
   an immutable, canonically ordered commitment set. Members retrieve it when
   they next connect, verify it, and pin its hash locally for this ceremony.
3. **Collect encrypted shares.** Each member prepares and durably saves its
   private round-two state and exact outgoing payload, then uploads a transcript
   signature and encrypted shares addressed to every other member.
4. **Finalize locally.** Members retrieve their addressed shares and the
   necessary transcript signatures, verify all required contributions, and
   derive and durably store their final key share.
5. **Acknowledge and retain.** Members send a signed, ceremony-specific success
   acknowledgement after saving the key. The coordinator retains delivery data
   until completion or the agreed expiry/retention boundary.

Example with only one participant online at a time:

| Visit | Work |
| --- | --- |
| Alice | Upload round-one commitment |
| Bob | Upload round-one commitment |
| Carol | Upload final commitment, retrieve frozen transcript, upload round two |
| Alice | Retrieve transcript and upload round two |
| Bob | Retrieve transcript, upload round two, retrieve shares and finish |
| Alice | Retrieve remaining shares and finish |
| Carol | Retrieve remaining shares and finish |

## Phase 1: Define the server-owned ceremony record

Introduce a unique ceremony ID, distinct from the user-facing name. Bind the ID,
group fingerprint, fixed roster, threshold, expiry, and protocol version into
the signed proposal and the canonical transcript. Bind subsequent submissions,
retrievals, acknowledgements, and rejection records to that ceremony.

Represent durable stages explicitly:

`collecting commitments -> collecting shares -> awaiting completion -> completed`

Rejection, cryptographic failure, and expiry are terminal outcomes. Session
creation, replacement, expiration, and disconnection do not change DKG stage.

The durable record should contain:

- Signed proposal, creator, fixed roster, and ceremony ID.
- Commitments indexed by participant, retained after transition to round two.
- Frozen transcript and its hash once all commitments have arrived.
- Accepted round-two payloads indexed by sender, including transcript signatures
  and ciphertexts indexed by recipient.
- Signed completion acknowledgements and terminal outcome, when present.
- Deadline and retention metadata sufficient for deterministic cleanup.

Use the existing host-owned atomic snapshot contract. Persist accepted inputs
and stage transitions before responding or publishing events. Preserve the
existing fail-closed handling of uncertain persistence outcomes. Restore the
same stage and accepted contributions after a coordinator restart.

## Phase 2: Add resumable protocol operations

Extend `noosphere_protocol`, server handlers, and both remote and local API paths:

- Provide an authenticated ceremony snapshot/fetch operation usable at any
  stage, with only the caller's addressed ciphertexts exposed to that caller.
- Return or advertise resumable ceremonies during login, including round two
  and pending completion. Events notify clients of progress; durable fetches
  remain sufficient for recovery after missed events.
- Make submission retries idempotent by ceremony, participant, and round.
  Identical accepted payloads return success even after the stage advances;
  different payloads for the same contribution are rejected.
- Validate the recipient set as exactly the fixed roster minus the sender,
  regardless of who is connected.
- Add signed completion acknowledgements bound to ceremony ID, transcript hash,
  and resulting group public key. Distinguish these from existing key possession
  acknowledgements and from mere transport receipt.
- Preserve terminal records long enough to answer uncertain retries and prevent
  delayed traffic from reviving an expired or rejected ceremony.

Keep snapshots and live events ordered so a client cannot miss a contribution
between fetching and subscribing. Clients must tolerate duplicate delivery and
buffer or fetch prerequisite state when a notification arrives out of order.
Set explicit limits for roster size, payload bytes, active ceremonies, and
retained data; pairwise share storage grows quadratically with roster size.

## Phase 3: Enable durable participant secrets

Add and release Frosty support for versioned serialization/deserialization of
both intermediate DKG secret types. Verify the underlying Rust implementation's
serialization and object-consumption behavior before defining the API. Validate
restored secrets against the local participant and ceremony parameters.

Treat exported bytes as private key material. Host storage must protect them,
and logging, public snapshots, and coordinator persistence must exclude them.
Define the format and disposal behavior, including temporary byte copies. Do
not replace serialization with newly generated randomness on resume.

Extend `ClientStorageInterface` and storage snapshots to atomically retain:

- Approved ceremony details and the pinned transcript, when available.
- Current intermediate private secret and exact pending outgoing payload.
- Received contributions or sufficient durable retrieval/progress information.
- Finalization state and pending completion acknowledgement.

Persist preparation before every network submission. After an uncertain response,
retry the same payload or reconcile it with server state. Commit the final key
and recoverable acknowledgement state before discarding intermediate secrets.
If required local secret material is lost, explicitly fail the attempt; do not
silently replace a previously published commitment.

## Phase 4: Resume the client and host workflows

Remove peer-presence-driven DKG resets. Load unfinished local ceremonies before
reconciling server snapshots, verify the frozen transcript, and advance only
when the required inputs are present. Persist the exact transcript a participant
has signed and refuse a different transcript for the same ceremony.

Allow reconnect and process restart in every stage. Repeated identical shares
are harmless; conflicting shares remain errors. Never treat fetching a proposal
as user approval. Existing approval decisions should survive restart.

Update Flutter worker messages, production storage providers, demo integrations,
and progress DTOs as required. Present separately which participants have uploaded
and which have finished; offline status must not imply failed DKG. Reuse the
existing key storage and signing interfaces after successful finalization.

## Completion, expiry, and security rules

- Receiving the last round-two upload advances to awaiting completion; it does
  not establish that every participant has a usable key. Mark the ceremony
  completed only after all roster members acknowledge the same transcript/key.
- Retain delivery material through the agreed completion deadline. Define any
  delivery grace period in the signed proposal rather than silently extending
  the existing expiry semantics. For the initial implementation, use a single
  signed deadline for contributions and completion.
- Retain a compact terminal record after cleanup. Expiry or rejection cannot
  revoke a key share already derived; terminal status must not claim otherwise.
- Require the complete set of valid participant transcript signatures before
  accepting local finalization. A coordinator mailbox is not by itself a
  cryptographic broadcast guarantee.
- Review how ceremony, transcript, sender, and recipient are authenticated with
  each encrypted share. Explicitly bind this context in the signed envelope or
  authenticated encryption construction; do not rely only on transport sessions.
- Preserve the existing abort-on-invalid-input behavior. A changed roster,
  replacement commitment, or fresh attempt needs a new ID and fresh DKG secrets.
- Keep ciphertexts and private ceremony details out of the public feed. Update
  feed completion semantics to reflect participant completion acknowledgements.

The asynchronous delivery design must preserve the underlying FROST assumptions.
The [ZF FROST DKG documentation](https://frost.zfnd.org/tutorial/dkg.html) describes
the shared commitment view and authenticated confidential share delivery that
the implementation must maintain. Review the final transcript/envelope design
against those requirements before release.

## Delivery order

1. Define the ceremony record and invariants starting in `noosphere_server`;
   specify the required shared domain values alongside it.
2. Implement protocol operations, durable server transitions, and server recovery
   tests with explicitly controlled participant inputs.
3. Add Frosty intermediate-secret serialization and verify round-trip recovery.
4. Implement client persistence, retry/reconciliation, and host provider updates.
5. Add end-to-end non-overlap tests, then update the architecture docs.

Define one wire protocol and persistence grammar for the feature. Inputs outside
those grammars have no DKG meaning and fail ordinary parsing or validation.

Server-only work is a useful first milestone but does not deliver restart-safe
asynchronous DKG until Frosty and client persistence are available.

## Verification and acceptance criteria

- Complete a 2-of-3 DKG with strictly non-overlapping participant sessions, then
  produce and verify a ROAST signature with the resulting key.
- Repeat with client processes recreated between visits and coordinator restarts
  during commitment collection, share collection, and pending completion.
- Inject failures before and after durable writes and responses. Retry each
  operation without replacing contributions or losing accepted messages.
- Exercise a lost final upload response, a lost completion response, duplicate
  notifications, and shares arriving before the client has reconciled its stage.
- Prove a recipient can retrieve every required share after all senders disconnect
  and after the final sender uploads.
- Reject conflicting retries, wrong recipient sets, unknown participants, changed
  transcripts, invalid signatures/ciphertexts, and messages from another ceremony
  with the same display name.
- Verify callers cannot retrieve another participant's ciphertext mailbox and
  that snapshots/logs never contain participant intermediate private secrets.
- Verify rejection/expiry cleanup, terminal retry behavior, malformed snapshot
  handling, and missing local secret handling.
- Verify a missing participant leaves the ceremony pending until its deadline;
  the signing threshold must not accidentally become the DKG completion quorum.
- Cover both Iroh and in-process APIs and the production Flutter storage path.

Acceptance requires successful key creation and signing after independent visits
and restarts, with no interval requiring simultaneous participant presence.

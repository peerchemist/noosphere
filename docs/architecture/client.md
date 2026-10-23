# Participant client

[Architecture overview](README.md)

`Client` is the transport-independent participant state machine. It consumes
an `ApiRequestInterface`, configuration, durable storage and an asynchronous
participant-key provider. The application decides whether to approve a
proposal; the client validates and performs the protocol work.

## Login and state

Login loads one consistent storage snapshot, signs the coordinator's challenge,
validates the server snapshot, restores safe operation state and attaches the
event stream. Completed signatures are reverified against local keys. Missing
DKG ACKs and encrypted recovery shares are then processed.

Session extension normally starts 15 seconds before expiry, with a 10-second
minimum wait. Extension or event-processing failure ends the session; a
reconnecting wrapper creates a new `Client`.

Internal locks serialize work per DKG, signing request and stored key. Public
getters return projections or reconstructed copies, not substitutes for the
host store.

## DKG

1. The initiator signs `NewDkgDetails`, runs Frosty part one and submits its
   commitment. Initiation counts as local acceptance.
2. Every other roster member explicitly accepts and submits a commitment.
   DKG requires the full roster even when the future signing threshold is
   smaller. Approval and rejection pass both the reviewed proposal name and
   ceremony ID; the client validates both under the ceremony lock so a reused
   name cannot redirect a delayed decision to a replacement proposal.
3. Each participant validates the full commitment set, runs part two, signs
   the commitment-set binding and encrypts one share per recipient.
4. Recipients fetch only their addressed mailbox, verify every sender's
   transcript signature, decrypt their shares and run part three.
5. The client persists the new key before sending a completion acknowledgement
   bound to the ceremony, transcript and resulting group public key.

`NewDkgDetails` protocol version 4 authenticates the target group fingerprint
(and therefore its roster identity keys), a fresh 32-byte attempt ID, threshold,
expiry and display metadata. Reusing a display name does not reuse an attempt.
The canonical transcript includes that signed proposal and the complete
commitment set.

Disconnecting does not remove a commitment or reset round two. On login, the
client fetches the durable ceremony snapshot, tolerates identical deliveries,
rejects conflicting deliveries and resubmits the exact prepared round-two
payload when it is still available. Snapshot reconciliation preserves verified
commitments delivered by events while the fetch was in flight. Invalid proofs,
ciphertexts or shares
reject the attempt.

Noosphere remains stateless with respect to durable application data. For
crash-safe DKG, the host supplies `persistDkgSecret`; Noosphere awaits that
callback after preparing each round's opaque private state and before sending
the corresponding contribution. A failed callback prevents submission. The
host protects and atomically replaces those bytes in its own storage, then
imports them after recreating the client. `Client.exportDkgSecret` (or the
matching worker API) remains available for explicit export, but exporting only
after a transition is not a durability barrier for the preceding submission.
Until matching state is imported, a published contribution is exposed as
non-resumable and explicit refresh fails with `MissingDkgSecret`; the host may
still reject it. Noosphere never substitutes fresh randomness. See the
[resumable DKG persistence contract](state-and-persistence.md#resumable-dkg-boundary).

Stored FROST keys carry the ceremony ID and transcript hash that created them.
Recovery matches those values rather than the display name. A fetched snapshot
must match the locally requested ceremony before the client sends an ACK or
changes state.

## Signing

To create a request, the client validates keys and metadata, signs the proposal,
generates commitments/nonces and atomically persists the prepared operation
before sending it.

On receipt, it verifies the creator, expiry, metadata, group keys and reported
progress. Missing keys cause durable rejection; otherwise the application
accepts or rejects. Acceptance prepares nonces and initial commitments before
network I/O.

For each ROAST round, the client verifies the signature index, threshold,
roster members, exact commitment set and local nonces. It creates a share plus
fresh next-round commitments, then atomically records consumed transcripts and
replacement nonces before replying. Final signatures are derived and verified
with any required Taproot tweak. Completion is published only after durable
request cleanup.

The client never broadcasts a blockchain transaction. The host owns transaction
policy, submission and confirmation tracking.

## Keys, recovery and lifetime

`KeyPurpose` tells the host why an identity key is requested; returning a key
does not approve the pending business action. Worker approvals also echo exact
proposal bytes. Direct API users must provide an equivalent review-to-action
binding.

`shareKeySecret` is an explicit recovery feature: it encrypts FROST shares for
selected participants until the full private key can be reconstructed. It is
not routine signing or membership change and is intentionally absent from the
public worker API.

`Client.events` is single-subscription. Protocol faults close the session.
Logout cancels timers, waits for recorded event work and closes transport.
Disconnected clients are not reused; direct reconnect users must replace their
references, while the worker does so internally.

See [events](events.md) and [state and persistence](state-and-persistence.md)
for delivery and crash-safety details.

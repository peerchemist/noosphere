# Rooms, group transitions and coordinator changes

[Architecture overview](../architecture.md)

Rooms enroll a roster before ROAST login. Coordinator rotation changes the
trusted transport endpoint while preserving a group. Group transitions replace
membership and create successor keys. These are separate workflows.

## Rooms and enrollment

A `RoomInvite` binds a secret token, expected participant key, room,
coordinator ID and expiry. Stored snapshots keep only the token hash. Enrollment
requires both the token and proof of the expected participant private key.

The host issues one `RoomInvite` per previously collected signer identity
public key. `NoosphereRoomInvite` is a transport-only UX wrapper that prepends
an application URI prefix to the invite's canonical, unpadded Base64URL
encoding. It carries no roster, wallet metadata, JSON payload or second set of
connection fields.

```text
creator collects signer public key
  -> coordinator issues participant-bound RoomInvite
  -> host creates clickable NoosphereRoomInvite link
  -> signer decodes link and supplies the matching private key
  -> Iroh discovers the pinned coordinator endpoint ID
  -> BeginEnrollment challenge
  -> signer proof and RedeemRoomInvite
```

Room and invite models retain only the stable Iroh coordinator endpoint ID.
They neither persist nor distribute coordinator IP addresses or relay URLs;
Iroh discovery owns resolution of the current route.

```text
enrolling --issue/revoke/redeem--> enrolling
enrolling --freeze complete roster--> frozen
enrolling|frozen --close--> closed
```

`RoomManager` restores rooms through explicit `RoomPersistence` and serializes
all mutations. Pending invites reserve capacity. Invite consumption and
participant insertion are persisted atomically; an ambiguous write blocks more
mutations until reload.

Enrollment uses `noosphere/roast-enrollment/1` with two RPCs:

1. `BeginEnrollment` validates the invite and returns a fresh, short-lived
   transcript challenge.
2. `RedeemRoomInvite` consumes the challenge, verifies the transcript signature
   and durably enrolls the participant.

Challenges are removed before proof validation and are not durable, preventing
replay. Used/revoked invitations are durable. Management actions—create,
invite, freeze and close—are local host APIs, not public enrollment RPCs.

Freezing sorts participant public keys and assigns identifiers `1..n`, then
builds a `GroupConfig` using the room ID. Enrollment order does not affect the
roster. The server registers the frozen group on the existing Iroh endpoint;
ordinary login and DKG follow separately.

Room threshold is policy metadata and can currently be `1..capacity`, while
DKG requires at least two. The host must choose a valid DKG threshold. Closing
a room stops future routing but cannot revoke already distributed shares.

## Coordinator changes

- Changed relay/IP hints under the same endpoint pin use
  `updateSignerAddress`.
- Moving a coordinator while preserving its Iroh key preserves the pin.
- A new endpoint identity requires app-approved `switchCoordinator`.

Switching stops the signer, rejects unresolved prepared signing state, persists
the approved coordinator selection, then reconnects to the same group under the
new pin. It is serialized but not atomic across storage and network. Failure
can leave the signer stopped, and there is no automatic fallback or group-wide
vote. See the [host workflow](../packages/noosphere/spec/COORDINATOR_ROTATION.md).

## Group transitions

Implemented shared models provide canonical values for:

- source/successor rosters and thresholds;
- exact authorized DKG proposal hashes;
- opaque, versioned host migration policy; and
- identity-signed proposal approvals.

Participants are compared by identity public key, not FROST identifier; a
retained participant may receive a different successor identifier. A proposal
does not yet contain the successor FROST key because DKG has not created it.
An individual approval proves consent only—not old-threshold authorization,
successor readiness or completed migration.

End-to-end transition orchestration is **proposed, not implemented**. The
design in [`GROUP_TRANSITIONS.md`](../packages/noosphere/spec/GROUP_TRANSITIONS.md)
creates a fresh group/key, proves readiness, authorizes migration under the old
threshold and activates only after host-verified external completion. The host
owns governance, assets, fees, submission and completion evidence. Reusing an
identity does not reuse a FROST share; recovery-share exchange is not a
membership-change mechanism.

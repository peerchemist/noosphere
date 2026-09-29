## Unreleased

- Add canonical group-transition proposals, bounded host migration policies,
  exact DKG plan bindings, and participant identity-key approvals.
- Add versioned pubkey-bound room invites, canonical enrollment transcripts,
  room lifecycle snapshots, and the transport-independent enrollment API.

## 0.1.0

- Establish the transport-independent Noosphere protocol package.
- Move the canonical protobuf schema, generated messages and bounded framing
  implementation from the client package.
- Own the shared ROAST domain model, group configuration, serialization
  utilities and Iroh transport settings used by both client and server.
- Preserve the existing wire format and protocol tests.

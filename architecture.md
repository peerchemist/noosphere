# Architecture

## Storage ownership

- Noosphere does not provide or own a persistent storage backend.
- Noosphere defines opaque, versioned storage records and the host interface
  used to load and persist them.
- Sygnature implements durable, encrypted storage behind that interface.
- The noosphere runtime may keep caches and active challenges in memory.
- Every security-sensitive state transition must be persisted successfully
  through the host interface before the new state is published or used.
- After a restart, noosphere reconstructs its state machines exclusively from
  the records returned by Sygnature through the host interface.

This boundary keeps storage policy, encryption, and key custody in the host
application while leaving record semantics and state-machine validation in
noosphere.

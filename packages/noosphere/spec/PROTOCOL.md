# Noosphere protocol

Noosphere coordinates authenticated participants through distributed key
generation and threshold-signing sessions. This document is the home of the
transport-independent protocol semantics. The protobuf schema defines the wire
messages, but not by itself their valid ordering or state transitions.

The current reference implementation supports participant and coordinator
roles. A process may run either role or both. Iroh/QUIC is the reference
transport, not part of the protocol semantics.

The existing client and server behavior remains normative during the initial
monorepo migration. Authentication, session, DKG, signing, expiry, reconnect,
replay and error rules will be transcribed here without changing their current
wire behavior.

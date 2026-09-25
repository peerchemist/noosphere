## 3.0.0

- Breaking: replace the gRPC server transport and CLI with Iroh QUIC.
- Add a persistent endpoint identity, endpoint-ID bootstrap output, relay
  policies, deadlines and connection/stream limits.
- Add complete Iroh coverage for authentication, DKG, signing, key sharing,
  reconnects and ambiguous outcomes.
- Add an AOT container build with pinned Iroh, Frosty and secp256k1 native
  libraries and a persistent identity volume.
- Remove gRPC code, configuration, dependencies and tests.
- Require Dart 3.13, Frosty 4.0.0 and noosphere_client 4.0.0.

## 2.0.0

- Moves to frosty 3.0.0 requiring new library binary.
- Implements `shareSecretShare` and `ackKeyConstructed` moving to protocol 2.
- Fixes sending of events when stream is closed.

## 1.0.0

Initial release of Noosphere ROAST server

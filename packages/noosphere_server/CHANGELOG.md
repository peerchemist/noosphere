## Unreleased

- Breaking: Move YAML parsing to the standalone CLI adapter and remove map/YAML methods
  from runtime configuration classes.

- Remove the production dependency on `noosphere_client`; shared protocol and
  domain types now come directly from `noosphere`. Client-based end-to-end
  tests retain a dev-only dependency.
- Add durable room enrollment state, invite lifecycle enforcement, Iroh ALPN
  dispatch, and dynamic activation of frozen groups in the ROAST dispatcher.

## 3.0.0

- Breaking: replace the gRPC server transport and CLI with Iroh QUIC.
- Add a persistent endpoint identity, endpoint-ID bootstrap output, relay
  policies, deadlines and connection/stream limits.
- Add complete Iroh coverage for authentication, DKG, signing, key sharing,
  reconnects and ambiguous outcomes.
- Add an AOT container build with pinned Iroh, Frosty and secp256k1 native
  libraries and a persistent identity volume.
- Remove gRPC code, configuration, dependencies and tests.
- Require Dart 3.13 and Frosty 4.0.0.

## 2.0.0

- Moves to frosty 3.0.0 requiring new library binary.
- Implements `shareSecretShare` and `ackKeyConstructed` moving to protocol 2.
- Fixes sending of events when stream is closed.

## 1.0.0

Initial release of Noosphere ROAST server

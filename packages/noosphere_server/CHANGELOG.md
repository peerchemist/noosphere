## 3.0.0

This release establishes the package as an Iroh-native fork of the original
`noosphere_server`.

- Removed the gRPC server, generated stubs, configuration, dependencies, and
  tests.
- Added authenticated Iroh QUIC transport for login, DKG, signing, key sharing,
  room enrollment, and protocol events.
- Added persistent Iroh endpoint identities, endpoint-ID pinning, relay
  policies, dedicated protocol ALPNs, and bounded connection resources.
- Moved shared domain types, protobuf messages, and framing into the sibling
  `noosphere` package.

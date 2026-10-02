## 4.0.0

This release establishes the package as an Iroh-native fork of the original
`noosphere_client`.

- Removed `GrpcClientApi`, generated gRPC stubs, configuration, dependencies,
  and tests.
- Added authenticated Iroh QUIC transport with server endpoint-ID pinning,
  relay configuration, and dedicated protocol ALPNs.
- Added fresh-session reconnection with bounded exponential backoff while
  avoiding automatic retries for mutations with ambiguous outcomes.
- Moved shared domain types, protobuf messages, and framing into the sibling
  `noosphere` package.

# Noosphere protocol

Canonical ROAST domain types, group configuration, protobuf messages and
transport-independent framing for the Noosphere protocol. Client, server and
Flutter implementations consume this package directly; transport adapter
implementations such as Iroh endpoints remain outside it.

The public libraries separate the semantic and wire layers:

- `noosphere.dart` contains generated protobuf messages and bounded framing.
- `domain.dart` contains ROAST requests, responses, events and shared types.
- `config.dart` and `common.dart` contain shared configuration and utilities.
- `iroh.dart` contains the shared ALPN and relay-policy value objects, without
  implementing an Iroh endpoint.

The canonical schema is `proto/noosphere.proto`. Regenerate the checked-in
Dart message classes with:

```sh
./tool/generate_protocol.sh
./tool/generate_protocol.sh --check
```

Protocol behavior beyond the wire schema is documented in `spec/`.

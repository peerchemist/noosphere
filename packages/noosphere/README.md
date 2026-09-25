# Noosphere protocol

Canonical protobuf messages and transport-independent framing for the
Noosphere protocol. Client, server and Flutter implementations consume this
package; transport adapters such as Iroh remain outside it.

The canonical schema is `proto/noosphere.proto`. Regenerate the checked-in
Dart message classes with:

```sh
./tool/generate_protocol.sh
./tool/generate_protocol.sh --check
```

Protocol behavior beyond the wire schema is documented in `spec/`.

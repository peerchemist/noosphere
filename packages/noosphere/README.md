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

Signature requests accept an optional free-form explanation:

```dart
final details = SignaturesRequestDetails(
  requiredSigs: requiredSigs,
  expiry: Expiry(const Duration(minutes: 10)),
  message: 'Approve payment for invoice #123',
);
await client.requestSignatures(details);
```

The message defaults to an empty string and is authenticated by the requester's
signature. Read it from `event.details.obj.message` on a domain
`SignaturesRequestEvent`, or `event.request.details.message` on a client
`SignaturesRequestClientEvent`. It also remains available in completed requests.
The explanation does not change the payloads being threshold-signed.
Messages are limited to 1 KiB (1024 UTF-8 bytes), exposed as
`SignaturesRequestDetails.maxMessageBytes`. Oversized messages are rejected on
construction and decoding.

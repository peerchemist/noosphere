# Noosphere Client for ROAST Threshold Signatures

**Coordinated public preview.** Deploy matching tested package versions across
all peers. Protocol v1 does not promise compatibility between preview builds;
see the [version policy](../noosphere/spec/VERSIONING.md).

This Dart library coordinates FROST key generation and ROAST threshold
signatures with a Noosphere server over authenticated Iroh QUIC connections.
The server identity is pinned independently from its address hints.

Import `package:noosphere_client/noosphere_client.dart` for participant APIs,
domain types and storage interfaces. Import
`package:noosphere_client/iroh_transport.dart` for direct RPC clients, endpoint
configuration and reconnecting transport. Transport implementations are not
re-exported by the participant library.

## Requirements

- Dart 3.13 or newer
- the native libraries required by `frosty`, `coinlib` and `iroh_quic`

For desktop Dart, install the signed Iroh native library and pass its path as
`nativeLibraryPath` when it is not in the platform loader path:

```sh
dart run iroh_quic:setup
```

Flutter applications should depend on `iroh_flutter: 1.0.3`, which packages
the matching native libraries for supported target ABIs.

## Connecting

The server CLI prints its full endpoint ID and a base64url bootstrap address.
Obtain the endpoint ID through a trusted channel; do not derive the pin from an
untrusted bootstrap address.

```dart
await Iroh.init(libraryPath: nativeLibraryPath);
final bootstrap = EndpointAddr.decode(base64Url.decode(encodedAddress));
final transport = IrohClientTransportConfig(
  bootstrapAddress: bootstrap,
  pinnedServerId: EndpointId.fromHex(trustedServerId),
  nativeLibraryPath: nativeLibraryPath,
);
final api = await IrohClientApi.connect(transport);
final client = await Client.login(
  config: clientConfig,
  api: api,
  store: storage,
  getPrivateKey: getPrivateKey,
);
```

`IrohRelayConfig.defaultNetwork()` permits direct connections and relay
fallback. Use `disabled()` only for direct/local deployments, `staging()` for
n0 staging, or `custom(urls)` for an explicit relay set.

## Reconnection and storage

`ReconnectingIrohClient` opens a fresh authenticated session after a transport
disconnect with bounded exponential backoff and jitter. Listen to `sessions`
and replace references to the former `Client` when a new session arrives.
Bootstrap address hints may be refreshed with `updateTransportConfig`, but the
pinned server identity cannot change.

Mutating RPCs are never retried automatically because a disconnect can make
their outcome ambiguous. Signing nonces use a prepared/complete storage
transition; applications must use a durable `ClientStorageInterface` in
production. Tests and examples can explicitly import
`package:noosphere_client/testing.dart` for `InMemoryClientStorage`.
It is not exported by `noosphere_client.dart`.

## DKG completion

Listen to `Client.events` immediately after login. When this participant
finishes a DKG and has durably stored its local FROST key, the client emits a
`CompletedDkgClientEvent`. Its `keyDetails` contains the new
`FrostKeyWithDetails`, including the group public key and the DKG name and
description:

```dart
final subscription = client.events.listen((event) {
  if (event case CompletedDkgClientEvent(:final keyDetails)) {
    print('Stored ${keyDetails.name}: ${keyDetails.groupKey.hex}');
  }
});
```

The event reports a completion in the current session; it is not an inventory
of previously stored keys. Read `client.keys` after login for the current key
set, and replace the subscription when a reconnect produces a fresh `Client`.

## Protocol

Canonical domain types, group configuration, messages and framing live in the
sibling `noosphere` workspace package. This package implements the participant
role and its Iroh transport.

See `example/example.dart` for a minimal command-line login and DKG example.
`example/reconnecting_client.dart` demonstrates the recommended application
lifecycle: a separately pinned coordinator ID, optional address hints, Iroh
discovery, event handling, fresh sessions after reconnect and graceful
shutdown.

Write the typed client configuration with
`File('participant.bin').writeAsBytes(clientConfig.toBytes())`. This compact
example format contains the group, participant ID and maximum DKG TTL; construct
`ClientConfig` directly in applications that customize all lifetime settings.
The examples and client library do not parse YAML.

Run it with only the coordinator ID to exercise Iroh discovery:

```sh
dart run example/reconnecting_client.dart \
  --config participant.bin \
  --server-id <trusted-full-hex-endpoint-id> \
  --key-file participant-private-key.hex \
  --native-library /path/to/libirohdart_ffi.so
```

Pass the server CLI's base64url address as `--address` when explicit bootstrap
hints are required. Add `--request-dkg` to submit one demonstration DKG after
the initial login. The example reads the private key lazily from a file and
uses `InMemoryClientStorage` to remain self-contained; replace both with secure
key access and a durable `ClientStorageInterface` in a real application.

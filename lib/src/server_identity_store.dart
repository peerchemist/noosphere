import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart';

/// Durable storage for the embedded server's 32-byte Iroh identity secret.
abstract interface class ServerIdentityStore {
  Future<Uint8List?> read();

  Future<void> write(Uint8List secret);
}

final Expando<Future<SecretKey>> _identityLoads = Expando<Future<SecretKey>>(
  'Noosphere server identities',
);

/// Loads or creates the identity associated with [store].
///
/// Calls using the same store instance share their first in-flight operation,
/// preventing concurrent starts from generating different identities.
Future<SecretKey> loadOrCreateServerIdentity(ServerIdentityStore store) {
  final existing = _identityLoads[store];
  if (existing != null) return existing;

  final loading = _loadOrCreate(store);
  _identityLoads[store] = loading;
  return loading;
}

Future<SecretKey> _loadOrCreate(ServerIdentityStore store) async {
  final stored = await store.read();
  if (stored != null) {
    if (stored.length != SecretKey.lengthBytes) {
      throw FormatException(
        'Stored Iroh server identity must contain exactly '
        '${SecretKey.lengthBytes} bytes; found ${stored.length}.',
      );
    }
    return SecretKey.fromBytes(stored);
  }

  final generated = SecretKey.generate();
  await store.write(generated.toBytes());
  return generated;
}

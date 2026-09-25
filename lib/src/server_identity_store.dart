import 'dart:math';
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
final Expando<bool> _identityLoadClaims = Expando<bool>(
  'Noosphere server identity runtime claims',
);

/// Loads or creates the identity associated with [store].
///
/// Calls using the same store instance share their first in-flight operation,
/// preventing concurrent starts from generating different identities.
Future<SecretKey> loadOrCreateServerIdentity(ServerIdentityStore store) {
  _identityLoadClaims[store] = true;
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

  // Worker host isolates deliberately do not initialize Iroh's native
  // runtime. Generate equivalent cryptographically secure raw key material in
  // Dart so direct nodes and workers can share this cache safely.
  final random = Random.secure();
  final generated = SecretKey.fromBytes(
    List<int>.generate(
      SecretKey.lengthBytes,
      (_) => random.nextInt(256),
      growable: false,
    ),
  );
  await store.write(generated.toBytes());
  return generated;
}

/// Exports the embedded server's raw 32-byte Iroh secret key.
///
/// The result is a secret key, not the public Iroh endpoint ID. Encrypt backups
/// at rest and never log them. This method returns a defensive copy, but Dart
/// managed memory cannot guarantee reliable zeroization.
///
/// Throws [StateError] if no identity has been stored yet and [FormatException]
/// if the stored value is not exactly [SecretKey.lengthBytes] bytes.
Future<Uint8List> exportStoredIrohServerIdentity(
  ServerIdentityStore store,
) async {
  final loaded = _identityLoads[store];
  if (loaded != null) {
    return Uint8List.fromList((await loaded).toBytes());
  }

  final stored = await store.read();
  if (stored == null) {
    throw StateError('The Iroh server identity has not been created yet.');
  }
  _validateSecretLength(stored, description: 'Stored Iroh server identity');
  return Uint8List.fromList(stored);
}

/// Restores an embedded server's raw 32-byte Iroh secret key.
///
/// Call this before starting the node or worker setup that uses [store]. By
/// default, a different stored identity is preserved; pass [overwrite] only
/// for an intentional replacement. Restoring the same key is idempotent.
///
/// [secret] is a secret key, not the public Iroh endpoint ID. It must come from
/// an encrypted backup and must never be logged. The bytes are copied before
/// storage, although Dart managed memory cannot guarantee reliable zeroization.
///
/// Throws [StateError] if this store's identity has already been loaded by a
/// running or starting node, or if replacement would require [overwrite].
Future<void> restoreStoredIrohServerIdentity(
  ServerIdentityStore store,
  Uint8List secret, {
  bool overwrite = false,
}) {
  _validateSecretLength(secret, description: 'Iroh server identity backup');
  final restoredBytes = Uint8List.fromList(secret);

  if (_identityLoadClaims[store] == true) {
    throw StateError(
      'Cannot restore an Iroh server identity after it has been loaded. '
      'Restore it before starting the node or worker setup.',
    );
  }

  final previous = _identityLoads[store];
  final restoring = _restoreIdentity(
    store,
    restoredBytes,
    overwrite: overwrite,
    previous: previous,
  );
  _identityLoads[store] = restoring;
  return restoring.then<void>((_) {});
}

Future<SecretKey> _restoreIdentity(
  ServerIdentityStore store,
  Uint8List secret, {
  required bool overwrite,
  required Future<SecretKey>? previous,
}) async {
  if (previous != null) await previous;

  final stored = await store.read();
  if (stored != null) {
    _validateSecretLength(stored, description: 'Stored Iroh server identity');
    if (_bytesEqual(stored, secret)) return SecretKey.fromBytes(stored);
    if (!overwrite) {
      throw StateError(
        'A different Iroh server identity is already stored. '
        'Pass overwrite: true to replace it intentionally.',
      );
    }
  }

  final key = SecretKey.fromBytes(secret);
  await store.write(Uint8List.fromList(secret));
  return key;
}

void _validateSecretLength(Uint8List secret, {required String description}) {
  if (secret.length != SecretKey.lengthBytes) {
    throw FormatException(
      '$description must contain exactly ${SecretKey.lengthBytes} bytes; '
      'found ${secret.length}.',
    );
  }
}

bool _bytesEqual(Uint8List first, Uint8List second) {
  if (first.length != second.length) return false;
  var difference = 0;
  for (var i = 0; i < first.length; i++) {
    difference |= first[i] ^ second[i];
  }
  return difference == 0;
}

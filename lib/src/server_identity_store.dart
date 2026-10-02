import 'dart:math';
import 'dart:typed_data';

import 'package:iroh_flutter/iroh_flutter.dart';

/// Durable storage for the embedded server's 32-byte Iroh identity secret.
abstract interface class ServerIdentityStore {
  Future<Uint8List?> read();

  Future<void> write(Uint8List secret);
}

// Sequencing survives failures; only a successfully loaded runtime identity is
// cached. Unclaimed operations always reconcile against durable storage.
final _identityStates = Expando<_IdentityState>('Noosphere server identities');

final class _IdentityState {
  Future<void> _tail = Future<void>.value();
  SecretKey? loaded;
  bool claimed = false;

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

_IdentityState _stateFor(ServerIdentityStore store) =>
    _identityStates[store] ??= _IdentityState();

/// Loads or creates the identity associated with [store].
///
/// Calls using the same store instance are serialized and reuse the first
/// successfully loaded identity. Failed storage operations can be retried.
/// The store is claimed synchronously, preventing subsequent restoration while
/// a runtime is starting or running.
Future<SecretKey> loadOrCreateServerIdentity(ServerIdentityStore store) {
  final state = _stateFor(store)..claimed = true;
  return state.run(() async => state.loaded ??= await _loadOrCreate(store));
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
Future<Uint8List> exportStoredIrohServerIdentity(ServerIdentityStore store) {
  final state = _stateFor(store);
  return state.run(() async {
    final loaded = state.loaded;
    if (loaded != null) return Uint8List.fromList(loaded.toBytes());
    final stored = await store.read();
    if (stored == null) {
      throw StateError('The Iroh server identity has not been created yet.');
    }
    _validateSecretLength(stored, description: 'Stored Iroh server identity');
    return Uint8List.fromList(stored);
  });
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

  final state = _stateFor(store);
  if (state.claimed) {
    throw StateError(
      'Cannot restore an Iroh server identity after it has been loaded. '
      'Restore it before starting the node or worker setup.',
    );
  }

  return state.run(
    () => _restoreIdentity(store, restoredBytes, overwrite: overwrite),
  );
}

Future<void> _restoreIdentity(
  ServerIdentityStore store,
  Uint8List secret, {
  required bool overwrite,
}) async {
  final stored = await store.read();
  if (stored != null) {
    _validateSecretLength(stored, description: 'Stored Iroh server identity');
    if (_bytesEqual(stored, secret)) return;
    if (!overwrite) {
      throw StateError(
        'A different Iroh server identity is already stored. '
        'Pass overwrite: true to replace it intentionally.',
      );
    }
  }

  await store.write(Uint8List.fromList(secret));
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

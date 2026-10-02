import 'dart:io';
import 'dart:typed_data';

import 'package:noosphere_flutter/noosphere_flutter.dart';

final class MemoryIdentityStore implements ServerIdentityStore {
  Uint8List? _secret;

  @override
  Future<Uint8List?> read() async =>
      _secret == null ? null : Uint8List.fromList(_secret!);

  @override
  Future<void> write(Uint8List secret) async {
    _secret = Uint8List.fromList(secret);
    logDemo('Stored the test server identity in memory.');
  }
}

void logWorkerEndpoint(WorkerCoordinatorAddress address) => logDemo(
  'Iroh ID: ${address.id}\n'
  'Iroh IPs: ${address.ipAddrs}\n'
  'Iroh relays: ${address.relayUrls}',
);

void logWorkerSnapshot(NoosphereWorkerSnapshot snapshot) {
  final coordinator = snapshot.coordinator;
  final dkgs = [for (final dkg in snapshot.dkgs) '${dkg.name}:${dkg.stage}'];
  final signingRequests = [
    for (final request in snapshot.signingRequests)
      '${request.creator}:${request.status}',
  ];
  final keys = [for (final key in snapshot.keys) key.name];
  logDemo(
    'ROAST worker event: WorkerSnapshotEvent\n'
    '  setup: ${snapshot.setupId}\n'
    '  generation: ${snapshot.generation}\n'
    '  server running: ${snapshot.serverRunning}\n'
    '  signer running: ${snapshot.signerRunning}\n'
    '  signer connected: ${snapshot.connected}\n'
    '  coordinator ID: ${coordinator?.id ?? '-'}\n'
    '  coordinator IPs: ${coordinator?.ipAddrs ?? const <String>[]}\n'
    '  coordinator relays: ${coordinator?.relayUrls ?? const <String>[]}\n'
    '  online participants: ${snapshot.onlineParticipants}\n'
    '  DKGs (${dkgs.length}): $dkgs\n'
    '  signing requests (${signingRequests.length}): $signingRequests\n'
    '  keys (${keys.length}): $keys',
  );
}

void logDemo(String message) => stdout.writeln('[noosphere] $message');

String hexBytes(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

P2TRAddress taprootAddress(WorkerKeyInfo key, Network network) =>
    P2TRAddress.fromTaproot(
      Taproot(internalKey: ECCompressedPublicKey.fromHex(key.groupKeyHex)),
      hrp: network.bech32Hrp,
    );

Uint8List parseHash(String value) {
  final hex = value.trim();
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
    throw const FormatException(
      'Message hash must be exactly 64 hex characters.',
    );
  }
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

ECPublicKey signatureVerificationKey(SingleSignatureDetails details) {
  final derived = deriveThresholdGroupKey(
    groupKey: details.groupKey,
    threshold: 2,
    path: details.hdDerivation,
  ).groupKey;
  final mast = details.signDetails.mastHash;
  if (mast == null) return derived;
  return derived.xonly.tweak(
    Taproot.tweakHash(Uint8List.fromList([...derived.x, ...mast])),
  )!;
}

#!/usr/bin/env bash
set -euo pipefail

# Validate a desktop consumer outside workspace resolution. These are staged
# source packages, not hosted releases; this script never publishes anything.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
consumer_dir="$(mktemp -d "${TMPDIR:-/tmp}/noosphere-consumer.XXXXXX")"
trap 'rm -rf "$consumer_dir"' EXIT
case "$(uname -s)" in
  Linux) consumer_platform=linux ;;
  Darwin) consumer_platform=macos ;;
  *) echo 'A Linux or macOS desktop host is required.' >&2; exit 1 ;;
esac

python3 - "$repo_root" "$consumer_dir" <<'PY'
from pathlib import Path
import shutil
import sys

repo, stage = map(Path, sys.argv[1:])
for name in ['noosphere_flutter', 'noosphere', 'noosphere_client', 'noosphere_server']:
    source = repo if name == 'noosphere_flutter' else repo / 'packages' / name
    target = stage / 'packages' / name
    target.mkdir(parents=True)
    shutil.copytree(source / 'lib', target / 'lib')
    manifest = []
    in_workspace = False
    for line in (source / 'pubspec.yaml').read_text().splitlines():
        if line.startswith('workspace:'):
            in_workspace = True
            continue
        if in_workspace and (not line or line.startswith(' ')):
            continue
        in_workspace = False
        if line == 'resolution: workspace':
            continue
        manifest.append(line)
    (target / 'pubspec.yaml').write_text('\n'.join(manifest) + '\n')
PY

flutter create --empty --platforms="$consumer_platform" \
  --project-name=noosphere_release_consumer "$consumer_dir/app"
cat > "$consumer_dir/app/pubspec.yaml" <<'YAML'
name: noosphere_release_consumer
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.13.0

dependencies:
  flutter:
    sdk: flutter
  noosphere_flutter:
    path: ../packages/noosphere_flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  integration_test:
    sdk: flutter

dependency_overrides:
  noosphere:
    path: ../packages/noosphere
  noosphere_client:
    path: ../packages/noosphere_client
  noosphere_server:
    path: ../packages/noosphere_server
YAML
mkdir -p "$consumer_dir/app/integration_test"
cat > "$consumer_dir/app/integration_test/consumer_test.dart" <<'DART'
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/testing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('standalone consumer loads native bindings and serves', (_) async {
    await NoosphereFlutter.initialize();
    final group = GroupConfig(id: 'consumer', participants: {
      for (var i = 1; i <= 2; i++)
        Identifier.fromUint16(i): ECCompressedPublicKey.fromPubkey(
          ECPrivateKey(Uint8List(32)..last = i).pubkey,
        ),
    });
    expect(GroupConfig.fromBytes(group.toBytes()).toBytes(), group.toBytes());
    final worker = await NoosphereWorker.start();
    try {
      final snapshot = await worker.startSetup(
        setupId: 'consumer',
        server: EmbeddedServerOptions(
          serverConfig: ServerConfig(group: group),
          identityStore: _Identity(),
          serverPersistence: InMemoryServerPersistence(),
          relay: IrohRelayConfig.disabled(),
        ),
      );
      expect(snapshot.serverRunning, isTrue);
    } finally {
      await worker.close();
    }
    expect(worker.isClosed, isTrue);
  });
}

final class _Identity implements ServerIdentityStore {
  Uint8List? bytes;
  @override
  Future<Uint8List?> read() async => bytes;
  @override
  Future<void> write(Uint8List value) async {
    bytes = Uint8List.fromList(value);
  }
}
DART
cd "$consumer_dir/app"
flutter pub get
flutter analyze
flutter test integration_test/consumer_test.dart -d "$consumer_platform"
echo 'Standalone source consumer passed; no hosted package set was published or tested.'

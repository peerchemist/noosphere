import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:coinlib/coinlib.dart';
import 'package:noosphere_server/noosphere_server.dart';

import 'src/identity_file.dart';
import 'src/server_state_file.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to the Iroh server YAML configuration.',
      mandatory: true,
    );
  final options = parser.parse(arguments);
  final configPath = options.option('config')!;

  await loadFrosty();
  final reader = MapReader.fromYaml(await File(configPath).readAsString());
  final config = IrohConfig.fromMapReader(reader);
  // Filesystem configuration belongs to this CLI host, not IrohConfig.
  final identityPath = reader['secret-key-path'].require<String>();
  final secretKey = await loadOrCreateIdentityFile(identityPath);
  final stateDirectory =
      reader['state-directory'].value<String>() ?? '$configPath.state';
  final server = await IrohServer.start(
    config,
    secretKey: secretKey,
    persistence: FileServerPersistence(Directory(stateDirectory)),
  );

  final termination = Completer<ProcessSignal>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  for (final signal in <ProcessSignal>[
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ]) {
    subscriptions.add(
      signal.watch().listen((received) {
        if (!termination.isCompleted) termination.complete(received);
      }),
    );
  }

  final address = base64Url.encode(server.address.encode());
  stdout.writeln('Loaded config from $configPath');
  stdout.writeln(
    'Group fingerprint is ${bytesToHex(config.server.group.fingerprint)}',
  );
  stdout.writeln('Iroh endpoint ID is ${server.id.toHex()}');
  stdout.writeln('IROH_SERVER_READY ${server.id.toHex()} $address');

  final serving = server.serve();
  try {
    final signal = await termination.future;
    stdout.writeln('Caught ${signal.name}; shutting down.');
  } finally {
    await server.close();
    await serving;
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}

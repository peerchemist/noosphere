import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart' as fr;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_client/iroh_transport.dart' as transport;
import 'package:noosphere_client/noosphere_client.dart' as ns;
import 'package:noosphere_client/testing.dart';

/// Logs into a pinned Iroh server, requests a DKG and prints received events.
void main(List<String> args) async {
  await fr.loadFrosty();

  final argParser = ArgParser()
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to binary ClientConfig bytes (config.toBytes()).',
      mandatory: true,
    )
    ..addOption(
      'address',
      abbr: 'a',
      help: 'Base64url endpoint address printed by the server CLI.',
      mandatory: true,
    )
    ..addOption(
      'server-id',
      help: 'Independently obtained full hex Iroh endpoint ID.',
      mandatory: true,
    )
    ..addOption('native-library', help: 'Optional path to libirohdart_ffi.')
    ..addOption(
      'key',
      abbr: 'k',
      help: 'Hex private key for this participant.',
      mandatory: true,
    );
  final argResults = argParser.parse(args);
  final configFile = argResults.option('config')!;
  final configBytes = await File(configFile).readAsBytes();
  final nativeLibrary = argResults.option('native-library');
  final key = cl.ECPrivateKey.fromHex(argResults.option('key')!);

  await Iroh.init(libraryPath: nativeLibrary);
  final api = await transport.IrohClientApi.connect(
    transport.IrohClientTransportConfig(
      bootstrapAddress: EndpointAddr.decode(
        base64Url.decode(argResults.option('address')!),
      ),
      pinnedServerId: EndpointId.fromHex(argResults.option('server-id')!),
      nativeLibraryPath: nativeLibrary,
    ),
  );

  final client = await ns.Client.login(
    config: ns.ClientConfig.fromBytes(configBytes),
    api: api,
    store: InMemoryClientStorage(),
    getPrivateKey: (_) async => key,
    onDisconnect: () => print('Disconnected callback'),
  );
  print('Logged in');

  await client.requestDkg(
    ns.NewDkgDetails(
      name: 'Example DKG ${cl.bytesToHex(cl.generateRandomBytes(4))}',
      description: 'A DKG request for example purposes',
      threshold: 2,
      expiry: ns.Expiry(Duration(hours: 1)),
    ),
  );

  await for (final event in client.events) {
    print(event);
  }

  print('Logged out / disconnected');
}

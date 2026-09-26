import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart' as fr;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart' as ns;
import 'package:noosphere_client/testing.dart';

/// Runs a reconnecting Noosphere client with a pinned coordinator identity.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to the ClientConfig YAML file.',
      mandatory: true,
    )
    ..addOption(
      'server-id',
      help: 'Trusted full-hex Iroh endpoint ID of the coordinator.',
      mandatory: true,
    )
    ..addOption(
      'address',
      abbr: 'a',
      help:
          'Optional base64url EndpointAddr. Iroh discovery is used if absent.',
    )
    ..addOption(
      'key-file',
      abbr: 'k',
      help: 'Path to a file containing the participant private key in hex.',
      mandatory: true,
    )
    ..addOption('native-library', help: 'Optional path to libirohdart_ffi.')
    ..addFlag(
      'request-dkg',
      help: 'Request one demonstration threshold-2 DKG after the first login.',
      defaultsTo: false,
    );
  final options = parser.parse(arguments);
  final serverId = EndpointId.fromHex(options.option('server-id')!);
  final encodedAddress = options.option('address');
  final bootstrapAddress = encodedAddress == null
      ? EndpointAddr(serverId)
      : EndpointAddr.decode(base64Url.decode(encodedAddress));
  final clientConfig = ns.ClientConfig.fromYaml(
    await File(options.option('config')!).readAsString(),
  );
  final keyFile = File(options.option('key-file')!);

  await fr.loadFrosty();
  final runtime = await ReconnectingIrohClient.connect(
    clientConfig: clientConfig,
    transportConfig: IrohClientTransportConfig(
      bootstrapAddress: bootstrapAddress,
      pinnedServerId: serverId,
      nativeLibraryPath: options.option('native-library'),
    ),
    // This keeps the example self-contained. Production applications must use
    // a durable ClientStorageInterface so keys and signing nonces survive a
    // process restart.
    store: InMemoryClientStorage(),
    // Read the key only when an operation needs it. A production application
    // should replace this file with its OS keystore or hardware wallet.
    getPrivateKey: (purpose) async {
      stdout.writeln('Private key requested for $purpose');
      return cl.ECPrivateKey.fromHex((await keyFile.readAsString()).trim());
    },
  );

  StreamSubscription<ns.ClientEvent>? eventSubscription;
  Future<void> attachSession(ns.Client client) async {
    await eventSubscription?.cancel();
    stdout.writeln(
      'Authenticated with ${client.onlineParticipants.length} '
      'other participant(s) online.',
    );
    eventSubscription = client.events.listen(
      (event) {
        switch (event) {
          case ns.ParticipantStatusClientEvent():
            stdout.writeln(
              'Participant ${event.id} is '
              '${event.loggedIn ? 'online' : 'offline'}.',
            );
          case ns.UpdatedDkgClientEvent():
            stdout.writeln('DKG state changed.');
          case ns.SignaturesCompleteClientEvent():
            stdout.writeln(
              'Completed ${event.signatures.length} signature(s).',
            );
          case ns.SecretShareClientEvent():
            stdout.writeln('Received a key share from ${event.sender}.');
          default:
            stdout.writeln('Received ${event.runtimeType}.');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        stderr.writeln('Session ended with an error: $error');
      },
      onDone: () => stdout.writeln('Session event stream closed.'),
    );
  }

  await attachSession(runtime.current);
  final sessionsSubscription = runtime.sessions.listen(
    (client) {
      stdout.writeln('Reconnected with a fresh authenticated session.');
      unawaited(attachSession(client));
    },
    onError: (Object error, StackTrace stackTrace) {
      stderr.writeln('Reconnect attempt failed: $error');
    },
  );

  if (options.flag('request-dkg')) {
    await runtime.current.requestDkg(
      ns.NewDkgDetails(
        name: 'Example DKG ${cl.bytesToHex(cl.generateRandomBytes(4))}',
        description: 'Requested by reconnecting_client.dart',
        threshold: 2,
        expiry: ns.Expiry(const Duration(hours: 1)),
      ),
    );
    stdout.writeln('Requested a DKG. The request is not retried on reconnect.');
  }

  final termination = Completer<ProcessSignal>();
  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[];
  for (final signal in <ProcessSignal>[
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ]) {
    signalSubscriptions.add(
      signal.watch().listen((received) {
        if (!termination.isCompleted) termination.complete(received);
      }),
    );
  }

  stdout.writeln('Client is running. Press Ctrl+C to stop.');
  final signal = await termination.future;
  stdout.writeln('Caught ${signal.name}; shutting down.');

  await sessionsSubscription.cancel();
  await eventSubscription?.cancel();
  await runtime.close();
  for (final subscription in signalSubscriptions) {
    await subscription.cancel();
  }
}

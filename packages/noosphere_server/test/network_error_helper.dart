import 'dart:io';
import 'dart:convert';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_server/noosphere_server.dart';

import 'data.dart';

class FailingHandler extends ServerApiHandler {
  FailingHandler()
    : super(config: serverConfig, persistence: newServerPersistence());

  @override
  Future<void> requestNewDkg({
    required SessionID sid,
    required Signed<NewDkgDetails> signedDetails,
    required DkgPublicCommitment commitment,
  }) {
    if (signedDetails.obj.name == 'internal-failure') {
      throw StateError('private failure marker');
    }
    return super.requestNewDkg(
      sid: sid,
      signedDetails: signedDetails,
      commitment: commitment,
    );
  }
}

Future<void> main(List<String> arguments) async {
  await loadFrosty();
  await Iroh.init(libraryPath: Platform.environment["IROH_NATIVE_LIBRARY"]);
  final server = await IrohServer.start(
    IrohConfig(
      server: serverConfig,
      relay: IrohRelayConfig.disabled(),
      nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
    ),
    secretKey: SecretKey.generate(),
    persistence: newServerPersistence(),
    handler: FailingHandler(),
    onError: arguments.first == 'default'
        ? null
        : (error, stack) {
            stderr.writeln('HOST_ERROR: $error');
            if (arguments.first == 'throwing') {
              throw StateError('callback failure marker');
            }
          },
  );
  final serving = server.serve();
  stdout.writeln(
    jsonEncode({
      'id': server.id.toHex(),
      'addresses': server.endpoint.boundSockets
          .map(
            (s) => s.startsWith('[')
                ? '[::1]:${s.split(':').last}'
                : '127.0.0.1:${s.split(':').last}',
          )
          .toList(),
    }),
  );
  await stdin.first;
  await server.close();
  await serving;
}

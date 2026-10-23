import 'dart:convert';
import 'dart:io';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_server/noosphere_server.dart';

import 'data.dart';
import 'support/process_persistence.dart';

Future<void> main(List<String> arguments) async {
  await cl.loadCoinlib();
  await loadFrosty();
  final persistence = TestProcessPersistence(Directory(arguments.first));
  final handler = ServerApiHandler(
    config: arguments.length > 2
        ? ServerConfig(
            group: groupConfig,
            publicFeed: PublicFeedConfig(feedId: PublicFeedId(arguments[2])),
          )
        : serverConfig,
    persistence: persistence,
  );
  await handler.ready;

  if (arguments[1] == 'seed') {
    final challenge = await handler.login(
      groupFingerprint: groupConfig.fingerprint,
      participantId: ids.first,
    );
    final login = await handler.respondToChallenge(
      Signed.sign(obj: challenge.challenge, key: getPrivkey(0)),
    );
    final details = getDkgDetails(name: 'process-restart-dkg');
    await handler.requestNewDkg(
      sid: login.id,
      signedDetails: signObject(details),
      commitment: DkgPart1(
        identifier: ids.first,
        threshold: 2,
        n: ids.length,
      ).public,
    );
  }

  stdout.writeln(utf8.decode(handler.state.toBytes()));
  await stdout.flush();
  exit(0);
}

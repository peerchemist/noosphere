// Deliberately isolated: no signer client, server, storage, or FROST setup.
import 'dart:convert';
import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/iroh.dart';
import 'package:noosphere_client/public_feed.dart';

Future<void> main(List<String> args) async {
  await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  final client = await PublicFeedClient.connect(
    EndpointAddr.decode(base64Decode(args[0])),
    EndpointId.fromHex(args[1]),
    relay: IrohRelayConfig.disabled(),
  );
  try {
    final page = await client.fetch(PublicFeedId(args[2]));
    stdout.writeln(
      jsonEncode({'entries': page.entries.length, 'cursor': page.nextCursor}),
    );
  } finally {
    await client.close();
  }
}

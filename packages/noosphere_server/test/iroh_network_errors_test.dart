@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_protocol/wire.dart' as wire;
import 'package:test/test.dart';

import 'data.dart';

Stream<Uint8List> chunks(RecvStream receive) async* {
  while (true) {
    final bytes = await receive.read(4096);
    if (bytes == null) return;
    yield Uint8List.fromList(bytes);
  }
}

Future<List<int>> rpc(
  Connection connection,
  wire.RoastOperation operation,
  List<int> body,
) async {
  final (send, receive) = await connection.openBi();
  await send.writeAll(
    Uint8List.fromList([...wire.encodeQuicVarInt(operation.id), ...body]),
  );
  await send.finish();
  return chunks(receive).fold<List<int>>([], (all, next) => all..addAll(next));
}

void main() {
  setUpAll(() async {
    await loadFrosty();
    await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  });

  for (final mode in ['default', 'callback', 'throwing']) {
    test(
      'malformed DKG and internal failures cannot terminate the coordinator ($mode)',
      () async {
        final root = Directory.current.path.endsWith('noosphere_server')
            ? '../..'
            : '.';
        final process = await Process.start(Platform.resolvedExecutable, [
          '--packages=$root/.dart_tool/package_config.json',
          '$root/packages/noosphere_server/test/network_error_helper.dart',
          mode,
        ]);
        final errors = StringBuffer();
        final stderrDone = process.stderr
            .transform(utf8.decoder)
            .listen(errors.write);
        final lines = StreamIterator(
          process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter()),
        );
        addTearDown(() async {
          process.stdin.writeln('stop');
          await process.stdin.close();
          expect(
            await process.exitCode.timeout(const Duration(seconds: 10)),
            0,
            reason: errors.toString(),
          );
          await lines.cancel();
          await stderrDone.cancel();
        });
        expect(
          await lines.moveNext().timeout(const Duration(seconds: 30)),
          isTrue,
          reason: errors.toString(),
        );
        final ready = jsonDecode(lines.current) as Map<String, dynamic>;
        final address = EndpointAddr(
          EndpointId.fromHex(ready['id'] as String),
          ipAddrs: (ready['addresses'] as List).cast<String>(),
        );
        final endpoint = await Endpoint.bind(
          alpns: [noosphereIrohAlpn.codeUnits],
          relayMode: RelayMode.disabled,
        );
        addTearDown(endpoint.close);

        Future<(Connection, List<int>)> login(int participant) async {
          final connection = await endpoint.connect(
            address,
            noosphereIrohAlpn.codeUnits,
          );
          final response = await rpc(
            connection,
            wire.RoastOperation.login,
            wire.LoginRequest(
              groupFingerprint: groupConfig.fingerprint,
              participantId: ids[participant].toBytes(),
              protocolVersion: noosphereRoastProtocolVersion,
            ).writeToBuffer(),
          );
          expect(response.first, 0);
          final challenge = ExpirableAuthChallengeResponse.fromBytes(
            Uint8List.fromList(
              wire.LoginResponse.fromBuffer(response.sublist(1)).challenge,
            ),
          );
          final signed = Signed.sign(
            obj: challenge.challenge,
            key: getPrivkey(participant),
          );
          final authenticated = await rpc(
            connection,
            wire.RoastOperation.respondToChallenge,
            wire.SignedAuthChallenge(
              challenge: signed.obj.toBytes(),
              signature: signed.signature.data,
            ).writeToBuffer(),
          );
          expect(authenticated.first, 0);
          final (send, receive) = await connection.openBi();
          await send.writeAll(
            Uint8List.fromList([
              ...wire.encodeQuicVarInt(wire.RoastOperation.startSession.id),
              ...wire.StartSession().writeToBuffer(),
            ]),
          );
          await send.finish();
          final events = StreamIterator(
            wire.decodeLengthPrefixedMessages(
              chunks(receive),
              maxMessageLength: 1000000,
            ),
          );
          expect(await events.moveNext(), isTrue);
          final sid = wire.SessionStarted.fromBuffer(events.current).sessionId;
          // Keep the session stream consumed while RPCs execute.
          unawaited(() async {
            try {
              while (await events.moveNext()) {}
            } catch (_) {}
          }());
          addTearDown(() {
            connection.close();
          });
          return (connection, sid);
        }

        final (connection, sid) = await login(0);
        final valid = signObject(getDkgDetails()).toBytes();
        final badVersion = Uint8List.fromList(valid)
          ..[0] = NewDkgDetails.currentProtocolVersion + 1;
        // version, fingerprint, attempt, compact name, compact empty description.
        final thresholdOffset = 2 + 32 + 32 + 1 + 3 + 1;
        final badThreshold = Uint8List.fromList(valid)
          ..[thresholdOffset] = 1
          ..[thresholdOffset + 1] = 0;
        final badName = Uint8List.fromList([
          ...valid.take(66),
          2,
          ...valid.sublist(67, 69),
          ...valid.sublist(70),
        ]);
        final commitment = getDkgPart1(0).public.toBytes();
        for (final malformed in [
          badVersion,
          badThreshold,
          badName,
          valid.sublist(0, 10),
        ]) {
          final response = await rpc(
            connection,
            wire.RoastOperation.requestNewDkg,
            wire.DkgRequest(
              sid: sid,
              signedDetails: malformed,
              commitment: commitment,
            ).writeToBuffer(),
          );
          expect(response.first, 1);
          expect(
            wire.ProtocolError.fromBuffer(response.sublist(1)).code,
            wire.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
          );
        }
        final accepted = await rpc(
          connection,
          wire.RoastOperation.requestNewDkg,
          wire.DkgRequest(
            sid: sid,
            signedDetails: valid,
            commitment: commitment,
          ).writeToBuffer(),
        );
        expect(accepted.first, 0);
        final (other, otherSid) = await login(1);
        try {
          final response = await rpc(
            connection,
            wire.RoastOperation.requestNewDkg,
            wire.DkgRequest(
              sid: sid,
              signedDetails: signObject(getDkgDetails(name: 'internal-failure'))
                  .toBytes(),
              commitment: commitment,
            ).writeToBuffer(),
          );
          expect(response, isEmpty);
        } on Exception {
          /* The affected connection may close before EOF. */
        }
        final extended = await rpc(
          other,
          wire.RoastOperation.extendSession,
          wire.Bytes(data: otherSid).writeToBuffer(),
        );
        expect(extended.first, 0);
        await login(2);
        expect(errors.toString(), contains('private failure marker'));
        if (mode != 'default') {
          expect(errors.toString(), contains('HOST_ERROR:'));
        }
        if (mode == 'throwing') {
          expect(errors.toString(), contains('callback failure marker'));
        }
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }
}

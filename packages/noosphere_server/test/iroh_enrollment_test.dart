@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/wire.dart' as protocol;
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/testing.dart';
import 'package:test/test.dart';

import 'data.dart';

void main() {
  final nativeLibrary = Platform.environment['IROH_NATIVE_LIBRARY'];
  const maximum = 4096;

  setUpAll(() async {
    await cl.loadCoinlib();
    await loadFrosty();
    await Iroh.init(libraryPath: nativeLibrary);
  });

  IrohClientTransportConfig transport(Endpoint endpoint) =>
      IrohClientTransportConfig(
        bootstrapAddress: _address(endpoint),
        pinnedServerId: endpoint.id,
        relay: IrohRelayConfig.disabled(),
        maxMessageLength: maximum,
        authTimeout: const Duration(seconds: 2),
        nativeLibraryPath: nativeLibrary,
      );

  group('enrollment over direct protobuf streams', () {
    late IrohServer server;
    late RoomManager rooms;
    late RoomInvite invite;
    late IrohRoomEnrollmentApi api;

    setUp(() async {
      final identity = SecretKey.generate();
      rooms = await RoomManager.open(
        coordinatorEndpointId: identity.publicKey.asBytes(),
        persistence: InMemoryRoomPersistence(),
      );
      server = await IrohServer.start(
        IrohConfig(
          server: serverConfig,
          relay: IrohRelayConfig.disabled(),
          maxMessageLength: maximum,
          authTimeout: const Duration(milliseconds: 500),
          nativeLibraryPath: nativeLibrary,
        ),
        secretKey: identity,
        rooms: rooms,
        persistence: InMemoryServerPersistence(),
      );
      unawaited(server.serve());
      addTearDown(server.close);
      await server.createRoom(
        roomId: 'room',
        expectedParticipants: 2,
        threshold: 2,
      );
      invite = await server.issueRoomInvite(
        roomId: 'room',
        expectedParticipantPublicKey: cl.ECCompressedPublicKey.fromPubkey(
          getPrivkey(0).pubkey,
        ),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      api = await IrohRoomEnrollmentApi.connect(transport(server.endpoint));
      addTearDown(api.close);
    });

    protocol.BeginEnrollmentRequest begin() => protocol.BeginEnrollmentRequest(
      invite: invite.toBytes(),
      participantPublicKey: invite.expectedParticipantPublicKey.data,
    );

    Future<(int, Uint8List)> exchange(
      List<int> bytes, {
      bool finish = true,
      String alpn = noosphereEnrollmentAlpn,
    }) async {
      final endpoint = await Endpoint.bind(relayMode: RelayMode.disabled);
      addTearDown(endpoint.close);
      final connection = await endpoint.connect(
        _address(server.endpoint),
        alpn.codeUnits,
      );
      addTearDown(() => connection.close());
      final (send, receive) = await connection.openBi();
      await send.writeAll(bytes);
      if (finish) await send.finish();
      final reader = protocol.QuicStreamReader(_chunks(receive));
      final status = await reader.readVarInt().timeout(
        const Duration(seconds: 3),
      );
      final body = await reader.readToEnd().timeout(const Duration(seconds: 3));
      return (status, body);
    }

    List<int> requestBytes(
      protocol.EnrollmentOperation operation,
      List<int> body,
    ) => [...protocol.encodeQuicVarInt(operation.id), ...body];

    test('enrolls, persists membership, and rejects proof replay', () async {
      final challenge = await api.beginEnrollment(
        invite: invite,
        participantPublicKey: invite.expectedParticipantPublicKey,
      );
      final proof = challenge.sign(getPrivkey(0));
      final snapshot = await api.redeemRoomInvite(proof);
      expect(snapshot.participants, hasLength(1));
      expect(snapshot.invites.single.status, RoomInviteStatus.used);
      expect(snapshot.toBytes(), (await rooms.getRoom('room')).toBytes());
      await expectLater(
        api.redeemRoomInvite(proof),
        throwsA(
          isA<RoomEnrollmentProtocolException>().having(
            (error) => error.code,
            'room code',
            RoomFailureCode.replayedChallenge.index,
          ),
        ),
      );
    });

    test('maps operation ID directly to the response protobuf', () async {
      final (status, body) = await exchange(
        requestBytes(
          protocol.EnrollmentOperation.beginEnrollment,
          begin().writeToBuffer(),
        ),
      );
      expect(status, protocol.RpcResponseStatus.success);
      final response = protocol.BeginEnrollmentResponse.fromBuffer(body);
      final challenge = EnrollmentChallenge.fromBytes(
        Uint8List.fromList(response.challenge),
      );
      expect(challenge.transcript.inviteId, invite.inviteId);
    });

    test('rejects unknown and wrong-ALPN operation IDs cleanly', () async {
      final (unknownStatus, unknownBody) = await exchange([
        ...protocol.encodeQuicVarInt(999),
        ...begin().writeToBuffer(),
      ]);
      expect(unknownStatus, protocol.RpcResponseStatus.error);
      expect(
        protocol.ProtocolError.fromBuffer(unknownBody).code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
      );

      final (wrongStatus, wrongBody) = await exchange(
        requestBytes(
          protocol.EnrollmentOperation.beginEnrollment,
          begin().writeToBuffer(),
        ),
        alpn: noosphereIrohAlpn,
      );
      expect(wrongStatus, protocol.RpcResponseStatus.error);
      expect(
        protocol.ProtocolError.fromBuffer(wrongBody).code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
      );
    });

    test('bounds FIN-delimited request bodies', () async {
      final (status, body) = await exchange([
        ...protocol.encodeQuicVarInt(
          protocol.EnrollmentOperation.beginEnrollment.id,
        ),
        ...List.filled(maximum + 1, 0),
      ]);
      expect(status, protocol.RpcResponseStatus.error);
      expect(
        protocol.ProtocolError.fromBuffer(body).code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
      );
    });

    test(
      'rejects oversized outgoing requests before opening a stream',
      () async {
        final small = await IrohRoomEnrollmentApi.connect(
          IrohClientTransportConfig(
            bootstrapAddress: _address(server.endpoint),
            pinnedServerId: server.id,
            relay: IrohRelayConfig.disabled(),
            maxMessageLength: 16,
            nativeLibraryPath: nativeLibrary,
          ),
        );
        addTearDown(small.close);
        await expectLater(
          small.beginEnrollment(
            invite: invite,
            participantPublicKey: invite.expectedParticipantPublicKey,
          ),
          throwsA(isA<protocol.FrameTooLargeException>()),
        );
      },
    );
  });
}

EndpointAddr _address(Endpoint endpoint) => EndpointAddr(
  endpoint.id,
  ipAddrs: [
    for (final address in endpoint.boundSockets)
      '${address.startsWith('[') ? '[::1]' : '127.0.0.1'}:${address.substring(address.lastIndexOf(':') + 1)}',
  ],
);

Stream<List<int>> _chunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(4096);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/wire.dart' as protocol;
import 'package:noosphere_client/iroh_transport.dart';
import 'package:noosphere_client/noosphere_client.dart';
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
        maxEnvelopeLength: maximum,
        authTimeout: const Duration(seconds: 2),
        nativeLibraryPath: nativeLibrary,
      );

  group('enrollment server', () {
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
          maxEnvelopeLength: maximum,
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

    protocol.Envelope begin({List<int> id = const [1, 2, 3]}) =>
        protocol.Envelope(
          wireVersion: noosphereIrohWireVersion,
          rpcRequest: protocol.RpcRequest(
            requestId: id,
            beginEnrollment: protocol.BeginEnrollmentRequest(
              invite: invite.toBytes(),
              participantPublicKey: invite.expectedParticipantPublicKey.data,
            ),
          ),
        );

    Future<protocol.Envelope> exchange(
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
      return protocol
          .decodeEnvelopes(_chunks(receive))
          .single
          .timeout(const Duration(seconds: 3));
    }

    test('enrolls, persists membership, and rejects proof replay', () async {
      final challenge = await api.beginEnrollment(
        invite: invite,
        participantPublicKey: invite.expectedParticipantPublicKey,
      );
      expect(challenge.transcript.inviteTokenHash, invite.tokenHash);
      expect(challenge.transcript.coordinatorEndpointId, server.id.asBytes());
      final proof = challenge.sign(getPrivkey(0));
      final snapshot = await api.redeemRoomInvite(proof);
      expect(snapshot.participants, hasLength(1));
      expect(snapshot.invites.single.status, RoomInviteStatus.used);
      expect(snapshot.toBytes(), (await rooms.getRoom('room')).toBytes());
      await expectLater(
        api.redeemRoomInvite(proof),
        throwsA(
          isA<RoomEnrollmentProtocolException>().having(
            (e) => e.code,
            'room code',
            RoomFailureCode.replayedChallenge.index,
          ),
        ),
      );
    });

    test(
      'joinRoom enrolls a second participant and the roster can freeze',
      () async {
        await RoomEnrollmentClient(api)
            .joinRoom(invite, (_) async => getPrivkey(0));
        final second = await server.issueRoomInvite(
          roomId: 'room',
          expectedParticipantPublicKey: cl.ECCompressedPublicKey.fromPubkey(
            getPrivkey(1).pubkey,
          ),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        await IrohRoomEnrollmentApi.joinRoom(
          transport(server.endpoint),
          second,
          (_) async => getPrivkey(1),
        );
        final frozen = await server.freezeRoom('room');
        expect(frozen.lifecycle, RoomLifecycle.frozen);
        expect(frozen.groupConfig!.participants, hasLength(2));
      },
    );

    test('preserves zero-valued domain failures in protobuf errors', () async {
      final unknown = RoomInvite(
        roomId: 'unknown',
        inviteId: invite.inviteId,
        token: invite.token,
        expectedParticipantPublicKey: invite.expectedParticipantPublicKey,
        coordinatorEndpointId: invite.coordinatorEndpointId,
        expiresAt: invite.expiresAt,
      );
      await expectLater(
        api.beginEnrollment(
          invite: unknown,
          participantPublicKey: unknown.expectedParticipantPublicKey,
        ),
        throwsA(
          isA<RoomEnrollmentProtocolException>()
              .having(
                (e) => e.code,
                'room code',
                RoomFailureCode.unknownRoom.index,
              )
              .having(
                (e) => e.error!.hasRoomFailureCode(),
                'domain error present',
                isTrue,
              )
              .having((e) => e.error!.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('rejects a proof signed by a different key', () async {
      final challenge = await api.beginEnrollment(
        invite: invite,
        participantPublicKey: invite.expectedParticipantPublicKey,
      );
      await expectLater(
        api.redeemRoomInvite(
          Signed.sign(obj: challenge.transcript, key: getPrivkey(1)),
        ),
        throwsA(
          isA<RoomEnrollmentProtocolException>().having(
            (e) => e.code,
            'room code',
            RoomFailureCode.invalidSignature.index,
          ),
        ),
      );
      expect((await rooms.getRoom('room')).participants, isEmpty);
      final fresh = await api.beginEnrollment(
        invite: invite,
        participantPublicKey: invite.expectedParticipantPublicKey,
      );
      expect(
        (await api.redeemRoomInvite(fresh.sign(getPrivkey(0)))).participants,
        hasLength(1),
      );
    });

    test('accepts shared framing and echoes the request ID', () async {
      final response = await exchange(protocol.encodeEnvelope(begin()));
      expect(response.wireVersion, noosphereIrohWireVersion);
      expect(response.rpcResponse.requestId, [1, 2, 3]);
      final challenge = EnrollmentChallenge.fromBytes(
        Uint8List.fromList(response.rpcResponse.beginEnrollment.challenge),
      );
      expect(challenge.transcript.inviteId, invite.inviteId);
    });

    test('rejects wrong versions, payloads, and missing request IDs', () async {
      final version = await exchange(
        protocol.encodeEnvelope(begin()..wireVersion = 99),
      );
      expect(
        version.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_UNSUPPORTED_VERSION,
      );
      final payload = await exchange(
        protocol.encodeEnvelope(
          protocol.Envelope(wireVersion: 1, ready: protocol.Ready()),
        ),
      );
      expect(
        payload.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
      );
      final emptyId = await exchange(
        protocol.encodeEnvelope(begin(id: const [])),
      );
      expect(
        emptyId.rpcResponse.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
      );
      expect(emptyId.rpcResponse.error.hasRoomFailureCode(), isFalse);
    });

    test('each ALPN rejects RPCs belonging to the other', () async {
      final signing = begin()..rpcRequest.login = protocol.LoginRequest();
      final response = await exchange(protocol.encodeEnvelope(signing));
      expect(
        response.rpcResponse.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
      );
      final wrongAlpn = await exchange(
        protocol.encodeEnvelope(begin()),
        alpn: noosphereIrohAlpn,
      );
      expect(
        wrongAlpn.rpcResponse.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
      );
    });

    test(
      'rejects malformed key and signature bytes without enrollment',
      () async {
        final badKey = begin()
          ..rpcRequest.beginEnrollment.participantPublicKey = [1];
        final keyResponse = await exchange(protocol.encodeEnvelope(badKey));
        expect(
          keyResponse.rpcResponse.error.code,
          protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
        );
        final challenge = await api.beginEnrollment(
          invite: invite,
          participantPublicKey: invite.expectedParticipantPublicKey,
        );
        final badSignature = begin()
          ..rpcRequest.redeemRoomInvite = protocol.RedeemRoomInviteRequest(
            transcript: challenge.transcript.toBytes(),
            signature: [1],
          );
        final signatureResponse = await exchange(
          protocol.encodeEnvelope(badSignature),
        );
        expect(
          signatureResponse.rpcResponse.error.code,
          protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
        );
        expect((await rooms.getRoom('room')).participants, isEmpty);
      },
    );

    test('bounds frames and rejects truncated or multiple requests', () async {
      final oversized = await exchange([0, 0, 16, 1]);
      expect(
        oversized.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
      );
      final truncated = await exchange([0, 0, 0, 20, 8, 1]);
      expect(
        truncated.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
      );
      final frame = protocol.encodeEnvelope(begin());
      final multiple = await exchange([...frame, ...frame]);
      expect(
        multiple.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
      );
      final partial = await exchange([0, 0], finish: false);
      expect(
        partial.error.code,
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_DEADLINE_EXCEEDED,
      );
    });

    test(
      'rejects extra redemption frames before consuming the proof',
      () async {
        final challenge = await api.beginEnrollment(
          invite: invite,
          participantPublicKey: invite.expectedParticipantPublicKey,
        );
        final proof = challenge.sign(getPrivkey(0));
        final request = begin()
          ..rpcRequest.redeemRoomInvite = protocol.RedeemRoomInviteRequest(
            transcript: proof.obj.toBytes(),
            signature: proof.signature.data,
          );
        final frame = protocol.encodeEnvelope(request);
        final response = await exchange([...frame, ...frame]);
        expect(
          response.error.code,
          protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
        );
        expect((await rooms.getRoom('room')).participants, isEmpty);
        expect((await api.redeemRoomInvite(proof)).participants, hasLength(1));
      },
    );

    test(
      'rejects oversized outgoing requests before opening a stream',
      () async {
        final small = await IrohRoomEnrollmentApi.connect(
          IrohClientTransportConfig(
            bootstrapAddress: _address(server.endpoint),
            pinnedServerId: server.id,
            relay: IrohRelayConfig.disabled(),
            maxEnvelopeLength: 16,
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

  group('enrollment client validates responses', () {
    for (final fault in [
      'version',
      'request ID',
      'variant',
      'payload',
      'multiple frames',
      'truncated frame',
      'oversized frame',
      'envelope error',
    ]) {
      test(fault, () async {
        final endpoint = await Endpoint.bind(
          alpns: [noosphereEnrollmentAlpn.codeUnits],
          relayMode: RelayMode.disabled,
        );
        addTearDown(endpoint.close);
        final invite = RoomInvite(
          roomId: 'room',
          inviteId: 'invite',
          token: Uint8List(32),
          expectedParticipantPublicKey: cl.ECCompressedPublicKey.fromPubkey(
            getPrivkey(0).pubkey,
          ),
          coordinatorEndpointId: endpoint.id.asBytes(),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        final serving = () async {
          final connection = (await endpoint.accept())!;
          addTearDown(() => connection.close());
          final (send, receive) = await connection.acceptBi();
          final request = await protocol
              .decodeEnvelopes(_chunks(receive))
              .single;
          final response = protocol.Envelope(
            wireVersion: noosphereIrohWireVersion,
            rpcResponse: protocol.RpcResponse(
              requestId: request.rpcRequest.requestId,
              beginEnrollment: protocol.BeginEnrollmentResponse(
                challenge: EnrollmentChallenge(
                  transcript: EnrollmentTranscript.forInvite(
                    invite,
                    Uint8List(32),
                  ),
                  expiresAt: invite.expiresAt,
                ).toBytes(),
              ),
            ),
          );
          switch (fault) {
            case 'version':
              response.wireVersion = 99;
            case 'request ID':
              response.rpcResponse.requestId = [0];
            case 'variant':
              response.rpcResponse.redeemRoomInvite =
                  protocol.RedeemRoomInviteResponse();
            case 'payload':
              response.ready = protocol.Ready();
            case 'envelope error':
              response.error = protocol.ProtocolError(
                code: protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
                message: 'invalid request',
              );
          }
          final frame = protocol.encodeEnvelope(response);
          await send.writeAll(switch (fault) {
            'multiple frames' => [...frame, ...frame],
            'truncated frame' => frame.sublist(0, frame.length - 1),
            'oversized frame' => [0, 0, 16, 1],
            _ => frame,
          });
          await send.finish();
        }();
        final api = await IrohRoomEnrollmentApi.connect(transport(endpoint));
        addTearDown(api.close);
        await expectLater(
          api.beginEnrollment(
            invite: invite,
            participantPublicKey: invite.expectedParticipantPublicKey,
          ),
          throwsA(switch (fault) {
            'multiple frames' => isA<StateError>(),
            'truncated frame' => isA<protocol.TruncatedFrameException>(),
            'oversized frame' => isA<protocol.FrameTooLargeException>(),
            'envelope error' => isA<RoomEnrollmentProtocolException>().having(
              (e) => e.code,
              'generic error code',
              0xffff,
            ),
            _ => isA<FormatException>(),
          }),
        );
        await serving;
      });
    }
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
    final chunk = await receive.read(64 * 1024);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

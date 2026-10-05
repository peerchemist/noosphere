import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/wire.dart' as protocol;
import 'package:noosphere/room.dart';

import '../client/client.dart';
import '../client/room_enrollment.dart';
import '../config/client.dart';
import 'config.dart';
import 'endpoint.dart';

final class RoomEnrollmentProtocolException implements Exception {
  const RoomEnrollmentProtocolException(this.code, this.message, {this.error});

  /// RoomFailureCode index, or 0xffff for a transport/protocol error.
  final int code;
  final String message;
  final protocol.ProtocolError? error;

  @override
  String toString() => 'RoomEnrollmentProtocolException($code): $message';
}

/// Enrollment transport over the coordinator's dedicated Iroh ALPN.
final class IrohRoomEnrollmentApi implements RoomEnrollmentApi {
  IrohRoomEnrollmentApi._(this.config, this._endpoint, this._connection);

  static Future<IrohRoomEnrollmentApi> connect(
    IrohClientTransportConfig transport, {
    IrohClientEndpoint? endpoint,
  }) async {
    final config = IrohClientTransportConfig(
      bootstrapAddress: transport.bootstrapAddress,
      pinnedServerId: transport.pinnedServerId,
      relay: transport.relay,
      alpn: protocol.noosphereEnrollmentAlpn,
      connectTimeout: transport.connectTimeout,
      authTimeout: transport.authTimeout,
      rpcTimeout: transport.rpcTimeout,
      maxEnvelopeLength: transport.maxEnvelopeLength,
      maxConcurrentStreams: transport.maxConcurrentStreams,
      nativeLibraryPath: transport.nativeLibraryPath,
    );
    final wrapper = endpoint ?? await IrohClientEndpoint.bind(config);
    try {
      return IrohRoomEnrollmentApi._(
        config,
        wrapper,
        await wrapper.connect(config),
      );
    } catch (_) {
      if (endpoint == null) await wrapper.close();
      rethrow;
    }
  }

  /// Verifies the participant key before opening an Iroh connection.
  static Future<RoomSnapshot> joinRoom(
    IrohClientTransportConfig transport,
    RoomInvite invite,
    GetPrivateKey getPrivateKey, {
    IrohClientEndpoint? endpoint,
  }) async {
    final key = await getPrivateKey(KeyPurpose.roomEnrollment);
    invite.requirePrivateKey(key);
    final api = await connect(transport, endpoint: endpoint);
    try {
      return await RoomEnrollmentClient(api).joinRoom(invite, (_) async => key);
    } finally {
      await api.close();
    }
  }

  final IrohClientTransportConfig config;
  final IrohClientEndpoint _endpoint;
  final Connection _connection;
  bool _closed = false;

  @override
  Future<EnrollmentChallenge> beginEnrollment({
    required RoomInvite invite,
    required cl.ECCompressedPublicKey participantPublicKey,
  }) async {
    final response = await _rpc(
      protocol.RpcRequest(
        beginEnrollment: protocol.BeginEnrollmentRequest(
          invite: invite.toBytes(),
          participantPublicKey: participantPublicKey.data,
        ),
      ),
      protocol.RpcResponse_Response.beginEnrollment,
    );
    return EnrollmentChallenge.fromBytes(
      Uint8List.fromList(response.beginEnrollment.challenge),
    );
  }

  @override
  Future<RoomSnapshot> redeemRoomInvite(
    Signed<EnrollmentTranscript> proof,
  ) async {
    final response = await _rpc(
      protocol.RpcRequest(
        redeemRoomInvite: protocol.RedeemRoomInviteRequest(
          transcript: proof.obj.toBytes(),
          signature: proof.signature.data,
        ),
      ),
      protocol.RpcResponse_Response.redeemRoomInvite,
    );
    return RoomSnapshot.fromBytes(
      Uint8List.fromList(response.redeemRoomInvite.snapshot),
    );
  }

  Future<protocol.RpcResponse> _rpc(
    protocol.RpcRequest request,
    protocol.RpcResponse_Response expected,
  ) async {
    if (_closed) throw StateError('enrollment client is closed');
    final requestId = cl.generateRandomBytes(16);
    request.requestId = requestId;
    final frame = protocol.encodeEnvelope(
      protocol.Envelope(
        wireVersion: protocol.noosphereIrohWireVersion,
        rpcRequest: request,
      ),
      maxEnvelopeLength: config.maxEnvelopeLength,
    );
    final (send, receive) = await _connection.openBi();
    var requestFinished = false;
    var responseReceived = false;
    try {
      await send.writeAll(frame).timeout(config.authTimeout);
      await send.finish().timeout(config.authTimeout);
      requestFinished = true;
      final envelope = await protocol
          .decodeEnvelopes(
            _readChunks(receive),
            maxEnvelopeLength: config.maxEnvelopeLength,
          )
          .single
          .timeout(config.authTimeout);
      responseReceived = true;
      if (envelope.wireVersion != protocol.noosphereIrohWireVersion) {
        throw const FormatException('unsupported Iroh wire version');
      }
      if (envelope.whichPayload() == protocol.Envelope_Payload.error) {
        _throwProtocolError(envelope.error);
      }
      if (envelope.whichPayload() != protocol.Envelope_Payload.rpcResponse) {
        throw const FormatException('expected enrollment RpcResponse');
      }
      final response = envelope.rpcResponse;
      if (!cl.bytesEqual(Uint8List.fromList(response.requestId), requestId)) {
        throw const FormatException('response request_id mismatch');
      }
      if (response.whichResponse() == protocol.RpcResponse_Response.error) {
        _throwProtocolError(response.error);
      }
      if (response.whichResponse() != expected) {
        throw const FormatException('invalid enrollment response');
      }
      return response;
    } on Object {
      if (!requestFinished) {
        try {
          await send.reset(1).timeout(config.authTimeout);
        } on TimeoutException {
          _connection.close(
            reason: 'enrollment stream cleanup failed'.codeUnits,
          );
        } on Object {
          // Preserve the request failure if the stream is already closed.
        }
      }
      if (!responseReceived) {
        try {
          await receive.stop(1).timeout(config.authTimeout);
        } on TimeoutException {
          _connection.close(
            reason: 'enrollment stream cleanup failed'.codeUnits,
          );
        } on Object {
          // Preserve the request failure if the stream is already closed.
        }
      }
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connection.close(reason: 'enrollment complete'.codeUnits);
    await _endpoint.close();
  }
}

Never _throwProtocolError(protocol.ProtocolError error) =>
    throw RoomEnrollmentProtocolException(
      error.hasRoomFailureCode() ? error.roomFailureCode : 0xffff,
      error.message,
      error: error,
    );

Stream<List<int>> _readChunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(64 * 1024);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

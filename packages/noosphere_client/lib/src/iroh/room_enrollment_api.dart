import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/wire.dart' as protocol;
import 'package:noosphere/room.dart';
import 'package:protobuf/protobuf.dart';

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
      maxMessageLength: transport.maxMessageLength,
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

  static Future<IrohClientTransportConfig> _transportForInvite(
    RoomInvite invite, {
    String? nativeLibraryPath,
  }) async {
    await Iroh.init(libraryPath: nativeLibraryPath);
    final coordinatorId = EndpointId.fromBytes(invite.coordinatorEndpointId);
    return IrohClientTransportConfig(
      bootstrapAddress: EndpointAddr(coordinatorId),
      pinnedServerId: coordinatorId,
      nativeLibraryPath: nativeLibraryPath,
    );
  }

  /// Finds the pinned coordinator from [invite], then verifies the participant
  /// key before opening an Iroh connection.
  static Future<RoomSnapshot> joinRoom(
    RoomInvite invite,
    GetPrivateKey getPrivateKey, {
    IrohClientEndpoint? endpoint,
    String? nativeLibraryPath,
  }) async {
    final key = await getPrivateKey(KeyPurpose.roomEnrollment);
    invite.requirePrivateKey(key);
    final config = await _transportForInvite(
      invite,
      nativeLibraryPath: nativeLibraryPath,
    );
    final api = await connect(config, endpoint: endpoint);
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
      protocol.EnrollmentOperation.beginEnrollment,
      protocol.BeginEnrollmentRequest(
        invite: invite.toBytes(),
        participantPublicKey: participantPublicKey.data,
      ),
      protocol.BeginEnrollmentResponse.fromBuffer,
    );
    return EnrollmentChallenge.fromBytes(
      Uint8List.fromList(response.challenge),
    );
  }

  @override
  Future<RoomSnapshot> redeemRoomInvite(
    Signed<EnrollmentTranscript> proof,
  ) async {
    final response = await _rpc(
      protocol.EnrollmentOperation.redeemRoomInvite,
      protocol.RedeemRoomInviteRequest(
        transcript: proof.obj.toBytes(),
        signature: proof.signature.data,
      ),
      protocol.RedeemRoomInviteResponse.fromBuffer,
    );
    return RoomSnapshot.fromBytes(Uint8List.fromList(response.snapshot));
  }

  Future<T> _rpc<T extends GeneratedMessage>(
    protocol.EnrollmentOperation operation,
    GeneratedMessage request,
    T Function(List<int>) decodeResponse,
  ) async {
    if (_closed) throw StateError('enrollment client is closed');
    final body = request.writeToBuffer();
    if (body.length > config.maxMessageLength) {
      throw protocol.FrameTooLargeException(
        length: body.length,
        maximum: config.maxMessageLength,
      );
    }
    final (send, receive) = await _connection.openBi();
    var requestFinished = false;
    var responseReceived = false;
    try {
      await send
          .writeAll(protocol.encodeQuicVarInt(operation.id))
          .timeout(config.authTimeout);
      await send.writeAll(body).timeout(config.authTimeout);
      await send.finish().timeout(config.authTimeout);
      requestFinished = true;
      final reader = protocol.QuicStreamReader(_readChunks(receive));
      final status = await reader.readVarInt().timeout(config.authTimeout);
      final responseBody = await reader
          .readToEnd(maxLength: config.maxMessageLength)
          .timeout(config.authTimeout);
      responseReceived = true;
      if (status == protocol.RpcResponseStatus.error) {
        _throwProtocolError(protocol.ProtocolError.fromBuffer(responseBody));
      }
      if (status != protocol.RpcResponseStatus.success) {
        throw FormatException('unknown response status $status');
      }
      return decodeResponse(responseBody);
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

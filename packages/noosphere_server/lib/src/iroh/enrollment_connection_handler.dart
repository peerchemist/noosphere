import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/api/types/signed.dart';
import 'package:noosphere_protocol/wire.dart' as protocol;
import 'package:noosphere_protocol/room.dart';

import '../room/manager.dart';
import 'stream_policy.dart';

final class IrohEnrollmentConnectionHandler {
  IrohEnrollmentConnectionHandler({
    required this.connection,
    required this.onError,
    required this.rooms,
    required this.timeout,
    required this.maxMessageLength,
    required this.maxStreams,
  }) : _streamPolicy = IrohStreamPolicy(
         connection: connection,
         onError: onError,
         timeout: timeout,
         maxConcurrent: maxStreams,
         idleTimeout: timeout,
       );

  final Connection connection;
  final void Function(Object, StackTrace) onError;
  final RoomManager rooms;
  final Duration timeout;
  final int maxMessageLength;
  final int maxStreams;
  final IrohStreamPolicy _streamPolicy;

  Future<void> run() async {
    _streamPolicy.startIdleDeadline();
    try {
      while (true) {
        final (send, receive) = await connection.acceptBi();
        await _streamPolicy.admit(
          send: send,
          receive: receive,
          handle: () => _handle(send, receive),
        );
      }
    } on IrohConnectionException {
      // Normal peer disconnect.
    } finally {
      await _streamPolicy.drain();
    }
  }

  Future<void> _handle(SendStream send, RecvStream receive) async {
    final reader = protocol.QuicStreamReader(readIrohChunks(receive));
    var requestReceived = false;
    try {
      final operationId = await reader.readVarInt().timeout(timeout);
      final body = await reader
          .readToEnd(maxLength: maxMessageLength)
          .timeout(timeout);
      requestReceived = true;
      final operation = protocol.EnrollmentOperation.fromId(operationId);
      if (operation == null) {
        throw FormatException('unknown enrollment operation ID $operationId');
      }
      final response = await _dispatch(operation, body).timeout(timeout);
      await _write(send, protocol.RpcResponseStatus.success, response);
    } catch (error) {
      if (!isIrohRequestError(error)) rethrow;
      final failure = _protocolError(error);
      try {
        await _write(send, protocol.RpcResponseStatus.error, failure);
      } on Exception {
        // The peer may already have closed the stream.
      }
    } finally {
      await _streamPolicy.finishStream(
        send: send,
        receive: receive,
        reader: reader,
        requestReceived: requestReceived,
      );
    }
  }

  Future<protocol.WireMessage> _dispatch(
    protocol.EnrollmentOperation operation,
    List<int> bytes,
  ) async {
    switch (operation) {
      case protocol.EnrollmentOperation.beginEnrollment:
        final body = protocol.BeginEnrollmentRequest.fromBuffer(bytes);
        final challenge = await rooms.beginEnrollment(
          invite: RoomInvite.fromBytes(Uint8List.fromList(body.invite)),
          participantPublicKey: cl.ECCompressedPublicKey(
            Uint8List.fromList(body.participantPublicKey),
          ),
        );
        return protocol.BeginEnrollmentResponse(challenge: challenge.toBytes());
      case protocol.EnrollmentOperation.redeemRoomInvite:
        final body = protocol.RedeemRoomInviteRequest.fromBuffer(bytes);
        final snapshot = await rooms.redeemRoomInvite(
          Signed(
            obj: EnrollmentTranscript.fromBytes(
              Uint8List.fromList(body.transcript),
            ),
            signature: cl.SchnorrSignature(Uint8List.fromList(body.signature)),
          ),
        );
        return protocol.RedeemRoomInviteResponse(snapshot: snapshot.toBytes());
    }
  }

  Future<void> _write(
    SendStream send,
    int status,
    protocol.WireMessage message,
  ) async {
    final body = message.writeToBuffer();
    if (body.length > maxMessageLength) {
      throw protocol.FrameTooLargeException(
        length: body.length,
        maximum: maxMessageLength,
      );
    }
    await send.writeAll(protocol.encodeQuicVarInt(status)).timeout(timeout);
    await send.writeAll(body).timeout(timeout);
  }
}

protocol.ProtocolError _protocolError(Object error) {
  final roomError = error is RoomException
      ? error
      : error is UnsupportedRoomInviteVersion
      ? const RoomException(RoomFailureCode.unsupportedVersion)
      : null;
  return protocol.ProtocolError(
    code: switch (error) {
      _ when roomError?.code == RoomFailureCode.unsupportedVersion =>
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_UNSUPPORTED_VERSION,
      _ => commonIrohProtocolErrorCode(error),
    },
    message: roomError?.message ?? 'invalid enrollment request',
    roomFailureCode: roomError?.code.index,
  );
}

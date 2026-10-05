import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/wire.dart' as protocol;
import 'package:noosphere/room.dart';
import 'package:protobuf/protobuf.dart';

import '../room/manager.dart';

final class IrohEnrollmentConnectionHandler {
  IrohEnrollmentConnectionHandler({
    required this.connection,
    required this.rooms,
    required this.timeout,
    required this.maxMessageLength,
    required this.maxStreams,
  });

  final Connection connection;
  final RoomManager rooms;
  final Duration timeout;
  final int maxMessageLength;
  final int maxStreams;
  final Set<Future<void>> _streams = {};

  Future<void> run() async {
    try {
      while (true) {
        final (send, receive) = await connection.acceptBi();
        if (_streams.length >= maxStreams) {
          await send.reset(1);
          await receive.stop(1);
          continue;
        }
        late final Future<void> handling;
        handling = _handle(
          send,
          receive,
        ).whenComplete(() => _streams.remove(handling));
        _streams.add(handling);
      }
    } on IrohConnectionException {
      // Normal peer disconnect.
    } finally {
      await Future.wait(_streams.toList(), eagerError: false);
    }
  }

  Future<void> _handle(SendStream send, RecvStream receive) async {
    var requestReceived = false;
    try {
      final reader = protocol.QuicStreamReader(_readChunks(receive));
      final operationId = await reader.readVarInt().timeout(timeout);
      final body = await reader
          .readToEnd(maxLength: maxMessageLength)
          .timeout(timeout);
      requestReceived = true;
      final operation = protocol.EnrollmentOperation.fromId(operationId);
      if (operation == null) {
        throw FormatException('unknown enrollment operation ID $operationId');
      }
      final response = await _dispatch(operation, body);
      await _write(send, protocol.RpcResponseStatus.success, response);
    } on Object catch (error) {
      final failure = _protocolError(error);
      try {
        await _write(send, protocol.RpcResponseStatus.error, failure);
      } on Object {
        // The peer may already have closed the stream.
      }
    } finally {
      try {
        await send.finish().timeout(timeout);
      } on Object {
        // Connection loss is already represented by the failed request.
      }
      if (!requestReceived) {
        try {
          // Finish the reply before stopping a potentially blocked native read.
          await receive.stop(1).timeout(timeout);
        } on TimeoutException {
          connection.close(
            reason: 'enrollment stream cleanup failed'.codeUnits,
          );
        } on Object {
          // Preserve the request failure if the stream is already closed.
        }
      }
    }
  }

  Future<GeneratedMessage> _dispatch(
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
    GeneratedMessage message,
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
      protocol.FrameTooLargeException() =>
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
      TimeoutException() =>
        protocol.ProtocolErrorCode.PROTOCOL_ERROR_DEADLINE_EXCEEDED,
      _ => protocol.ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
    },
    message: roomError?.message ?? 'invalid enrollment request',
    roomFailureCode: roomError?.code.index,
  );
}

Stream<List<int>> _readChunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(64 * 1024);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

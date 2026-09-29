import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/iroh.dart';
import 'package:noosphere/noosphere.dart' as protocol;
import 'package:noosphere/room.dart';

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
    protocol.RpcRequest? request;
    var requestReceived = false;
    try {
      final envelope = await protocol
          .decodeEnvelopes(
            _readChunks(receive),
            maxEnvelopeLength: maxMessageLength,
          )
          .single
          .timeout(timeout);
      requestReceived = true;
      if (envelope.wireVersion != noosphereIrohWireVersion) {
        throw const RoomException(RoomFailureCode.unsupportedVersion);
      }
      if (envelope.whichPayload() != protocol.Envelope_Payload.rpcRequest) {
        throw const FormatException('expected enrollment RpcRequest');
      }
      request = envelope.rpcRequest;
      if (request.requestId.isEmpty) {
        throw const FormatException('request_id is empty');
      }
      final response = await _dispatch(request);
      await _write(
        send,
        protocol.Envelope(
          wireVersion: noosphereIrohWireVersion,
          rpcResponse: response,
        ),
      );
    } on Object catch (error) {
      final failure = _protocolError(error);
      try {
        await _write(
          send,
          protocol.Envelope(
            wireVersion: noosphereIrohWireVersion,
            rpcResponse: request == null
                ? null
                : protocol.RpcResponse(
                    requestId: request.requestId,
                    error: failure,
                  ),
            error: request == null ? failure : null,
          ),
        );
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

  Future<protocol.RpcResponse> _dispatch(protocol.RpcRequest request) async {
    switch (request.whichRequest()) {
      case protocol.RpcRequest_Request.beginEnrollment:
        final body = request.beginEnrollment;
        final challenge = await rooms.beginEnrollment(
          invite: RoomInvite.fromBytes(Uint8List.fromList(body.invite)),
          participantPublicKey: cl.ECCompressedPublicKey(
            Uint8List.fromList(body.participantPublicKey),
          ),
        );
        return protocol.RpcResponse(
          requestId: request.requestId,
          beginEnrollment: protocol.BeginEnrollmentResponse(
            challenge: challenge.toBytes(),
          ),
        );
      case protocol.RpcRequest_Request.redeemRoomInvite:
        final body = request.redeemRoomInvite;
        final snapshot = await rooms.redeemRoomInvite(
          Signed(
            obj: EnrollmentTranscript.fromBytes(
              Uint8List.fromList(body.transcript),
            ),
            signature: cl.SchnorrSignature(Uint8List.fromList(body.signature)),
          ),
        );
        return protocol.RpcResponse(
          requestId: request.requestId,
          redeemRoomInvite: protocol.RedeemRoomInviteResponse(
            snapshot: snapshot.toBytes(),
          ),
        );
      default:
        throw const FormatException(
          'RPC is not supported on the enrollment ALPN',
        );
    }
  }

  Future<void> _write(SendStream send, protocol.Envelope envelope) => send
      .writeAll(
        protocol.encodeEnvelope(envelope, maxEnvelopeLength: maxMessageLength),
      )
      .timeout(timeout);
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

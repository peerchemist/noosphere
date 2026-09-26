import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/common/serial.dart';
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
    try {
      final request = await _readFrame(
        receive,
        maxMessageLength,
      ).timeout(timeout);
      final reader = cl.BytesReader(request);
      final protocol = reader.readString();
      final version = reader.readUInt16();
      if (protocol != noosphereEnrollmentProtocol ||
          version != noosphereEnrollmentProtocolVersion) {
        throw const RoomException(RoomFailureCode.unsupportedVersion);
      }
      final operation = reader.readUInt8();
      final Uint8List payload;
      switch (operation) {
        case 1:
          final invite = RoomInvite.fromBytes(reader.readVarSlice());
          final publicKey = reader.readPubKey();
          if (!reader.atEnd) {
            throw const FormatException('trailing request data');
          }
          payload = (await rooms.beginEnrollment(
            invite: invite,
            participantPublicKey: publicKey,
          )).toBytes();
        case 2:
          final transcript = EnrollmentTranscript.fromBytes(
            reader.readVarSlice(),
          );
          final signature = reader.readSignature();
          if (!reader.atEnd) {
            throw const FormatException('trailing request data');
          }
          payload = (await rooms.redeemRoomInvite(
            Signed(obj: transcript, signature: signature),
          )).toBytes();
        default:
          throw const FormatException('unknown enrollment operation');
      }
      await _writeFrame(
        send,
        _EnrollmentResponse.success(operation, payload),
      ).timeout(timeout);
    } on Object catch (error) {
      final code = error is RoomException ? error.code.index : 0xffff;
      final message = error is RoomException
          ? error.message
          : 'invalid enrollment request';
      try {
        await _writeFrame(
          send,
          _EnrollmentResponse.failure(code, message),
        ).timeout(timeout);
      } on Object {
        // The peer may already have closed the stream.
      }
    } finally {
      try {
        await send.finish().timeout(timeout);
      } on Object {
        // Connection loss is already represented by the failed request.
      }
    }
  }
}

final class _EnrollmentResponse with cl.Writable {
  _EnrollmentResponse.success(this.operation, this.payload)
    : success = true,
      errorCode = 0,
      message = '';

  _EnrollmentResponse.failure(this.errorCode, this.message)
    : success = false,
      operation = 0,
      payload = Uint8List(0);

  final bool success;
  final int operation;
  final Uint8List payload;
  final int errorCode;
  final String message;

  @override
  void write(cl.Writer writer) {
    writer.writeBool(success);
    if (success) {
      writer
        ..writeUInt8(operation)
        ..writeVarSlice(payload);
    } else {
      writer
        ..writeUInt16(errorCode)
        ..writeString(message);
    }
  }
}

Future<Uint8List> _readFrame(RecvStream receive, int maximum) async {
  final prefix = await receive.readExact(4);
  final length = ByteData.sublistView(prefix).getUint32(0, Endian.little);
  if (length < 1 || length > maximum) {
    throw const FormatException('invalid enrollment frame length');
  }
  return receive.readExact(length);
}

Future<void> _writeFrame(SendStream send, cl.Writable value) async {
  final payload = value.toBytes();
  final frame = Uint8List(4 + payload.length);
  ByteData.sublistView(frame).setUint32(0, payload.length, Endian.little);
  frame.setRange(4, frame.length, payload);
  await send.writeAll(frame);
}

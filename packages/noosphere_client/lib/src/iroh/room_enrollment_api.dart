import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/common/serial.dart';
import 'package:noosphere/room.dart';

import '../client/client.dart';
import '../client/room_enrollment.dart';
import '../config/client.dart';
import 'config.dart';
import 'endpoint.dart';

final class RoomEnrollmentProtocolException implements Exception {
  const RoomEnrollmentProtocolException(this.code, this.message);

  final int code;
  final String message;

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
      alpn: noosphereEnrollmentAlpn,
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
      _EnrollmentRequest.begin(invite, participantPublicKey),
      1,
    );
    return EnrollmentChallenge.fromBytes(response);
  }

  @override
  Future<RoomSnapshot> redeemRoomInvite(
    Signed<EnrollmentTranscript> proof,
  ) async {
    final response = await _rpc(_EnrollmentRequest.redeem(proof), 2);
    return RoomSnapshot.fromBytes(response);
  }

  Future<Uint8List> _rpc(cl.Writable request, int expectedOperation) async {
    if (_closed) throw StateError('enrollment client is closed');
    final (send, receive) = await _connection.openBi();
    try {
      await _writeFrame(send, request).timeout(config.authTimeout);
      await send.finish().timeout(config.authTimeout);
      final bytes = await _readFrame(
        receive,
        config.maxEnvelopeLength,
      ).timeout(config.authTimeout);
      final reader = cl.BytesReader(bytes);
      final success = reader.readBool();
      if (!success) {
        final code = reader.readUInt16();
        final message = reader.readString();
        if (!reader.atEnd) {
          throw const FormatException('trailing enrollment error data');
        }
        throw RoomEnrollmentProtocolException(code, message);
      }
      final operation = reader.readUInt8();
      final payload = reader.readVarSlice();
      if (operation != expectedOperation || !reader.atEnd) {
        throw const FormatException('invalid enrollment response');
      }
      return payload;
    } on Object {
      try {
        await receive.stop(1);
      } on Object {
        // Preserve the request failure.
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

final class _EnrollmentRequest with cl.Writable {
  _EnrollmentRequest.begin(this.invite, this.publicKey)
    : operation = 1,
      proof = null;

  _EnrollmentRequest.redeem(this.proof)
    : operation = 2,
      invite = null,
      publicKey = null;

  final int operation;
  final RoomInvite? invite;
  final cl.ECCompressedPublicKey? publicKey;
  final Signed<EnrollmentTranscript>? proof;

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString(noosphereEnrollmentProtocol)
      ..writeUInt16(noosphereEnrollmentProtocolVersion)
      ..writeUInt8(operation);
    if (operation == 1) {
      writer
        ..writeVarSlice(invite!.toBytes())
        ..writePubKey(publicKey!);
    } else {
      writer
        ..writeVarSlice(proof!.obj.toBytes())
        ..writeSignature(proof!.signature);
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

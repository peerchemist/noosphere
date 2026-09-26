import 'dart:convert';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/common/serial.dart';

const String noosphereEnrollmentProtocol = 'noosphere/roast-enrollment/1';
const int noosphereEnrollmentProtocolVersion = 1;

final class UnsupportedRoomInviteVersion implements FormatException {
  const UnsupportedRoomInviteVersion(this.version);

  final int version;

  @override
  String get message => 'unsupported room invite version: $version';

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'UnsupportedRoomInviteVersion($version)';
}

/// A short-lived invite bound to one participant key and one coordinator.
///
/// [token] is the only bearer-secret component. Servers must persist
/// [tokenHash], never [token]. Possession of it is still insufficient to join:
/// redemption also requires a signature from [expectedParticipantPublicKey].
final class RoomInvite with cl.Writable {
  RoomInvite({
    this.version = noosphereEnrollmentProtocolVersion,
    required this.roomId,
    required this.inviteId,
    required Uint8List token,
    required this.expectedParticipantPublicKey,
    required Uint8List coordinatorEndpointId,
    Iterable<String> relayUrls = const [],
    Iterable<String> ipAddrs = const [],
    required this.expiresAt,
  }) : _token = _copyExact(token, 32, 'token'),
       _coordinatorEndpointId = _copyExact(
         coordinatorEndpointId,
         32,
         'coordinatorEndpointId',
       ),
       relayUrls = List.unmodifiable(relayUrls),
       ipAddrs = List.unmodifiable(ipAddrs) {
    _checkVersion(version);
    _checkId(roomId, 'roomId');
    _checkId(inviteId, 'inviteId');
    _checkStrings(this.relayUrls, 'relayUrls');
    _checkStrings(this.ipAddrs, 'ipAddrs');
  }

  factory RoomInvite.fromBytes(Uint8List bytes) {
    final reader = cl.BytesReader(bytes);
    final protocol = reader.readString();
    if (protocol != noosphereEnrollmentProtocol) {
      throw const FormatException('not a Noosphere room invite');
    }
    final version = reader.readUInt16();
    _checkVersion(version);
    final invite = RoomInvite(
      version: version,
      roomId: reader.readString(),
      inviteId: reader.readString(),
      token: reader.readSlice(32),
      expectedParticipantPublicKey: reader.readPubKey(),
      coordinatorEndpointId: reader.readSlice(32),
      relayUrls: _readStrings(reader),
      ipAddrs: _readStrings(reader),
      expiresAt: reader.readTime(),
    );
    if (!reader.atEnd) throw const FormatException('trailing invite data');
    return invite;
  }

  factory RoomInvite.decode(String encoded) {
    try {
      return RoomInvite.fromBytes(
        base64Url.decode(base64Url.normalize(encoded)),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('invalid room invite encoding', error);
    }
  }

  final int version;
  final String roomId;
  final String inviteId;
  final Uint8List _token;
  final cl.ECCompressedPublicKey expectedParticipantPublicKey;
  final Uint8List _coordinatorEndpointId;
  final List<String> relayUrls;
  final List<String> ipAddrs;
  final DateTime expiresAt;

  Uint8List get token => Uint8List.fromList(_token);
  Uint8List get coordinatorEndpointId =>
      Uint8List.fromList(_coordinatorEndpointId);
  Uint8List get tokenHash => cl.sha256Hash(_token);

  String encode() => base64Url.encode(toBytes()).replaceAll('=', '');

  bool matchesPrivateKey(cl.ECPrivateKey privateKey) => cl.bytesEqual(
    expectedParticipantPublicKey.data,
    cl.ECCompressedPublicKey.fromPubkey(privateKey.pubkey).data,
  );

  void requirePrivateKey(cl.ECPrivateKey privateKey) {
    if (!matchesPrivateKey(privateKey)) {
      throw ArgumentError.value(
        privateKey,
        'privateKey',
        'does not match invite participant public key',
      );
    }
  }

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString(noosphereEnrollmentProtocol)
      ..writeUInt16(version)
      ..writeString(roomId)
      ..writeString(inviteId)
      ..writeSlice(_token)
      ..writePubKey(expectedParticipantPublicKey)
      ..writeSlice(_coordinatorEndpointId);
    _writeStrings(writer, relayUrls);
    _writeStrings(writer, ipAddrs);
    writer.writeTime(expiresAt);
  }
}

void _checkVersion(int version) {
  if (version != noosphereEnrollmentProtocolVersion) {
    throw UnsupportedRoomInviteVersion(version);
  }
}

void _checkId(String value, String name) {
  final length = utf8.encode(value).length;
  if (length < 1 || length > 255) {
    throw ArgumentError.value(value, name, 'must be 1..255 UTF-8 bytes');
  }
}

void _checkStrings(List<String> values, String name) {
  if (values.length > 0xffff) throw ArgumentError.value(values, name);
  for (final value in values) {
    if (utf8.encode(value).length > 0xffff) {
      throw ArgumentError.value(value, name, 'entry is too long');
    }
  }
}

Uint8List _copyExact(Uint8List bytes, int length, String name) {
  if (bytes.length != length) {
    throw ArgumentError.value(bytes.length, name, 'must contain $length bytes');
  }
  return Uint8List.fromList(bytes);
}

void _writeStrings(cl.Writer writer, List<String> values) {
  writer.writeUInt16(values.length);
  for (final value in values) {
    writer.writeString(value);
  }
}

List<String> _readStrings(cl.BytesReader reader) => List.unmodifiable(
  List.generate(reader.readUInt16(), (_) => reader.readString()),
);

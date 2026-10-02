import 'dart:collection';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere/common/serial.dart';

import 'map_serial.dart';

typedef ParticipantMap = SplayTreeMap<Identifier, cl.ECCompressedPublicKey>;

/// Configuation for participants in a FROST singing group which can represent
/// multiple FROST keys for a given set of participants whereby each participant
/// has an [Identifier] and associated [cl.ECCompressedPublicKey].
class GroupConfig with cl.Writable, NoosphereWritable, MapWritable {
  /// A unique ID for the group that allows unique groups to be made with the
  /// same participants.
  final String id;

  /// A map from a participant's [Identifier] and their
  /// [cl.ECCompressedPublicKey] used for authentication and for sharing
  /// information confidentially.
  final Map<Identifier, cl.ECCompressedPublicKey> participants;

  GroupConfig({
    required this.id,
    required Map<Identifier, cl.ECCompressedPublicKey> participants,
  }) : participants = Map.unmodifiable(ParticipantMap.of(participants)) {
    RangeError.checkValueInInterval(participants.length, 2, 0xffff);
  }

  factory GroupConfig.fromReader(cl.BytesReader reader) {
    final id = reader.readString();
    final n = reader.readUInt16();

    return GroupConfig(id: id, participants: _readParticipants(reader, n));
  }

  factory GroupConfig.fromMapReader(MapReader reader) {
    final keysNode = reader["participant-keys"];

    return GroupConfig(
      id: reader["id"].require(),
      participants: {
        for (final idString in keysNode.keysOf<String>())
          Identifier.fromHex(idString): cl.ECCompressedPublicKey.fromHex(
            keysNode[idString].require(),
          ),
      },
    );
  }

  factory GroupConfig.fromYaml(String yaml) =>
      GroupConfig.fromMapReader(MapReader.fromYaml(yaml));

  /// Convenience constructor to construct from serialised [bytes].
  factory GroupConfig.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, GroupConfig.fromReader);

  /// Convenience constructor to construct from encoded [hex].
  factory GroupConfig.fromHex(String hex) =>
      GroupConfig.fromBytes(cl.hexToBytes(hex));

  /// A fingerprint made from the [id] and [participants] that is unqiue for
  /// each group and can be used to check for group equality.
  Uint8List get fingerprint => cl.sha256Hash(toBytes());

  @override
  void write(cl.Writer writer) {
    writer.writeString(id);
    writer.writeUInt16(participants.length);
    for (final entry in participants.entries) {
      writer.writeIdentifier(entry.key);
      writer.writePubKey(entry.value);
    }
  }

  @override
  Map<Object, Object> map() => {
    "id": id,
    "participant-keys": {
      for (final entry in participants.entries)
        entry.key.toString(): entry.value.hex,
    },
  };
}

Map<Identifier, cl.ECCompressedPublicKey> _readParticipants(
  cl.BytesReader reader,
  int count,
) {
  final participants = <Identifier, cl.ECCompressedPublicKey>{};
  for (var i = 0; i < count; i++) {
    final id = reader.readIdentifier();
    if (participants.containsKey(id)) {
      throw const FormatException('duplicate participant identifier');
    }
    participants[id] = reader.readPubKey();
  }
  return participants;
}

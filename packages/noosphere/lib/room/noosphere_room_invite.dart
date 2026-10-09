import 'package:noosphere/room/invite.dart';

/// A clickable-link wrapper around a participant-bound [RoomInvite].
///
/// [prefix] is supplied by the application and includes its separator, for
/// example `sygnature-roast-v1:`. The remainder of [encode] is the existing
/// canonical binary [RoomInvite] encoded as unpadded Base64URL.
final class NoosphereRoomInvite {
  NoosphereRoomInvite({required this.prefix, required this.invite}) {
    if (prefix.isEmpty) throw ArgumentError.value(prefix, 'prefix');
  }

  factory NoosphereRoomInvite.decode(String encoded, {required String prefix}) {
    if (prefix.isEmpty || !encoded.startsWith(prefix)) {
      throw const FormatException('invalid Noosphere room invite prefix');
    }
    return NoosphereRoomInvite(
      prefix: prefix,
      invite: RoomInvite.decode(encoded.substring(prefix.length)),
    );
  }

  final String prefix;
  final RoomInvite invite;

  String encode() => '$prefix${invite.encode()}';
}

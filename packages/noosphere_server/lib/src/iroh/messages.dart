import 'dart:typed_data';

import 'package:noosphere/event_wire.dart' as event_wire;
import 'package:noosphere/noosphere.dart' as protocol;
import 'package:noosphere/domain.dart';

export 'package:noosphere/iroh.dart' show noosphereIrohWireVersion;

extension SessionStartedDomainValues on protocol.SessionStarted {
  SessionID get domainSessionId =>
      SessionID.fromBytes(Uint8List.fromList(sessionId));
}

protocol.EventMessage encodeEvent(Event event) => event_wire.encodeEvent(event);

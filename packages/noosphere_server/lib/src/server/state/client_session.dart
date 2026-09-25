import 'dart:async';

import 'package:noosphere/domain.dart';

import 'ring_buffer.dart';

class ClientSession implements Expirable {
  ClientSession({
    required this.participantId,
    required this.sessionID,
    required this.expiry,
    required void Function() onLostStream,
  }) {
    void flushEvents() {
      for (final event in eventBuffer.flushBuffer()) {
        eventController.add(event);
      }
    }

    eventController = StreamController<Event>(
      onListen: flushEvents,
      onResume: flushEvents,
      onCancel: onLostStream,
    );
  }

  final Identifier participantId;
  final SessionID sessionID;
  @override
  Expiry expiry;
  late final StreamController<Event> eventController;
  final eventBuffer = RingBuffer<Event>(100);
  bool _ended = false;

  void sendEvent(Event event) {
    if (_ended || eventController.isClosed) return;
    if (eventController.isPaused) {
      eventBuffer.add(event);
    } else {
      eventController.add(event);
    }
  }

  bool end() {
    if (_ended) return false;
    _ended = true;
    if (!eventController.isClosed) eventController.close();
    return true;
  }
}

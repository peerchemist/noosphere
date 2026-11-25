import 'dart:async';

import 'package:noosphere_protocol/domain.dart';

import 'ring_buffer.dart';

class ClientSession implements Expirable {
  ClientSession({
    required this.participantId,
    required this.sessionID,
    required this.expiry,
    required FutureOr<void> Function() onLostStream,
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
  SigningSnapshotEvent? _pendingSigningSnapshot;

  // The in-process API has no transport write to wait for.
  Stream<Event> get events => eventController.stream.map((event) {
    finishEvent(event);
    return event;
  });

  void enqueueSigningSnapshot(SigningSnapshotEvent Function() capture) {
    if (_ended || eventController.isClosed) throw InvalidRequest.noSession();
    if (_pendingSigningSnapshot != null) {
      throw InvalidRequest('A signing snapshot is already queued');
    }
    final snapshot = capture();
    _pendingSigningSnapshot = snapshot;
    sendEvent(snapshot);
  }

  void finishEvent(Event? event) {
    if (identical(event, _pendingSigningSnapshot)) {
      _pendingSigningSnapshot = null;
    }
  }

  void sendEvent(Event event) {
    if (_ended || eventController.isClosed) return;
    if (eventController.isPaused) {
      finishEvent(eventBuffer.add(event));
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

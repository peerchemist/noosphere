import 'dart:async';
import 'dart:typed_data';

import 'package:noosphere/wire.dart';
import 'package:noosphere/domain.dart';

import '../server/api_handler.dart';
import 'connection_context.dart';

final class UnknownIrohGroupException implements Exception {
  const UnknownIrohGroupException();

  @override
  String toString() => 'UnknownIrohGroupException';
}

final class ConnectionGroupMismatchException implements Exception {
  const ConnectionGroupMismatchException();

  @override
  String toString() => 'ConnectionGroupMismatchException';
}

/// A state transition result plus messages that may be written afterwards.
final class IrohDispatchResult<T> {
  IrohDispatchResult(this.value, {Iterable<Envelope> outgoing = const []})
    : outgoing = List.unmodifiable(outgoing);

  final T value;
  final List<Envelope> outgoing;
}

/// Serializes state mutations independently for each configured group.
///
/// Callbacks may invoke [ServerApiHandler] methods but must not perform network
/// reads or writes. [invokeAndSend] deliberately runs its send callback only
/// after the group's lane has been released.
final class IrohDispatcher {
  IrohDispatcher(Iterable<ServerApiHandler> handlers) {
    for (final handler in handlers) {
      addHandler(handler);
    }
    if (_lanes.isEmpty) throw ArgumentError('at least one group is required');
  }

  factory IrohDispatcher.single(ServerApiHandler handler) =>
      IrohDispatcher([handler]);

  final Map<_GroupKey, _GroupLane> _lanes = {};
  bool _closed = false;

  /// Adds a newly frozen enrollment room to the ordinary ROAST dispatcher.
  void addHandler(ServerApiHandler handler) {
    if (_closed) throw StateError('dispatcher is closed');
    final key = _GroupKey(handler.config.group.fingerprint);
    if (_lanes.containsKey(key)) {
      throw ArgumentError('duplicate Iroh group fingerprint');
    }
    _lanes[key] = _GroupLane(handler);
  }

  Future<void> removeHandler(List<int> groupFingerprint) async {
    if (_closed) throw StateError('dispatcher is closed');
    final lane = _lanes.remove(_GroupKey(groupFingerprint));
    if (lane != null) await lane.queue.close();
  }

  int pendingFor(List<int> groupFingerprint) =>
      _lanes[_GroupKey(groupFingerprint)]?.queue.pending ?? 0;

  bool hasGroup(List<int> groupFingerprint) =>
      !_closed && _lanes.containsKey(_GroupKey(groupFingerprint));

  Future<ExpirableAuthChallengeResponse> beginAuthentication({
    required List<int> groupFingerprint,
    required Identifier participantId,
    required ConnectionContext connection,
    int protocolVersion = ServerApiHandler.currentProtocolVersion,
  }) async {
    if (connection.phase != IrohConnectionPhase.connected) {
      throw StateError('connection already started authentication');
    }
    final result = await invoke(
      groupFingerprint: groupFingerprint,
      connection: connection,
      operation: (handler, connection) async {
        final challenge = await handler.login(
          groupFingerprint: Uint8List.fromList(groupFingerprint),
          participantId: participantId,
          protocolVersion: protocolVersion,
        );
        connection.issueChallenge(
          challenge: challenge.challenge,
          groupFingerprint: groupFingerprint,
          participantId: participantId,
        );
        return IrohDispatchResult(challenge);
      },
    );
    return result.value;
  }

  Future<void> completeAuthentication({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
    required Signed<AuthChallenge> signedChallenge,
  }) => schedule(
    groupFingerprint: groupFingerprint,
    connection: connection,
    mutation: (handler, connection) async {
      if (!connection.acceptsChallenge(signedChallenge.obj)) {
        throw InvalidRequest.noChallenge();
      }
      final participant = await handler.verifyChallenge(signedChallenge);
      if (participant != connection.pendingParticipantId) {
        throw StateError('challenge participant changed');
      }
      connection.authenticate();
    },
  );

  Future<SessionStarted> startSession({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
  }) async {
    if (connection.phase != IrohConnectionPhase.authenticated) {
      throw StateError('connection is not authenticated');
    }
    final result = await invoke(
      groupFingerprint: groupFingerprint,
      connection: connection,
      operation: (handler, connection) async {
        final participant = connection.participantId;
        if (participant == null) {
          throw StateError('authenticated connection has no participant');
        }
        final response = await handler.startSession(participant);
        connection.attachSession(response.id);
        return IrohDispatchResult(
          SessionStarted(
            sessionId: response.id.toBytes(),
            snapshot: response.toBytes(),
          ),
        );
      },
    );
    return result.value;
  }

  /// Completes snapshot initialization and exposes queued/live session events.
  Future<Stream<Envelope>> ready({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
  }) async {
    final result = await invoke(
      groupFingerprint: groupFingerprint,
      connection: connection,
      operation: (handler, connection) {
        if (connection.phase != IrohConnectionPhase.sessionAttached) {
          throw StateError('connection has no session awaiting Ready');
        }
        final sessionId = connection.sessionId;
        if (sessionId == null) {
          throw StateError('connection has incomplete session state');
        }
        final session = handler.getSession(sessionId);
        connection.markReady();
        return IrohDispatchResult(
          session.eventController.stream.map(
            (event) => Envelope(
              wireVersion: noosphereIrohWireVersion,
              event: encodeEvent(event),
            ),
          ),
        );
      },
    );
    return result.value;
  }

  /// Runs a domain request only after the snapshot handshake is ready.
  Future<IrohDispatchResult<T>> invokeReady<T>({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
    required FutureOr<IrohDispatchResult<T>> Function(
      ServerApiHandler handler,
      ConnectionContext connection,
    )
    operation,
  }) => invoke(
    groupFingerprint: groupFingerprint,
    connection: connection,
    operation: (handler, connection) {
      if (connection.phase != IrohConnectionPhase.ready) {
        throw StateError('connection is not ready for domain requests');
      }
      return operation(handler, connection);
    },
  );

  Future<void> disconnect({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
  }) => logout(groupFingerprint: groupFingerprint, connection: connection);

  Future<void> logout({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
  }) async {
    if (connection.isClosed) return;
    final sessionId = connection.sessionId;
    if (sessionId != null) {
      await scheduleGroup(
        groupFingerprint: groupFingerprint,
        mutation: (handler) async {
          final session = handler.sessionForTransport(sessionId);
          if (session != null &&
              session.participantId == connection.participantId) {
            await handler.endSessionForTransport(session);
          }
        },
      );
    }
    connection.close();
  }

  Future<IrohDispatchResult<T>> invoke<T>({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
    required FutureOr<IrohDispatchResult<T>> Function(
      ServerApiHandler handler,
      ConnectionContext connection,
    )
    operation,
  }) {
    if (_closed) return Future.error(StateError('dispatcher is closed'));
    connection.ensureOpen();

    final key = _GroupKey(groupFingerprint);
    final lane = _lanes[key];
    if (lane == null) return Future.error(const UnknownIrohGroupException());
    if (connection.hasGroupBinding && !connection.belongsToGroup(key.bytes)) {
      return Future.error(const ConnectionGroupMismatchException());
    }

    return lane.queue.run(() {
      connection.ensureOpen();
      if (connection.hasGroupBinding && !connection.belongsToGroup(key.bytes)) {
        throw const ConnectionGroupMismatchException();
      }
      return operation(lane.handler, connection);
    });
  }

  Future<T> invokeAndSend<T>({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
    required FutureOr<IrohDispatchResult<T>> Function(
      ServerApiHandler handler,
      ConnectionContext connection,
    )
    operation,
    required Future<void> Function(List<Envelope> outgoing) send,
  }) async {
    final result = await invoke(
      groupFingerprint: groupFingerprint,
      connection: connection,
      operation: operation,
    );

    // The group's serial lane has been released before network backpressure is
    // observed here.
    if (result.outgoing.isNotEmpty) await send(result.outgoing);
    return result.value;
  }

  Future<void> schedule({
    required List<int> groupFingerprint,
    required ConnectionContext connection,
    required FutureOr<void> Function(
      ServerApiHandler handler,
      ConnectionContext connection,
    )
    mutation,
  }) async {
    await invoke<void>(
      groupFingerprint: groupFingerprint,
      connection: connection,
      operation: (handler, context) async {
        await mutation(handler, context);
        return IrohDispatchResult(null);
      },
    );
  }

  Future<void> scheduleGroup({
    required List<int> groupFingerprint,
    required FutureOr<void> Function(ServerApiHandler handler) mutation,
  }) => invokeGroup(groupFingerprint: groupFingerprint, operation: mutation);

  Future<T> invokeGroup<T>({
    required List<int> groupFingerprint,
    required FutureOr<T> Function(ServerApiHandler handler) operation,
  }) {
    if (_closed) return Future.error(StateError('dispatcher is closed'));
    final lane = _lanes[_GroupKey(groupFingerprint)];
    if (lane == null) return Future.error(const UnknownIrohGroupException());
    return lane.queue.run(() => operation(lane.handler));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(_lanes.values.map((lane) => lane.queue.close()));
  }
}

final class _GroupLane {
  _GroupLane(this.handler);

  final ServerApiHandler handler;
  final _SerialQueue queue = _SerialQueue();
}

final class _GroupKey {
  _GroupKey(List<int> bytes) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;

  @override
  bool operator ==(Object other) {
    if (other is! _GroupKey || other.bytes.length != bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != other.bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(bytes);
}

final Object _activeQueueZoneKey = Object();

final class _QueueZoneState {
  _QueueZoneState(this.queue);

  final _SerialQueue queue;
  bool active = true;
}

final class _SerialQueue {
  Future<void> _tail = Future.value();
  bool _accepting = true;
  int _pending = 0;

  int get pending => _pending;

  Future<T> run<T>(FutureOr<T> Function() operation) {
    if (!_accepting) return Future.error(StateError('serial queue is closed'));
    final currentZone = Zone.current[_activeQueueZoneKey];
    if (currentZone is _QueueZoneState &&
        identical(currentZone.queue, this) &&
        currentZone.active) {
      return Future.error(StateError('reentrant dispatch would deadlock'));
    }

    final completer = Completer<T>();
    final zoneState = _QueueZoneState(this);
    _pending++;
    _tail = _tail.then((_) async {
      try {
        final value = await runZoned(
          () async => operation(),
          zoneValues: {_activeQueueZoneKey: zoneState},
        );
        completer.complete(value);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        zoneState.active = false;
        _pending--;
      }
    });
    return completer.future;
  }

  Future<void> close() {
    _accepting = false;
    return _tail;
  }
}

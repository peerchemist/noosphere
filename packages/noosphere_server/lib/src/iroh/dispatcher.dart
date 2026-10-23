import 'dart:async';
import 'dart:typed_data';

import 'package:noosphere_protocol/domain.dart';
import 'package:noosphere_protocol/public_feed.dart';
import 'package:noosphere_protocol/wire.dart'
    hide PublicFeedPage, PublicFeedEntry;

import '../server/api_handler.dart';
import '../server/state/client_session.dart';
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

final class IrohDispatchResult<T>(final T value);

/// Serializes state mutations independently for each configured group.
///
/// Callbacks may invoke [ServerApiHandler] methods but must not perform network
/// reads or writes.
final class IrohDispatcher {
  IrohDispatcher(Iterable<ServerApiHandler> handlers, {this.onError}) {
    try {
      for (final handler in handlers) {
        addHandler(handler);
      }
    } catch (_) {
      for (final lane in _lanes.values) {
        lane.maintenance?.cancel();
        lane.handler.detachSessionLostHandler();
      }
      rethrow;
    }
    if (_lanes.isEmpty) throw ArgumentError('at least one group is required');
  }

  factory IrohDispatcher.single(
    ServerApiHandler handler, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) => IrohDispatcher([handler], onError: onError);

  final Map<_GroupKey, _GroupLane> _lanes = {};
  final void Function(Object error, StackTrace stackTrace)? onError;
  bool _closed = false;

  /// Adds a newly frozen enrollment room to the ordinary ROAST dispatcher.
  void addHandler(ServerApiHandler handler) {
    if (_closed) throw StateError('dispatcher is closed');
    final key = _GroupKey(handler.config.group.fingerprint);
    if (_lanes.containsKey(key)) {
      throw ArgumentError('duplicate Iroh group fingerprint');
    }
    final feedId = handler.config.publicFeed?.feedId;
    if (feedId != null &&
        _lanes.values.any(
          (lane) => lane.handler.config.publicFeed?.feedId == feedId,
        )) {
      throw ArgumentError('duplicate public feed ID');
    }
    final lane = _GroupLane(handler);
    handler.attachSessionLostHandler(
      (session) => _endLostSession(lane, session),
    );
    _lanes[key] = lane;
    lane.maintenance = Timer.periodic(const Duration(seconds: 1), (_) {
      // Busy protocol calls already expire state through _prepare. Avoid
      // accumulating maintenance jobs behind slow host persistence.
      if (_closed || lane.queue.pending != 0) return;
      unawaited(
        lane.queue.run(handler.maintainPublicFeed).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          // Handler fails closed on an uncertain durable write. Reads will
          // refuse to publish that state; the host must restart the handler.
          _reportError(error, stackTrace);
        }),
      );
    });
  }

  Future<void> _endLostSession(_GroupLane lane, ClientSession session) {
    Future<void> endSession() async {
      if (!identical(
        lane.handler.sessionForTransport(session.sessionID),
        session,
      )) {
        return;
      }
      await lane.handler.endSessionForTransport(session);
    }

    final ending = lane.queue.isCurrent
        ? endSession()
        : lane.queue.run(endSession);
    return ending.catchError(_reportError);
  }

  void _reportError(Object error, StackTrace stackTrace) =>
      onError?.call(error, stackTrace);

  Future<void> removeHandler(List<int> groupFingerprint) async {
    if (_closed) throw StateError('dispatcher is closed');
    final lane = _lanes.remove(_GroupKey(groupFingerprint));
    if (lane != null) {
      lane.maintenance?.cancel();
      await lane.queue.close();
      lane.handler.detachSessionLostHandler();
    }
  }

  /// Routes by opaque feed ID only; never binds a participant connection.
  Future<PublicFeedPage?> getPublicFeed(
    PublicFeedId feedId,
    int afterCursor,
    int limit,
  ) {
    if (_closed) return Future.error(StateError('dispatcher is closed'));
    for (final lane in _lanes.values) {
      if (lane.handler.config.publicFeed?.feedId == feedId) {
        // The handler reads an immutable committed view. Pollers neither wait
        // behind host writes nor occupy the participant mutation lane.
        return lane.handler.getPublicFeed(feedId, afterCursor, limit);
      }
    }
    return Future.value(null);
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
  Future<Stream<EventMessage>> ready({
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
          session.eventController.stream.map(encodeEvent),
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
    for (final lane in _lanes.values) {
      lane.maintenance?.cancel();
    }
    await Future.wait(_lanes.values.map((lane) => lane.queue.close()));
    for (final lane in _lanes.values) {
      lane.handler.detachSessionLostHandler();
    }
  }
}

final class _GroupLane {
  _GroupLane(this.handler);

  final ServerApiHandler handler;
  final _SerialQueue queue = _SerialQueue();
  Timer? maintenance;
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
  bool get isCurrent {
    final currentZone = Zone.current[_activeQueueZoneKey];
    return currentZone is _QueueZoneState &&
        identical(currentZone.queue, this) &&
        currentZone.active;
  }

  Future<T> run<T>(FutureOr<T> Function() operation) {
    if (!_accepting) return Future.error(StateError('serial queue is closed'));
    if (isCurrent) {
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

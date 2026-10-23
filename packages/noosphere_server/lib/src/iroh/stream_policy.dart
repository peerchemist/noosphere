import 'dart:async';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/wire.dart';

/// Shared admission, lifetime, and cleanup policy for accepted QUIC streams.
final class IrohStreamPolicy({
  required final Connection connection,
  required final void Function(Object, StackTrace) onError,
  required final Duration timeout,
  required final int maxConcurrent,
  final Duration? idleTimeout,
}) {
  final Set<Future<void>> _active = {};
  Timer? _idleDeadline;
  bool _accepting = true;

  void startIdleDeadline() => _armIdleDeadline();

  Future<void> admit({
    required SendStream send,
    required RecvStream receive,
    required Future<void> Function() handle,
  }) async {
    if (!_accepting || _active.length >= maxConcurrent) {
      await _quietly(() => send.reset(1));
      await _quietly(() => receive.stop(1));
      return;
    }

    _idleDeadline?.cancel();
    late final Future<void> handling;
    handling = Future<void>.sync(handle)
        .catchError((Object error, StackTrace stackTrace) {
          connection.close(reason: 'internal stream failure'.codeUnits);
          onError(error, stackTrace);
        })
        .whenComplete(() {
          _active.remove(handling);
          _armIdleDeadline();
        });
    _active.add(handling);
  }

  Future<void> finishStream({
    required SendStream send,
    required RecvStream receive,
    required QuicStreamReader reader,
    required bool requestReceived,
  }) async {
    await _quietly(send.finish);
    await _quietly(() => receive.stop(requestReceived ? 0 : 1));
    await _quietly(reader.cancel);
  }

  Future<void> drain() async {
    _accepting = false;
    _idleDeadline?.cancel();
    await Future.wait(_active.toList(), eagerError: false);
  }

  void _armIdleDeadline() {
    if (!_accepting || _active.isNotEmpty || idleTimeout == null) return;
    _idleDeadline = Timer(idleTimeout!, () {
      connection.close(reason: 'idle connection deadline exceeded'.codeUnits);
    });
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action().timeout(timeout);
    } on TimeoutException {
      connection.close(reason: 'stream cleanup deadline exceeded'.codeUnits);
    } on Exception {
      // The peer may already have closed or reset the stream.
    }
  }
}

bool isIrohRequestError(Object error) =>
    error is Exception || error is ArgumentError;

ProtocolErrorCode commonIrohProtocolErrorCode(Object error) => switch (error) {
  FrameTooLargeException() =>
    ProtocolErrorCode.PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
  TimeoutException() => ProtocolErrorCode.PROTOCOL_ERROR_DEADLINE_EXCEEDED,
  _ => ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
};

Stream<List<int>> readIrohChunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(64 * 1024);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

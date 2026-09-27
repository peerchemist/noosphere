part of '../worker_runtime.dart';

final class _HostBridge {
  _HostBridge(
    this.port,
    this.generation,
    this.maxMessageBytes,
    this.maxOutstandingRequests,
  );

  final SendPort port;
  final int generation;
  final int maxMessageBytes;
  final int maxOutstandingRequests;
  final _pending = <int, Completer<Object?>>{};
  int _nextId = 1;
  bool _closed = false;

  Future<Object?> request(
    String setupId,
    String operation,
    Map<String, Object?> payload,
  ) {
    if (_closed) throw StateError('Host bridge is closed.');
    if (_pending.length >= maxOutstandingRequests) {
      throw StateError('Too many host requests are outstanding.');
    }
    final id = _nextId++;
    final message = <String, Object?>{
      'version': workerProtocolVersion,
      'generation': generation,
      'type': 'hostRequest',
      'hostRequestId': id,
      'setupId': setupId,
      'operation': operation,
      'payload': payload,
    };
    if (approximateMessageBytes(message) > maxMessageBytes) {
      throw StateError('Host request exceeds worker message limit.');
    }
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send(message);
    return completer.future;
  }

  void complete(Map<Object?, Object?> message) {
    final id = message['hostRequestId'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (message['ok'] == true) {
      completer.complete(message['result']);
    } else {
      completer.completeError(
        NoosphereWorkerException(
          message['code'] as String? ?? 'host_failure',
          message['message'] as String? ?? 'Host operation failed.',
        ),
      );
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final completer in _pending.values) {
      completer.completeError(
        const NoosphereWorkerException(
          'worker_closing',
          'Worker closed during a host operation.',
        ),
      );
    }
    _pending.clear();
  }
}

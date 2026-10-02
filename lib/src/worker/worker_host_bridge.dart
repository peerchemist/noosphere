part of '../worker_runtime.dart';

final class _HostBridge implements WorkerHost {
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

  @override
  Future<Object?> request(
    String setupId,
    ProviderOperation operation,
    Map<String, Object?> payload,
  ) {
    if (_closed) throw StateError('Host bridge is closed.');
    if (_pending.length >= maxOutstandingRequests) {
      throw StateError('Too many host requests are outstanding.');
    }
    final id = _nextId++;
    final message = ProviderRequest(
      generation,
      id,
      setupId,
      operation,
      payload,
    );
    if (approximateMessageBytes(message) > maxMessageBytes) {
      throw StateError('Host request exceeds worker message limit.');
    }
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send(message);
    return completer.future;
  }

  void complete(ProviderReply message) {
    final completer = _pending.remove(message.id);
    if (completer == null) return;
    if (message.failure case final failure?) {
      completer.completeError(failure);
    } else {
      completer.complete(message.result);
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

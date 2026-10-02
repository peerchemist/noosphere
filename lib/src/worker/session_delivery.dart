import 'dart:async';

/// Establishes a snapshot before delivering any event from a new session,
/// including streams which emit immediately from listen(). Old-session events
/// and errors are ignored as soon as replacement or cancellation starts.
final class SessionDelivery<T> {
  StreamSubscription<T>? _subscription;
  int _revision = 0;

  Future<void> attach(
    Stream<T> stream, {
    required void Function() snapshot,
    required void Function(T) event,
    required void Function(Object) error,
    void Function()? replaced,
  }) async {
    final revision = ++_revision;
    await _subscription?.cancel();
    if (revision != _revision) return;
    final pending = <void Function()>[];
    var ready = false;
    void deliver(void Function() action) {
      if (revision != _revision) return;
      if (ready) {
        action();
      } else {
        pending.add(action);
      }
    }

    _subscription = stream.listen(
      (value) => deliver(() => event(value)),
      onError: (Object failure) => deliver(() => error(failure)),
    );
    snapshot();
    replaced?.call();
    ready = true;
    for (final action in pending) {
      if (revision == _revision) action();
    }
  }

  Future<void> cancel() async {
    _revision++;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'worker.dart';

/// Optional terminal-lifecycle bridge for [NoosphereWorker].
///
/// Window focus changes do not stop the worker. Explicit logout should call
/// [NoosphereWorker.stopSetup], and application shutdown should await
/// [NoosphereWorker.close].
final class NoosphereWorkerLifecycleObserver(
  final NoosphereWorker worker, {
  final Duration closeTimeout = const Duration(seconds: 5),
  final void Function(Object error, StackTrace stackTrace)? onCloseError,
}) extends WidgetsBindingObserver {
  bool _attached = false;
  Future<void>? _terminalClose;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(
        _terminalClose ??= worker.close().timeout(closeTimeout).onError((
          error,
          stackTrace,
        ) {
          if (error != null) onCloseError?.call(error, stackTrace);
        }),
      );
    }
  }
}

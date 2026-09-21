import 'dart:async';

import 'package:flutter/widgets.dart';

import 'node.dart';

/// Optional bridge from terminal Flutter lifecycle events to a bounded close.
///
/// Losing focus (`inactive`) deliberately does nothing. Applications should
/// still call [NoosphereNode.close] explicitly during logout and shutdown.
final class NoosphereLifecycleObserver(
  final NoosphereNode node, {
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
        _terminalClose ??= node.close().timeout(closeTimeout).onError((
          error,
          stackTrace,
        ) {
          if (error != null) onCloseError?.call(error, stackTrace);
        }),
      );
    }
  }
}

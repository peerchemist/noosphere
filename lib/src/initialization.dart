import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib_flutter;
import 'package:flutter/widgets.dart';
import 'package:frosty_flutter/frosty_flutter.dart' as frosty_flutter;
import 'package:iroh_flutter/iroh_flutter.dart' as iroh_flutter;
import 'package:meta/meta.dart';

/// Initializes every native runtime used by Noosphere.
///
/// Concurrent callers receive the same in-flight future. A failed future is
/// retained so later callers observe the original failure instead of racing a
/// second native initialization attempt.
abstract final class NoosphereFlutter {
  static Future<void>? _initialization;
  static Future<void> Function() _initializer = _initializePlugins;

  @RecordUse()
  static Future<void> initialize() =>
      _initialization ??= Future<void>.sync(_initializer);

  static Future<void> _initializePlugins() async {
    WidgetsFlutterBinding.ensureInitialized();
    await coinlib_flutter.loadCoinlib();
    await iroh_flutter.Iroh.init();
    await frosty_flutter.loadFrosty();
  }

  @visibleForTesting
  static void debugResetInitialization({Future<void> Function()? initializer}) {
    _initialization = null;
    _initializer = initializer ?? _initializePlugins;
  }
}

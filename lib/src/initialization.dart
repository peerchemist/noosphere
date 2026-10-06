import 'dart:io';

import 'package:coinlib/coinlib.dart' as coinlib;
import 'package:flutter/widgets.dart';
import 'package:frosty/frosty.dart' as frosty;
// ignore: implementation_imports
import 'package:frosty/src/rust_bindings/generated/frb_generated.dart'
    show RustLib;
import 'package:iroh_flutter/iroh_flutter.dart' as iroh_flutter;
import 'package:meta/meta.dart';

/// Initializes every native runtime used by Noosphere.
///
/// Concurrent callers receive the same in-flight future. A failed future is
/// retained so later callers observe the original failure instead of racing a
/// second native initialization attempt.
abstract final class NoosphereFlutter {
  static Future<void>? _initialization;
  static Future<void>? _rootPreparation;
  static Future<void>? _nativeInitialization;
  static Future<void> Function() _rootPreparer = _prepareRoot;
  static Future<void> Function() _nativeInitializer = _initializeNative;

  /// Prepares the root Flutter isolate and initializes native bindings there.
  ///
  /// Worker isolates use [initializeNative] instead, because Flutter bindings
  /// may only be prepared by the root isolate. Host code that creates native
  /// Frosty values can call this method before using those values.
  @RecordUse()
  static Future<void> initialize() => _initialization ??= _initializeAll();

  static Future<void> _initializeAll() async {
    await prepareRootIsolate();
    await initializeNative();
  }

  /// Performs Flutter-only root isolate preparation without loading native
  /// libraries. This is safe to call before spawning [NoosphereWorker].
  static Future<void> prepareRootIsolate() =>
      _rootPreparation ??= Future<void>.sync(_rootPreparer);

  /// Initializes Noosphere's native bindings in the calling isolate.
  ///
  /// Native binding state is isolate-local even when the underlying dynamic
  /// libraries and Rust runtimes are process-wide.
  @RecordUse()
  static Future<void> initializeNative() =>
      _nativeInitialization ??= Future<void>.sync(_nativeInitializer);

  static Future<void> _prepareRoot() async {
    WidgetsFlutterBinding.ensureInitialized();
  }

  static Future<void> _initializeNative() async {
    await coinlib.loadCoinlib();
    await iroh_flutter.Iroh.init(libraryPath: _irohMacOsFrameworkPath());
    await _loadFrosty();
  }

  static Future<void> _loadFrosty() async {
    try {
      await frosty.loadFrosty();
    } on UnsupportedError catch (error) {
      // Frosty's native-assets branch probes Isolate.packageConfigSync to find
      // libraries for standalone Dart. Flutter isolates do not support that
      // API, but FRB's normal loader resolves the bundled native asset.
      if (error.message != 'Isolate.packageConfig') rethrow;
      await RustLib.init();
    }
  }

  // Iroh and Frosty both use flutter_rust_bridge and therefore export a few
  // identically named runtime symbols. Looking them up in the macOS process
  // can resolve Frosty's symbols while initialising Iroh. Opening Iroh's
  // framework explicitly gives dart:ffi a library-scoped symbol namespace.
  static String? _irohMacOsFrameworkPath() {
    if (!Platform.isMacOS) return null;

    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final framework = File(
      '${executableDirectory.parent.path}/Frameworks/'
      'iroh_flutter.framework/iroh_flutter',
    );
    return framework.existsSync() ? framework.path : null;
  }

  @visibleForTesting
  static void debugResetInitialization({
    Future<void> Function()? initializer,
    Future<void> Function()? rootPreparer,
    Future<void> Function()? nativeInitializer,
  }) {
    _initialization = null;
    _rootPreparation = null;
    _nativeInitialization = null;
    _rootPreparer = rootPreparer ?? initializer ?? _prepareRoot;
    _nativeInitializer =
        nativeInitializer ??
        (initializer == null ? _initializeNative : () async {});
  }
}

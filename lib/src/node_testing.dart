import 'package:noosphere_roast_server/noosphere_roast_server.dart';

/// Internal seam used by lifecycle unit tests. This library is not exported by
/// `package:noosphere_flutter/noosphere_flutter.dart`.
abstract interface class NoosphereNodeBackend {
  Future<NoosphereServerRole> startServer();

  Future<NoosphereClientRole> startClient();
}

abstract interface class NoosphereServerRole {
  IrohServer? get server;

  Future<void> close();

  Future<void> waitForServe();
}

abstract interface class NoosphereClientRole {
  ReconnectingIrohClient? get client;

  Future<void> close();
}

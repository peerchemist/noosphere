import 'package:noosphere_flutter/noosphere_flutter.dart';

/// The demo depends on session operations, not a concrete isolate implementation.
abstract interface class DemoWorker {
  Stream<NoosphereWorkerEvent> get events;
  bool get isClosed;
  Future<NoosphereWorkerSnapshot> startSetup({
    required String setupId,
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  });
  Future<NoosphereWorkerSnapshot> snapshot(String setupId);
  Future<void> requestDkg(String setupId, NewDkgDetails proposal);
  Future<void> acceptDkg(String setupId, WorkerDkgStatus proposal);
  Future<void> requestSignatures(
    String setupId,
    SignaturesRequestDetails proposal,
  );
  Future<void> acceptSignatures(String setupId, WorkerSigningRequest proposal);
  Future<void> close();
}

Future<DemoWorker> startDemoWorker() async =>
    _DemoWorker(await NoosphereWorker.start());

final class _DemoWorker(this.worker) implements DemoWorker {
  final NoosphereWorker worker;
  @override
  Stream<NoosphereWorkerEvent> get events => worker.events;
  @override
  bool get isClosed => worker.isClosed;
  @override
  Future<NoosphereWorkerSnapshot> startSetup({
    required String setupId,
    EmbeddedServerOptions? server,
    ClientNodeOptions? client,
  }) => worker.startSetup(setupId: setupId, server: server, client: client);
  @override
  Future<NoosphereWorkerSnapshot> snapshot(String setupId) =>
      worker.snapshot(setupId);
  @override
  Future<void> requestDkg(String setupId, NewDkgDetails proposal) =>
      worker.requestDkg(setupId, proposal);
  @override
  Future<void> acceptDkg(String setupId, WorkerDkgStatus proposal) =>
      worker.acceptDkg(setupId, proposal);
  @override
  Future<void> requestSignatures(
    String setupId,
    SignaturesRequestDetails proposal,
  ) => worker.requestSignatures(setupId, proposal);
  @override
  Future<void> acceptSignatures(
    String setupId,
    WorkerSigningRequest proposal,
  ) => worker.acceptSignatures(setupId, proposal);
  @override
  Future<void> close() => worker.close();
}

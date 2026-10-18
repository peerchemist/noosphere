import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/src/worker/dto_mapper.dart';
import 'package:noosphere_flutter/src/worker/message_size.dart';
import 'package:noosphere_flutter/src/worker/messages.dart';
import 'package:noosphere_flutter/src/worker/worker_host_setup.dart';
import 'package:noosphere_flutter/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('host cancellation operation persists the minimal tombstone and its snapshot DTO', () async {
    final storage = InMemoryClientStorage();
    final host = HostSetup()..storage = storage;
    final id = SignaturesRequestId.fromBytes(Uint8List(16)..last = 7);
    final expiry = Expiry(const Duration(minutes: 2));
    await storage.addRejectedSigsRequest(id, FinalExpirable(expiry));
    await host.dispatch(ProviderOperation.cancelSignaturesRequest, {
      'id': id.toBytes(),
      'expiryMicros': expiry.time.microsecondsSinceEpoch,
    });
    final snapshot =
        (await host.dispatch(ProviderOperation.loadState, const {}))! as Map;
    expect(snapshot['rejected'], isEmpty);
    expect(snapshot['nonces'], isEmpty);
    expect(snapshot['prepared'], isEmpty);
    expect(snapshot['cancelled'], [
      CancelledSignaturesRequest(id, expiry).toBytes(),
    ]);
    await host.dispatch(ProviderOperation.cancelSignaturesRequest, {
      'id': id.toBytes(),
      'expiryMicros': expiry.time.microsecondsSinceEpoch,
    });
    expect(storage.cancelledRequests, hasLength(1));
    storage.cancelledRequests[id] = CancelledSignaturesRequest(
      id,
      Expiry(const Duration(seconds: -1)),
    );
    await host.dispatch(
      ProviderOperation.pruneCancelledSignaturesRequests,
      const {},
    );
    expect(storage.cancelledRequests, isEmpty);
  });

  test('cancelled client event maps to a dedicated sendable worker event', () {
    final id = SignaturesRequestId.fromBytes(Uint8List(16)..last = 1);
    final expiry = Expiry(const Duration(minutes: 2));
    final events = <NoosphereWorkerEvent>[];
    WorkerDtoMapper(
      'signer',
      42,
      events.add,
    ).event(SignaturesCancelledClientEvent(requestId: id, expiresAt: expiry));
    final event = events.single as WorkerSignaturesCancelledEvent;
    expect(event.setupId, 'signer');
    expect(event.generation, 42);
    expect(event.requestId, id.toBytes());
    expect(event.expiresAt, expiry.time);
    expect(
      approximateMessageBytes(WorkerEventMessage(42, event)),
      greaterThan(16),
    );
    expect(() => event.requestId[0] = 1, throwsUnsupportedError);
    final snapshot = NoosphereWorkerSnapshot(
      setupId: 'signer',
      generation: 42,
      serverRunning: false,
      signerRunning: true,
      connected: true,
      coordinator: null,
      onlineParticipants: [],
      dkgs: [],
      signingRequests: [],
      keys: [],
      cancelledRequests: [
        WorkerCancelledSignaturesRequest(
          requestId: event.requestId,
          expiresAt: event.expiresAt,
        ),
      ],
    );
    expect(approximateMessageBytes(snapshot), greaterThan(24));
  });
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/src/iroh_node.dart';
import 'package:noosphere_flutter/src/lifecycle.dart';
import 'package:noosphere_flutter/src/node_testing.dart';
import 'package:noosphere_flutter/src/server_identity_store.dart';

void main() {
  test('rejects an empty role set', () {
    expect(
      () => NoosphereNode.startForTesting(
        server: false,
        client: false,
        backend: _Backend(<String>[]),
      ),
      throwsArgumentError,
    );
  });

  test('server-only starts, closes, then joins serve', () async {
    final events = <String>[];
    final node = await NoosphereNode.startForTesting(
      server: true,
      client: false,
      backend: _Backend(events),
    );

    expect(events, ['start server']);
    await node.close();
    expect(events, ['start server', 'close server', 'join serve']);
  });

  test(
    'serve failure updates health before close and is safe to observe',
    () async {
      final events = <String>[];
      final role = _ServerRole(events);
      final node = await NoosphereNode.startForTesting(
        server: true,
        client: false,
        backend: _Backend(events, serverRole: role),
      );
      expect(node.serverRunning, isTrue);
      final failure = StateError('serve failed');
      role.done.completeError(failure);
      final termination = await node.serverDone!;
      expect(termination.error, same(failure));
      expect(node.serverRunning, isFalse);
      expect(events, ['start server']);
      await expectLater(node.close(), throwsA(same(failure)));
      expect(events, ['start server', 'close server']);
    },
  );

  test(
    'normal serve completion is observable independently of close',
    () async {
      final events = <String>[];
      final role = _ServerRole(events);
      final node = await NoosphereNode.startForTesting(
        server: true,
        client: false,
        backend: _Backend(events, serverRole: role),
      );
      role.done.complete();
      expect((await node.serverDone!).error, isNull);
      expect(node.serverRunning, isFalse);
      await node.close();
    },
  );

  test('client-only starts and closes', () async {
    final events = <String>[];
    final node = await NoosphereNode.startForTesting(
      server: false,
      client: true,
      backend: _Backend(events),
    );

    expect(events, ['start client']);
    await node.close();
    expect(events, ['start client', 'close client']);
  });

  test('client-only node rejects server identity export', () async {
    final node = await NoosphereNode.startForTesting(
      server: false,
      client: true,
      backend: _Backend(<String>[]),
    );
    addTearDown(node.close);

    await expectLater(
      node.exportIrohServerIdentity(),
      throwsA(isA<StateError>()),
    );
  });

  test('server node exports its identity defensively', () async {
    final bytes = Uint8List(32)..last = 17;
    final store = _MemoryIdentityStore(bytes);
    final node = await NoosphereNode.startForTesting(
      server: true,
      client: false,
      backend: _Backend(<String>[]),
      identityStore: store,
    );
    addTearDown(node.close);

    final first = await node.exportIrohServerIdentity();
    first.last = 99;
    final second = await node.exportIrohServerIdentity();

    expect(second, orderedEquals(bytes));
  });

  test('both starts server first and closes client first', () async {
    final events = <String>[];
    final node = await NoosphereNode.startForTesting(
      server: true,
      client: true,
      backend: _Backend(events),
    );

    expect(events, ['start server', 'start client']);
    await node.close();
    expect(events, [
      'start server',
      'start client',
      'close client',
      'close server',
      'join serve',
    ]);
  });

  test(
    'partial startup failure cleans the server and preserves failure',
    () async {
      final events = <String>[];
      final failure = StateError('client start failed');
      final backend = _Backend(events, clientFailure: failure);

      await expectLater(
        NoosphereNode.startForTesting(
          server: true,
          client: true,
          backend: backend,
        ),
        throwsA(same(failure)),
      );
      expect(events, [
        'start server',
        'start client',
        'close server',
        'join serve',
      ]);
    },
  );

  test('concurrent close calls share one future and one shutdown', () async {
    final events = <String>[];
    final barrier = Completer<void>();
    final backend = _Backend(events, clientCloseBarrier: barrier);
    final node = await NoosphereNode.startForTesting(
      server: true,
      client: true,
      backend: backend,
    );

    final first = node.close();
    final second = node.close();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(events.where((event) => event == 'close client'), hasLength(1));

    barrier.complete();
    await Future.wait([first, second]);
    expect(events.where((event) => event == 'close server'), hasLength(1));
    expect(events.where((event) => event == 'join serve'), hasLength(1));
  });

  test('lifecycle ignores inactive and closes on detached', () async {
    final events = <String>[];
    final node = await NoosphereNode.startForTesting(
      server: true,
      client: false,
      backend: _Backend(events),
    );
    final observer = NoosphereLifecycleObserver(node);

    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(events, ['start server']);

    observer.didChangeAppLifecycleState(AppLifecycleState.detached);
    await Future<void>.delayed(Duration.zero);
    expect(events, ['start server', 'close server', 'join serve']);
  });
}

final class _Backend(
  this.events, {
  this.clientFailure,
  this.clientCloseBarrier,
  this.serverRole,
}) implements NoosphereNodeBackend {
  final List<String> events;
  final Object? clientFailure;
  final _ServerRole? serverRole;
  final Completer<void>? clientCloseBarrier;

  @override
  Future<NoosphereServerRole> startServer() async {
    events.add('start server');
    return serverRole ?? _ServerRole(events);
  }

  @override
  Future<NoosphereClientRole> startClient() async {
    events.add('start client');
    if (clientFailure case final failure?) throw failure;
    return _ClientRole(events, clientCloseBarrier);
  }
}

final class _ServerRole(this.events) implements NoosphereServerRole {
  final List<String> events;
  final done = Completer<void>();

  @override
  Never get server => throw UnsupportedError('fake server');

  @override
  Future<void> close() async {
    events.add('close server');
    if (!done.isCompleted) done.complete();
  }

  @override
  Future<void> waitForServe() async {
    await done.future;
    events.add('join serve');
  }
}

final class _ClientRole(this.events, this.closeBarrier)
    implements NoosphereClientRole {
  final List<String> events;
  final Completer<void>? closeBarrier;

  @override
  Never get client => throw UnsupportedError('fake client');

  @override
  Future<void> close() async {
    events.add('close client');
    await closeBarrier?.future;
  }
}

final class _MemoryIdentityStore(Uint8List initial)
    implements ServerIdentityStore {
  final Uint8List _bytes = Uint8List.fromList(initial);

  @override
  Future<Uint8List?> read() async => Uint8List.fromList(_bytes);

  @override
  Future<void> write(Uint8List secret) async {
    _bytes.setAll(0, secret);
  }
}

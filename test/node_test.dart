import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/src/lifecycle.dart';
import 'package:noosphere_flutter/src/node.dart';
import 'package:noosphere_flutter/src/node_testing.dart';

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

final class _Backend(this.events, {this.clientFailure, this.clientCloseBarrier})
    implements NoosphereNodeBackend {
  final List<String> events;
  final Object? clientFailure;
  final Completer<void>? clientCloseBarrier;

  @override
  Future<NoosphereServerRole> startServer() async {
    events.add('start server');
    return _ServerRole(events);
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

  @override
  Never get server => throw UnsupportedError('fake server');

  @override
  Future<void> close() async => events.add('close server');

  @override
  Future<void> waitForServe() async => events.add('join serve');
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

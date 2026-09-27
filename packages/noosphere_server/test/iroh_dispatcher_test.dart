@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/noosphere.dart';
import 'package:noosphere_server/noosphere_server.dart';
import 'package:noosphere_server/src/iroh/connection_context.dart';
import 'package:noosphere_server/src/iroh/dispatcher.dart';
import 'package:test/test.dart';

import 'data.dart';

void main() {
  setUpAll(() async {
    await loadFrosty();
    await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);
  });

  ConnectionContext connection([int id = 1]) => ConnectionContext(
    connectionId: id,
    remoteEndpointId: SecretKey.generate().publicKey,
  );

  test('serializes concurrent mutations for the same group', () async {
    final dispatcher = IrohDispatcher.single(getApiHandler());
    addTearDown(dispatcher.close);
    final gate = Completer<void>();
    final order = <String>[];
    var active = 0;
    var maximumActive = 0;

    Future<IrohDispatchResult<int>> operation(int id) async {
      active++;
      maximumActive = active > maximumActive ? active : maximumActive;
      order.add('start$id');
      if (id == 1) await gate.future;
      order.add('end$id');
      active--;
      return IrohDispatchResult(id);
    }

    final first = dispatcher.invoke(
      groupFingerprint: groupConfig.fingerprint,
      connection: connection(),
      operation: (_, _) => operation(1),
    );
    final second = dispatcher.invoke(
      groupFingerprint: groupConfig.fingerprint,
      connection: connection(2),
      operation: (_, _) => operation(2),
    );
    await pumpEventQueue();

    expect(order, ['start1']);
    expect(dispatcher.pendingFor(groupConfig.fingerprint), 2);
    gate.complete();

    expect((await first).value, 1);
    expect((await second).value, 2);
    expect(order, ['start1', 'end1', 'start2', 'end2']);
    expect(maximumActive, 1);
  });

  test('different groups execute independently', () async {
    final secondGroup = GroupConfig(
      id: 'SecondGroup',
      participants: groupConfig.participants,
    );
    final dispatcher = IrohDispatcher([
      getApiHandler(),
      ServerApiHandler(
        config: ServerConfig(group: secondGroup),
        persistence: newServerPersistence(),
      ),
    ]);
    addTearDown(dispatcher.close);
    final gate = Completer<void>();
    final firstStarted = Completer<void>();

    final first = dispatcher.invoke(
      groupFingerprint: groupConfig.fingerprint,
      connection: connection(),
      operation: (_, _) async {
        firstStarted.complete();
        await gate.future;
        return IrohDispatchResult(1);
      },
    );
    await firstStarted.future;

    final second = await dispatcher.invoke(
      groupFingerprint: secondGroup.fingerprint,
      connection: connection(2),
      operation: (_, _) => IrohDispatchResult(2),
    );

    expect(second.value, 2);
    gate.complete();
    expect((await first).value, 1);
  });

  test('slow network writer does not retain the group lane', () async {
    final dispatcher = IrohDispatcher.single(getApiHandler());
    addTearDown(dispatcher.close);
    final writeStarted = Completer<void>();
    final releaseWriter = Completer<void>();

    final first = dispatcher.invokeAndSend(
      groupFingerprint: groupConfig.fingerprint,
      connection: connection(),
      operation: (_, _) => IrohDispatchResult(
        1,
        outgoing: [Envelope(wireVersion: 1, ready: Ready())],
      ),
      send: (_) {
        writeStarted.complete();
        return releaseWriter.future;
      },
    );
    await writeStarted.future;

    final second = await dispatcher.invoke(
      groupFingerprint: groupConfig.fingerprint,
      connection: connection(2),
      operation: (_, _) => IrohDispatchResult(2),
    );

    expect(second.value, 2);
    releaseWriter.complete();
    expect(await first, 1);
  });

  test('an operation error does not poison later mutations', () async {
    final dispatcher = IrohDispatcher.single(getApiHandler());
    addTearDown(dispatcher.close);

    await expectLater(
      dispatcher.invoke<void>(
        groupFingerprint: groupConfig.fingerprint,
        connection: connection(),
        operation: (_, _) => throw StateError('expected'),
      ),
      throwsStateError,
    );

    final next = await dispatcher.invoke(
      groupFingerprint: groupConfig.fingerprint,
      connection: connection(2),
      operation: (_, _) => IrohDispatchResult(2),
    );
    expect(next.value, 2);
  });

  test('scheduled callbacks use the same serial lane', () async {
    final dispatcher = IrohDispatcher.single(getApiHandler());
    addTearDown(dispatcher.close);
    final gate = Completer<void>();
    final order = <String>[];
    final context = connection();

    final request = dispatcher.invoke(
      groupFingerprint: groupConfig.fingerprint,
      connection: context,
      operation: (_, _) async {
        order.add('request-start');
        await gate.future;
        order.add('request-end');
        return IrohDispatchResult(null);
      },
    );
    final callback = dispatcher.schedule(
      groupFingerprint: groupConfig.fingerprint,
      connection: context,
      mutation: (_, _) => order.add('callback'),
    );
    await pumpEventQueue();
    expect(order, ['request-start']);

    gate.complete();
    await Future.wait([request, callback]);
    expect(order, ['request-start', 'request-end', 'callback']);
  });

  test('connection context enforces phase and group binding', () async {
    final secondGroup = GroupConfig(
      id: 'SecondGroup',
      participants: groupConfig.participants,
    );
    final dispatcher = IrohDispatcher([
      getApiHandler(),
      ServerApiHandler(
        config: ServerConfig(group: secondGroup),
        persistence: newServerPersistence(),
      ),
    ]);
    addTearDown(dispatcher.close);
    final context = connection();
    final participant = ids.first;
    late SessionID session;

    await dispatcher.schedule(
      groupFingerprint: groupConfig.fingerprint,
      connection: context,
      mutation: (handler, connection) async {
        connection.issueChallenge(
          challenge: AuthChallenge(),
          groupFingerprint: groupConfig.fingerprint,
          participantId: participant,
        );
        connection.authenticate();
        final response = await handler.startSession(participant);
        session = response.id;
        connection.attachSession(session);
        connection.markReady();
      },
    );

    expect(context.phase, IrohConnectionPhase.ready);
    expect(context.participantId, participant);
    expect(context.sessionId, session);

    await expectLater(
      dispatcher.invoke(
        groupFingerprint: secondGroup.fingerprint,
        connection: context,
        operation: (_, _) => IrohDispatchResult(null),
      ),
      throwsA(isA<ConnectionGroupMismatchException>()),
    );
  });
}

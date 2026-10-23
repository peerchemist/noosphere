@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/wire.dart';
import 'package:noosphere_server/src/iroh/stream_policy.dart';
import 'package:test/test.dart';

const _alpn = 'noosphere/stream-policy-test/1';

void main() {
  setUpAll(
    () => Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']),
  );

  test('classifies request errors and common protocol codes', () {
    expect(isIrohRequestError(const FormatException()), isTrue);
    expect(isIrohRequestError(ArgumentError()), isTrue);
    expect(isIrohRequestError(StateError('internal')), isFalse);

    expect(
      commonIrohProtocolErrorCode(
        const FrameTooLargeException(length: 2, maximum: 1),
      ),
      ProtocolErrorCode.PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
    );
    expect(
      commonIrohProtocolErrorCode(TimeoutException('late')),
      ProtocolErrorCode.PROTOCOL_ERROR_DEADLINE_EXCEEDED,
    );
    expect(
      commonIrohProtocolErrorCode(const FormatException()),
      ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
    );
  });

  test('reads chunks and finishes both stream halves', () async {
    final (server, client) = await _connections();
    final ((serverSend, serverReceive), (clientSend, clientReceive)) =
        await _stream(server, client, [1, 2, 3]);
    await clientSend.finish();
    final policy = _policy(server);
    final reader = QuicStreamReader(readIrohChunks(serverReceive));

    expect(await reader.readToEnd(), [1, 2, 3]);
    await policy.finishStream(
      send: serverSend,
      receive: serverReceive,
      reader: reader,
      requestReceived: true,
    );

    expect(await clientReceive.read(1), isNull);
    await policy.drain();
  });

  test('rejects streams above the concurrent admission limit', () async {
    final (server, client) = await _connections();
    final policy = _policy(server, maxConcurrent: 1);
    final release = Completer<void>();
    final entered = Completer<void>();

    final ((firstSend, firstReceive), _) = await _stream(server, client, [1]);
    final firstReader = QuicStreamReader(readIrohChunks(firstReceive));
    await policy.admit(
      send: firstSend,
      receive: firstReceive,
      handle: () async {
        entered.complete();
        await release.future;
        await policy.finishStream(
          send: firstSend,
          receive: firstReceive,
          reader: firstReader,
          requestReceived: false,
        );
      },
    );
    await entered.future;

    var rejectedHandlerRan = false;
    final ((secondSend, secondReceive), (_, secondClientReceive)) =
        await _stream(server, client, [2]);
    await policy.admit(
      send: secondSend,
      receive: secondReceive,
      handle: () async {
        rejectedHandlerRan = true;
      },
    );

    expect(rejectedHandlerRan, isFalse);
    await expectLater(
      secondClientReceive.read(1),
      throwsA(isA<IrohStreamException>()),
    );
    release.complete();
    await policy.drain();
  });

  test('reports task failures and closes the connection', () async {
    final (server, client) = await _connections();
    final reported = Completer<Object>();
    final policy = _policy(
      server,
      onError: (error, _) => reported.complete(error),
    );
    final ((send, receive), _) = await _stream(server, client, [1]);

    await policy.admit(
      send: send,
      receive: receive,
      handle: () async => throw StateError('task failed'),
    );

    expect(await reported.future, isA<StateError>());
    expect(
      await client.closed().timeout(const Duration(seconds: 1)),
      contains('internal stream failure'),
    );
    await policy.drain();
  });

  test('idle deadline pauses for active work and rearms afterwards', () async {
    final (server, client) = await _connections();
    const idleTimeout = Duration(milliseconds: 100);
    final policy = _policy(server, idleTimeout: idleTimeout);
    final release = Completer<void>();
    final entered = Completer<void>();
    final ((send, receive), _) = await _stream(server, client, [1]);
    final reader = QuicStreamReader(readIrohChunks(receive));
    var closed = false;
    unawaited(client.closed().then((_) => closed = true));

    policy.startIdleDeadline();
    await policy.admit(
      send: send,
      receive: receive,
      handle: () async {
        entered.complete();
        await release.future;
        await policy.finishStream(
          send: send,
          receive: receive,
          reader: reader,
          requestReceived: false,
        );
      },
    );
    await entered.future;
    await Future<void>.delayed(idleTimeout * 2);
    expect(closed, isFalse);

    release.complete();
    expect(
      await client.closed().timeout(const Duration(seconds: 1)),
      contains('idle connection deadline exceeded'),
    );
    await policy.drain();
  });
}

IrohStreamPolicy _policy(
  Connection connection, {
  int maxConcurrent = 2,
  Duration? idleTimeout,
  void Function(Object, StackTrace)? onError,
}) => IrohStreamPolicy(
  connection: connection,
  onError: onError ?? (_, _) {},
  timeout: const Duration(seconds: 1),
  maxConcurrent: maxConcurrent,
  idleTimeout: idleTimeout,
);

Future<(Connection, Connection)> _connections() async {
  final serverEndpoint = await Endpoint.bind(
    alpns: [_alpn.codeUnits],
    relayMode: RelayMode.disabled,
  );
  final clientEndpoint = await Endpoint.bind(relayMode: RelayMode.disabled);
  addTearDown(serverEndpoint.close);
  addTearDown(clientEndpoint.close);
  final accepted = serverEndpoint.accept();
  final client = await clientEndpoint.connect(
    _address(serverEndpoint),
    _alpn.codeUnits,
  );
  final server = (await accepted)!;
  addTearDown(client.close);
  addTearDown(server.close);
  return (server, client);
}

Future<((SendStream, RecvStream), (SendStream, RecvStream))> _stream(
  Connection server,
  Connection client,
  List<int> request,
) async {
  final accepted = server.acceptBi();
  final clientStream = await client.openBi();
  await clientStream.$1.writeAll(request);
  return ((await accepted), clientStream);
}

EndpointAddr _address(Endpoint endpoint) => EndpointAddr(
  endpoint.id,
  ipAddrs: endpoint.boundSockets.map((address) {
    final split = address.lastIndexOf(':');
    return address.startsWith('[')
        ? '[::1]${address.substring(split)}'
        : '127.0.0.1${address.substring(split)}';
  }).toList(),
);

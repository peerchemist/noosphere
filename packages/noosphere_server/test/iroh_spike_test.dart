@TestOn('vm')
@Timeout(Duration(seconds: 90))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(
    () => Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']),
  );

  test('endpoint close releases a blocked accept', () async {
    final endpoint = await Endpoint.bind(relayMode: RelayMode.disabled);
    final accepted = endpoint.accept();
    await endpoint.close();
    expect(await accepted.timeout(const Duration(seconds: 5)), isNull);
  });

  test('endpoint close releases a blocked stream read', () async {
    const alpn = 'noosphere/roast/1';
    final server = await Endpoint.bind(
      alpns: [alpn.codeUnits],
      relayMode: RelayMode.disabled,
    );
    final client = await Endpoint.bind(relayMode: RelayMode.disabled);
    addTearDown(client.close);

    final serverAddress = EndpointAddr(
      server.id,
      ipAddrs: _loopbackAddresses(server.boundSockets),
    );
    final accepted = server.accept();
    final clientConnection = await client.connect(
      serverAddress,
      alpn.codeUnits,
    );
    final (clientSend, _) = await clientConnection.openBi();
    await clientSend.writeAll(Uint8List.fromList(const <int>[1]));

    final serverConnection = await accepted;
    final (_, serverReceive) = await serverConnection!.acceptBi();
    final blockedRead = serverReceive.readExact(2);
    final readExpectation = expectLater(
      blockedRead.timeout(const Duration(seconds: 5)),
      throwsA(isA<IrohStreamException>()),
    );
    await server.close();
    await readExpectation;
  });

  test('persisted secret keeps the same endpoint id', () async {
    final temporary = await Directory.systemTemp.createTemp('iroh-identity-');
    addTearDown(() => temporary.delete(recursive: true));
    final secretPath = '${temporary.path}/secret.key';

    final first = await _run(<String>['identity', secretPath]);
    final second = await _run(<String>['identity', secretPath]);

    expect(first.exitCode, 0, reason: first.stderr as String);
    expect(second.exitCode, 0, reason: second.stderr as String);
    expect(first.stdout, second.stdout);
  });

  test(
    'two Dart processes exchange framed protobuf messages directly',
    () async {
      await _testTwoProcesses('direct');
    },
  );

  test(
    'two Dart processes exchange framed protobuf messages through a relay',
    () async => _testTwoProcesses('relay'),
    skip: Platform.environment['IROH_SPIKE_RELAY'] == '1'
        ? false
        : 'set IROH_SPIKE_RELAY=1 to exercise the public relay',
  );
}

Future<void> _testTwoProcesses(String transport) async {
  final temporary = await Directory.systemTemp.createTemp('iroh-spike-');
  addTearDown(() => temporary.delete(recursive: true));

  final process = await Process.start(Platform.resolvedExecutable, <String>[
    'run',
    'tool/iroh_spike.dart',
    'server',
    '${temporary.path}/secret.key',
    transport,
  ], workingDirectory: Directory.current.path);
  addTearDown(() => process.kill());

  final ready = Completer<String>();
  final serverStdout = StringBuffer();
  final serverStderr = StringBuffer();
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      serverStdout.writeln(line);
      if (line.startsWith('IROH_SPIKE_READY ') && !ready.isCompleted) {
        ready.complete(line);
      }
    },
  );
  process.stderr.transform(utf8.decoder).listen(serverStderr.write);

  final readyParts = (await ready.future.timeout(const Duration(seconds: 40)))
      .split(' ');
  final client = await _run(<String>['client', readyParts[1], transport]);
  final serverExit = await process.exitCode.timeout(
    const Duration(seconds: 40),
  );

  expect(client.exitCode, 0, reason: client.stderr as String);
  expect(client.stdout, contains('IROH_SPIKE_OK ${readyParts[2]}'));
  expect(serverExit, 0, reason: '$serverStdout\n$serverStderr');
  expect(serverStdout.toString(), contains('IROH_SPIKE_SERVED'));
}

Future<ProcessResult> _run(List<String> arguments) => Process.run(
  Platform.resolvedExecutable,
  <String>['run', 'tool/iroh_spike.dart', ...arguments],
  workingDirectory: Directory.current.path,
);

List<String> _loopbackAddresses(List<String> boundAddresses) {
  return boundAddresses.map((address) {
    final separator = address.lastIndexOf(':');
    final host = address.substring(0, separator);
    final port = address.substring(separator + 1);
    return host.startsWith('[') || host.contains(':')
        ? '[::1]:$port'
        : '127.0.0.1:$port';
  }).toList();
}

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/src/worker/session_delivery.dart';
import 'package:noosphere_flutter/src/worker_protocol.dart';

void main() {
  for (final operation in WorkerOperation.values) {
    test(
      'command $operation survives isolate transfer with owned fields',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final command = WorkerCommand(
          7,
          11,
          operation,
          setupId: 'test',
          payload: {
            'proposal': bytes,
            'id': Uint8List(16),
            'name': 'name',
            'roles': 2,
            'server': null,
            'client': null,
            'address': {
              'id': Uint8List(32),
              'relayUrls': <String>[],
              'ipAddrs': <String>[],
            },
          },
        );
        bytes[0] = 99;
        final copy = await Isolate.run(() => command);
        expect(copy.operation, operation);
        expect(copy.id, 11);
        expect(copy.generation, 7);
        expect(copy.setupId, 'test');
        expect(copy.fields.bytes('proposal'), [1, 2, 3]);
        expect(
          () => copy.fields.bytes('proposal')[0] = 4,
          throwsUnsupportedError,
        );
        expect(approximateMessageBytes(copy), approximateMessageBytes(command));
      },
    );
  }
  for (final operation in ProviderOperation.values) {
    test(
      'provider $operation and both reply outcomes survive transfer',
      () async {
        final request = ProviderRequest(9, 13, 'test', operation, {
          'state': Uint8List(17),
          'nonces': {'values': <Object?>[], 'expiryMicros': 12},
        });
        final copy = await Isolate.run(() => request);
        expect(copy.operation, operation);
        expect(copy.fields.values, request.fields.values);
        final success = ProviderReply.success(9, 13, {'state': Uint8List(17)});
        final failure = ProviderReply.failure(
          9,
          13,
          const NoosphereWorkerException(
            'host_timeout',
            'Durable outcome unknown.',
          ),
        );
        final copies = await Isolate.run(() => [success, failure]);
        expect(copies.first.result, success.result);
        expect(copies.last.failure!.code, 'host_timeout');
        expect(copies.last.result, isNull);
        expect(approximateMessageBytes(copies.last), greaterThan(80));
      },
    );
  }
  test(
    'all reply/control/event variants cross without native objects',
    () async {
      final port = ReceivePort();
      addTearDown(port.close);
      final messages = <WorkerMessage>[
        WorkerReady(2, port.sendPort),
        WorkerStartupFailure(
          2,
          const NoosphereWorkerException('startup_failed', 'Failed.'),
        ),
        WorkerReply.success(2, 1, Uint8List(4)),
        WorkerReply.failure(
          2,
          2,
          const NoosphereWorkerException('start_result_too_large', 'Started.'),
        ),
        WorkerEventMessage(
          2,
          WorkerFailureEvent(
            'test',
            2,
            operation: 'serve',
            message: 'Stopped.',
          ),
        ),
      ];
      final copies = await Isolate.run(() => messages);
      expect(
        copies.map((v) => v.runtimeType),
        messages.map((v) => v.runtimeType),
      );
      for (var i = 0; i < copies.length; i++) {
        expect(copies[i].generation, 2);
        expect(
          approximateMessageBytes(copies[i]),
          approximateMessageBytes(messages[i]),
        );
      }
    },
  );
  test('native/arbitrary payloads and mistyped fields are rejected', () {
    expect(() => MessageFields({'native': Object()}), throwsFormatException);
    expect(
      () => MessageFields({
        'nested': {1: 'bad'},
      }),
      throwsFormatException,
    );
    expect(
      () => MessageFields({'roles': 'both'}).integer('roles'),
      throwsFormatException,
    );
    expect(() => MessageFields({}).bytes('proposal'), throwsFormatException);
    expect(MessageFields({}).optional<String>('missing'), isNull);
  });
  test(
    'large nested byte fields are accounted for in commands and replies',
    () {
      final bytes = Uint8List(8192);
      expect(
        approximateMessageBytes(
          WorkerCommand(
            1,
            1,
            WorkerOperation.requestDkg,
            payload: {'proposal': bytes},
          ),
        ),
        greaterThan(8192),
      );
      expect(
        approximateMessageBytes(ProviderReply.success(1, 1, {'bytes': bytes})),
        greaterThan(8192),
      );
    },
  );
  test(
    'replacement snapshot precedes even immediate events and errors',
    () async {
      final events = <String>[];
      final delivery = SessionDelivery<String>();
      final first = StreamController<String>(sync: true);
      final second = StreamController<String>(sync: true);
      addTearDown(first.close);
      addTearDown(second.close);
      addTearDown(delivery.cancel);
      await delivery.attach(
        first.stream,
        snapshot: () => events.add('first snapshot'),
        event: events.add,
        error: (_) => events.add('old error'),
      );
      await delivery.attach(
        second.stream,
        snapshot: () {
          events.add('second snapshot');
          second.add('new event');
          second.addError(StateError('new error'));
        },
        event: events.add,
        error: (_) => events.add('new error'),
        replaced: () => events.add('replaced'),
      );
      first.add('stale event');
      expect(events, [
        'first snapshot',
        'second snapshot',
        'replaced',
        'new event',
        'new error',
      ]);
    },
  );
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'room records survive worker restart and stay isolated by setup',
    () async {
      final firstStore = InMemoryRoomPersistence();
      final secondStore = InMemoryRoomPersistence();
      final first = await NoosphereWorker.startForTesting(
        roomPersistences: {'first': firstStore, 'second': secondStore},
      );
      addTearDown(first.close);
      await first.debugWriteRoomForTesting(
        'first',
        'room',
        Uint8List.fromList([1, 2]),
      );
      await first.debugWriteRoomForTesting(
        'second',
        'room',
        Uint8List.fromList([3, 4]),
      );
      final records = await first.debugLoadRoomsForTesting('first');
      records['room']![0] = 99;
      expect((await firstStore.loadAll())['room'], [1, 2]);
      expect((await first.debugLoadRoomsForTesting('second'))['room'], [3, 4]);
      await first.close();

      final replacement = await NoosphereWorker.startForTesting(
        roomPersistences: {'first': firstStore},
      );
      addTearDown(replacement.close);
      expect((await replacement.debugLoadRoomsForTesting('first'))['room'], [
        1,
        2,
      ]);
    },
  );

  test(
    'room write waits for durable host completion and serializes reads',
    () async {
      final store = _DelayedRooms();
      final worker = await NoosphereWorker.startForTesting(
        roomPersistences: {'setup': store},
      );
      addTearDown(worker.close);
      var acknowledged = false;
      final write = worker
          .debugWriteRoomForTesting('setup', 'room', Uint8List.fromList([5]))
          .then((_) => acknowledged = true);
      await store.called.future;
      final read = worker.debugLoadRoomsForTesting('setup');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(acknowledged, isFalse);
      expect(store.loads, 0);
      store.release.complete();
      await write;
      expect((await read)['room'], [5]);
    },
  );

  test(
    'room provider failures are propagated without private details',
    () async {
      final store = _DelayedRooms();
      final worker = await NoosphereWorker.startForTesting(
        roomPersistences: {'setup': store},
      );
      addTearDown(worker.close);
      final failure = expectLater(
        worker.debugWriteRoomForTesting('setup', 'room', Uint8List(0)),
        throwsA(
          isA<NoosphereWorkerException>()
              .having((error) => error.code, 'code', 'host_state')
              .having(
                (error) => error.message,
                'message',
                isNot(contains('secret detail')),
              ),
        ),
      );
      await store.called.future;
      store.release.completeError(StateError('secret detail'));
      await failure;
      expect(await store.loadAll(), isEmpty);
    },
  );

  test(
    'timeout blocks new writes and a replacement waits for the old commit',
    () async {
      final store = _DelayedRooms();
      final worker = await NoosphereWorker.startForTesting(
        roomPersistences: {'setup': store},
        hostOperationTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(worker.close);
      await expectLater(
        worker.debugWriteRoomForTesting(
          'setup',
          'room',
          Uint8List.fromList([7]),
        ),
        throwsA(
          isA<NoosphereWorkerException>().having(
            (error) => error.code,
            'code',
            'host_timeout',
          ),
        ),
      );
      await expectLater(
        worker.debugWriteRoomForTesting(
          'setup',
          'room',
          Uint8List.fromList([8]),
        ),
        throwsA(
          isA<NoosphereWorkerException>().having(
            (error) => error.code,
            'code',
            'invalid_state',
          ),
        ),
      );
      await worker.close();
      final replacement = await NoosphereWorker.startForTesting(
        roomPersistences: {'setup': store},
      );
      addTearDown(replacement.close);
      final loaded = replacement.debugLoadRoomsForTesting('setup');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.loads, 0);
      store.release.complete();
      expect((await loaded)['room'], [7]);
      await replacement.debugWriteRoomForTesting(
        'setup',
        'room',
        Uint8List.fromList([9]),
      );
      expect((await replacement.debugLoadRoomsForTesting('setup'))['room'], [
        9,
      ]);
    },
  );

  test('missing room provider fails explicitly', () async {
    final worker = await NoosphereWorker.startForTesting(
      identityStores: {'setup': null},
    );
    addTearDown(worker.close);
    await expectLater(
      worker.debugLoadRoomsForTesting('setup'),
      throwsA(
        isA<NoosphereWorkerException>().having(
          (error) => error.code,
          'code',
          'host_state',
        ),
      ),
    );
  });
}

final class _DelayedRooms implements RoomPersistence {
  final called = Completer<void>();
  final release = Completer<void>();
  final _store = InMemoryRoomPersistence();
  int loads = 0;

  @override
  Future<Map<String, Uint8List>> loadAll() {
    loads++;
    return _store.loadAll();
  }

  @override
  Future<void> write(String roomId, Uint8List state) async {
    if (!called.isCompleted) called.complete();
    await release.future;
    await _store.write(roomId, state);
  }
}

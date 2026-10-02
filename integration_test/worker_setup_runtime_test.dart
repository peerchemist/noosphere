import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';
import 'package:noosphere_flutter/src/worker/node_factory.dart';
import 'package:noosphere_flutter/src/worker/provider_registry.dart';
import 'package:noosphere_flutter/src/worker_protocol.dart';
import 'package:noosphere_flutter/src/worker_runtime.dart';
import 'package:noosphere_flutter/testing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(NoosphereFlutter.initialize);
  late EmbeddedServerOptions options;
  setUp(() {
    final group = GroupConfig(
      id: 'test',
      participants: {
        for (var i = 1; i <= 2; i++)
          Identifier.fromUint16(i): ECCompressedPublicKey.fromPubkey(
            ECPrivateKey(Uint8List(32)..last = i).pubkey,
          ),
      },
    );
    options = EmbeddedServerOptions(
      serverConfig: ServerConfig(group: group),
      identityStore: _Identity(),
      serverPersistence: InMemoryServerPersistence(),
    );
  });
  test(
    'failed stop preserves provider ownership until acknowledged retry',
    () async {
      var stopFails = true;
      final registry = HostProviderRegistry((
        operation, {
        setupId,
        payload = const {},
      }) async {
        if (operation == WorkerOperation.stopRoles && stopFails) {
          throw StateError('cleanup failed');
        }
        return _snapshot();
      });
      await registry.startSetup(setupId: 'test', server: options);
      await expectLater(registry.stopSetup('test'), throwsStateError);
      expect(
        registry.phase('test', NoosphereWorkerRoles.server),
        HostRolePhase.cleanupRequired,
      );
      expect(registry.setup('test').identityStore, same(options.identityStore));
      await expectLater(
        registry.startSetup(setupId: 'test', server: options),
        throwsStateError,
      );
      stopFails = false;
      await registry.stopSetup('test');
      expect(registry.setupIds, isEmpty);
      await registry.startSetup(setupId: 'test', server: options);
    },
  );
  test(
    'incomplete startup cleanup retains providers as an explicit state',
    () async {
      final registry = HostProviderRegistry((
        operation, {
        setupId,
        payload = const {},
      }) async {
        throw const NoosphereWorkerException(
          'startup_cleanup_failed',
          'Cleanup incomplete.',
        );
      });
      await expectLater(
        registry.startSetup(setupId: 'test', server: options),
        throwsA(isA<NoosphereWorkerException>()),
      );
      expect(
        registry.phase('test', NoosphereWorkerRoles.server),
        HostRolePhase.cleanupRequired,
      );
      expect(registry.setup('test').identityStore, same(options.identityStore));
    },
  );
  test(
    'node factory failure rolls back only roles added by that startup',
    () async {
      final node = _Node();
      var starts = 0;
      final runtime = WorkerSetupRuntime(
        setupId: 'test',
        generation: 1,
        host: _Host(),
        emit: (_) {},
        nodeFactory: ({server, client}) async {
          starts++;
          if (starts == 2) throw StateError('signer start failed');
          return node;
        },
      );
      final client = ClientNodeOptions(
        clientConfig: ClientConfig(
          group: options.serverConfig.group,
          id: options.serverConfig.group.participants.keys.first,
        ),
        bootstrapAddress: EndpointAddr(PublicKey.fromHex('58${'66' * 31}')),
        pinnedServerId: PublicKey.fromHex('58${'66' * 31}'),
        storage: InMemoryClientStorage(),
        getPrivateKey: (_) async => ECPrivateKey(Uint8List(32)..last = 1),
      );
      await expectLater(
        runtime.start(server: options, client: client),
        throwsStateError,
      );
      expect(node.closes, 1);
      expect(runtime.hasRoles, isFalse);
      await runtime.close();
    },
  );
  test('failed role cleanup keeps the node reachable for retry', () async {
    final node = _Node()..failClose = true;
    final runtime = WorkerSetupRuntime(
      setupId: 'test',
      generation: 1,
      host: _Host(),
      emit: (_) {},
      nodeFactory: ({server, client}) async => node,
    );
    await runtime.start(server: options, client: null);
    await expectLater(
      runtime.stopRoles(NoosphereWorkerRoles.server),
      throwsStateError,
    );
    expect(runtime.hasRoles, isTrue);
    node.failClose = false;
    await runtime.stopRoles(NoosphereWorkerRoles.server);
    expect(runtime.hasRoles, isFalse);
  });
  test(
    'replacement sessions emit snapshot before replacement and later events',
    () async {
      final first = _Client();
      final connection = _Connection(first);
      final node = _Node(connection: connection);
      final events = <NoosphereWorkerEvent>[];
      final runtime = WorkerSetupRuntime(
        setupId: 'test',
        generation: 1,
        host: _Host(),
        emit: events.add,
        nodeFactory: ({server, client}) async => node,
      );
      final publicKey = PublicKey.fromHex('58${'66' * 31}');
      final config = ClientNodeOptions(
        clientConfig: ClientConfig(
          group: options.serverConfig.group,
          id: options.serverConfig.group.participants.keys.first,
        ),
        bootstrapAddress: EndpointAddr(publicKey),
        pinnedServerId: publicKey,
        storage: InMemoryClientStorage(),
        getPrivateKey: (_) async => ECPrivateKey(Uint8List(32)..last = 1),
      );
      await runtime.start(server: null, client: config);
      events.clear();
      final replacement = _Client();
      connection.updates.add(replacement);
      await Future<void>.delayed(Duration.zero);
      expect(events[0], isA<WorkerSnapshotEvent>());
      expect(events[1], isA<WorkerSessionReplacedEvent>());
      connection.updates.add(_BrokenClient());
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isA<WorkerFailureEvent>());
      connection.updates.addError(StateError('reconnect failed'));
      await Future<void>.delayed(Duration.zero);
      expect(
        events.last,
        isA<WorkerFailureEvent>().having(
          (e) => e.operation,
          'operation',
          'reconnect',
        ),
      );
      await runtime.close();
      await first.controller.close();
      await replacement.controller.close();
      await connection.updates.close();
    },
  );
}

NoosphereWorkerSnapshot _snapshot() => NoosphereWorkerSnapshot(
  setupId: 'test',
  generation: 1,
  serverRunning: true,
  signerRunning: false,
  connected: false,
  coordinator: null,
  onlineParticipants: [],
  dkgs: [],
  signingRequests: [],
  keys: [],
);

final class _Identity implements ServerIdentityStore {
  @override
  Future<Uint8List?> read() async => Uint8List(32);
  @override
  Future<void> write(Uint8List secret) async {}
}

final class _Host implements WorkerHost {
  @override
  Future<Object?> request(
    String setupId,
    ProviderOperation operation,
    Map<String, Object?> payload,
  ) async => null;
}

final class _Node({this.connection}) implements WorkerNode {
  final _Connection? connection;
  final done = Completer<NoosphereServerTermination>();
  int closes = 0;
  bool failClose = false;
  @override
  EndpointAddr? get serverAddress => null;
  @override
  bool get serverRunning => !done.isCompleted;
  @override
  Future<NoosphereServerTermination>? get serverDone => done.future;
  @override
  WorkerClientConnection? get client => connection;
  @override
  Future<void> close() async {
    closes++;
    if (failClose) throw StateError('close failed');
    if (!done.isCompleted) done.complete(const NoosphereServerTermination());
  }

  @override
  Future<void> stopServingForTesting() => close();
}

final class _Connection(this.current) implements WorkerClientConnection {
  @override
  final Client current;
  final updates = StreamController<Client>.broadcast();
  @override
  Stream<Client> get sessions => updates.stream;
  @override
  bool get isConnected => true;
  @override
  void updateTransportConfig(IrohClientTransportConfig config) {}
}

class _Client implements Client {
  final controller = StreamController<ClientEvent>.broadcast();
  @override
  Stream<ClientEvent> get events => controller.stream;
  @override
  Set<Identifier> get onlineParticipants => {};
  @override
  List<DkgInProgress> get dkgRequests => [];
  @override
  List<DkgInProgress> get acceptedDkgs => [];
  @override
  List<SignaturesRequest> get signaturesRequests => [];
  @override
  Map<ECCompressedPublicKey, FrostKeyWithDetails> get keys => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BrokenClient extends _Client {
  @override
  Stream<ClientEvent> get events => throw StateError('Cannot attach session');
}

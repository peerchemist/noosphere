import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enrolls a pubkey-bound 2-of-3 room, runs DKG, and signs', (
    _,
  ) async {
    await NoosphereFlutter.initialize();
    final participantKeys = List.generate(
      3,
      (index) => ECPrivateKey(Uint8List(32)..last = index + 1),
    );
    final bootstrapGroup = GroupConfig(
      id: 'room-bootstrap-only',
      participants: {
        for (var index = 0; index < participantKeys.length; index++)
          Identifier.fromUint16(index + 1): ECCompressedPublicKey.fromPubkey(
            participantKeys[index].pubkey,
          ),
      },
    );
    final serverNode = await NoosphereNode.start(
      server: EmbeddedServerOptions(
        serverConfig: ServerConfig(group: bootstrapGroup),
        identityStore: MemoryIdentityStore(),
        roomPersistence: InMemoryRoomPersistence(),
        relay: IrohRelayConfig.disabled(),
      ),
    );
    final address = await reachableTestAddress(serverNode.server!);
    final rooms = serverNode.server!.rooms!;
    await rooms.createRoom(
      roomId: 'native-room-2-of-3',
      expectedParticipants: 3,
      threshold: 2,
    );
    final invites = <RoomInvite>[];
    for (final key in participantKeys) {
      invites.add(
        await rooms.issueRoomInvite(
          roomId: 'native-room-2-of-3',
          expectedParticipantPublicKey: ECCompressedPublicKey.fromPubkey(
            key.pubkey,
          ),
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );
    }

    final enrollmentApis = <IrohRoomEnrollmentApi>[];
    final clientNodes = <NoosphereNode>[];
    try {
      for (var index = 0; index < participantKeys.length; index++) {
        final api = await IrohRoomEnrollmentApi.connect(
          IrohClientTransportConfig(
            bootstrapAddress: address,
            pinnedServerId: address.id,
            relay: IrohRelayConfig.disabled(),
          ),
        );
        enrollmentApis.add(api);
        if (index == 0) {
          await expectLater(
            RoomEnrollmentClient(api).joinRoom(
              invites[index],
              (_) async => ECPrivateKey(Uint8List(32)..last = 4),
            ),
            throwsArgumentError,
          );
        }
        await RoomEnrollmentClient(api)
            .joinRoom(invites[index], (_) async => participantKeys[index]);
      }

      final frozen = await serverNode.server!.freezeRoom('native-room-2-of-3');
      final group = frozen.groupConfig!;
      expect(frozen.threshold, 2);
      expect(group.participants, hasLength(3));
      expect(frozen.groupFingerprint, orderedEquals(group.fingerprint));

      final stores = List.generate(3, (_) => InMemoryClientStorage());
      for (var index = 0; index < participantKeys.length; index++) {
        final publicKey = ECCompressedPublicKey.fromPubkey(
          participantKeys[index].pubkey,
        );
        final participant = group.participants.entries
            .singleWhere((entry) => entry.value == publicKey)
            .key;
        clientNodes.add(
          await NoosphereNode.start(
            client: nativeTestClientOptions(
              group: group,
              participant: participant,
              key: participantKeys[index],
              address: address,
              storage: stores[index],
            ),
          ),
        );
      }
      final clients = clientNodes.map((node) => node.client!.current).toList();
      final events = clients
          .map((client) => client.events.asBroadcastStream())
          .toList();
      const dkgName = 'enrolled-native-2-of-3';
      final proposals = [
        for (var index = 1; index < 3; index++)
          events[index]
              .where((event) => event is UpdatedDkgClientEvent)
              .cast<UpdatedDkgClientEvent>()
              .firstWhere((event) => event.progress.details.name == dkgName),
      ];
      await clients.first.requestDkg(
        NewDkgDetails(
          name: dkgName,
          description: 'Enrolled native 2-of-3 integration test',
          threshold: 2,
          expiry: Expiry(const Duration(hours: 1)),
        ),
      );
      await Future.wait(proposals).timeout(const Duration(seconds: 15));
      final completedKeys = Future.wait([
        for (final store in stores) store.waitForKeyWithName(dkgName, 3),
      ]);
      await Future.wait([
        clients[1].acceptDkg(dkgName),
        clients[2].acceptDkg(dkgName),
      ]);
      final keys = await completedKeys.timeout(const Duration(minutes: 2));
      expect(keys.map((key) => key.groupKey).toSet(), hasLength(1));

      final message = Uint8List(32)..last = 99;
      final request = SignaturesRequestDetails(
        requiredSigs: [
          SingleSignatureDetails(
            signDetails: SignDetails.scriptSpend(message: message),
            groupKey: keys.first.groupKey,
            hdDerivation: const [],
          ),
        ],
        expiry: Expiry(const Duration(minutes: 3)),
      );
      final secondSawRequest = events[1]
          .where((event) => event is SignaturesRequestClientEvent)
          .cast<SignaturesRequestClientEvent>()
          .firstWhere((event) => event.request.details.id == request.id);
      final completed = [
        for (final stream in events)
          stream
              .where((event) => event is SignaturesCompleteClientEvent)
              .cast<SignaturesCompleteClientEvent>()
              .firstWhere((event) => event.details.id == request.id),
      ];
      await clients.first.requestSignatures(request);
      await secondSawRequest.timeout(const Duration(seconds: 15));
      await clients[1].acceptSignaturesRequest(request.id);
      final results = await Future.wait(completed)
          .timeout(const Duration(minutes: 2));
      for (final result in results) {
        expect(
          result.signatures.single.verify(keys.first.groupKey, message),
          isTrue,
        );
      }
    } finally {
      for (final node in clientNodes.reversed) {
        await node.close();
      }
      for (final api in enrollmentApis.reversed) {
        await api.close();
      }
      await serverNode.close();
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}

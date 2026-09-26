@TestOn('vm')
library;

import 'dart:io';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_client/iroh_transport.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(
    () => Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']),
  );

  test('rejects bootstrap endpoint ID that differs from the pin', () async {
    final local = await Endpoint.bind(relayMode: RelayMode.disabled);
    final server = await Endpoint.bind(relayMode: RelayMode.disabled);
    final other = await Endpoint.bind(relayMode: RelayMode.disabled);
    addTearDown(local.close);
    addTearDown(server.close);
    addTearDown(other.close);

    final wrapper = IrohClientEndpoint.borrowed(local);
    final config = IrohClientTransportConfig(
      bootstrapAddress: EndpointAddr(
        server.id,
        ipAddrs: _loopbackAddresses(server.boundSockets),
      ),
      pinnedServerId: other.id,
      relay: IrohRelayConfig.disabled(),
    );

    await expectLater(
      wrapper.connect(config),
      throwsA(isA<PinnedEndpointMismatchException>()),
    );
  });

  test('connects only to the correctly pinned server', () async {
    final server = await Endpoint.bind(
      alpns: [noosphereIrohAlpn.codeUnits],
      relayMode: RelayMode.disabled,
    );
    final local = await Endpoint.bind(relayMode: RelayMode.disabled);
    addTearDown(server.close);
    addTearDown(local.close);
    final accepted = server.accept();
    final wrapper = IrohClientEndpoint.borrowed(local);
    final config = IrohClientTransportConfig(
      bootstrapAddress: EndpointAddr(
        server.id,
        ipAddrs: _loopbackAddresses(server.boundSockets),
      ),
      pinnedServerId: server.id,
      relay: IrohRelayConfig.disabled(),
    );

    final clientConnection = await wrapper.connect(config);
    final serverConnection = await accepted;
    addTearDown(clientConnection.close);
    addTearDown(serverConnection!.close);

    expect(clientConnection.remoteId, server.id);
    expect(serverConnection.remoteId, local.id);
  });

  test(
    'discovers a correctly pinned server from only its endpoint ID',
    () async {
      final server = await Endpoint.bind(alpns: [noosphereIrohAlpn.codeUnits]);
      final local = await Endpoint.bind();
      addTearDown(server.close);
      addTearDown(local.close);

      await server
          .homeRelayStatus()
          .firstWhere((statuses) => statuses.any((status) => status.connected))
          .timeout(const Duration(seconds: 30));

      final accepted = server.accept();
      final wrapper = IrohClientEndpoint.borrowed(local);
      final clientConnection = await wrapper.connect(
        IrohClientTransportConfig(
          bootstrapAddress: EndpointAddr(server.id),
          pinnedServerId: server.id,
          connectTimeout: const Duration(seconds: 30),
        ),
      );
      final serverConnection = await accepted;
      addTearDown(clientConnection.close);
      addTearDown(serverConnection!.close);

      expect(clientConnection.remoteId, server.id);
      expect(serverConnection.remoteId, local.id);
    },
    skip: Platform.environment['IROH_DISCOVERY_INTEGRATION'] == '1'
        ? false
        : 'set IROH_DISCOVERY_INTEGRATION=1 to use public Iroh discovery',
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'closing a borrowed endpoint leaves the application endpoint open',
    () async {
      final endpoint = await Endpoint.bind(relayMode: RelayMode.disabled);
      addTearDown(endpoint.close);

      final wrapper = IrohClientEndpoint.borrowed(endpoint);
      await wrapper.close();

      expect(wrapper.ownsEndpoint, isFalse);
      expect(endpoint.isClosed, isFalse);
    },
  );

  test('closing an owned endpoint releases it and is idempotent', () async {
    final serverId = SecretKey.generate().publicKey;
    final config = IrohClientTransportConfig(
      bootstrapAddress: EndpointAddr(serverId),
      pinnedServerId: serverId,
      relay: IrohRelayConfig.disabled(),
      nativeLibraryPath: Platform.environment['IROH_NATIVE_LIBRARY'],
    );
    final wrapper = await IrohClientEndpoint.bind(config);

    await Future.wait([wrapper.close(), wrapper.close()]);

    expect(wrapper.ownsEndpoint, isTrue);
    expect(wrapper.endpoint.isClosed, isTrue);
  });
}

List<String> _loopbackAddresses(List<String> boundAddresses) =>
    boundAddresses.map((address) {
      final separator = address.lastIndexOf(':');
      final host = address.substring(0, separator);
      final port = address.substring(separator + 1);
      return host.startsWith('[') || host.contains(':')
          ? '[::1]:$port'
          : '127.0.0.1:$port';
    }).toList();

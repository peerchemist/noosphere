import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/noosphere.dart' as pb;

const _alpn = 'noosphere/roast/1';
const _maxFrameLength = 1024 * 1024;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
  }

  await Iroh.init(libraryPath: Platform.environment['IROH_NATIVE_LIBRARY']);

  switch (args.first) {
    case 'server':
      if (args.length != 3) _usage();
      await _runServer(File(args[1]), _parseTransport(args[2]));
    case 'client':
      if (args.length != 3) _usage();
      await _runClient(args[1], _parseTransport(args[2]));
    case 'identity':
      if (args.length != 2) _usage();
      await _printIdentity(File(args[1]));
    default:
      _usage();
  }
}

Never _usage() {
  stderr.writeln(
    'usage: dart run tool/iroh_spike.dart '
    '<server SECRET direct|relay | client ADDRESS direct|relay | '
    'identity SECRET>',
  );
  exit(64);
}

_Transport _parseTransport(String value) => switch (value) {
  'direct' => _Transport.direct,
  'relay' => _Transport.relay,
  _ => _usage(),
};

Future<void> _runServer(File secretFile, _Transport transport) async {
  final secretKey = await _loadOrCreateSecret(secretFile);
  final endpoint = await Endpoint.bind(
    secretKey: secretKey,
    alpns: [_alpn.codeUnits],
    relayMode: transport.relayMode,
  );

  try {
    final address = await _advertisedAddress(endpoint, transport);
    stdout.writeln(
      'IROH_SPIKE_READY '
      '${base64UrlEncode(address.encode())} ${endpoint.id.toZ32()}',
    );
    await stdout.flush();

    final connection = await endpoint.accept().timeout(
      const Duration(seconds: 30),
    );
    if (connection == null) {
      throw StateError('endpoint closed before accepting a connection');
    }

    final (send, receive) = await connection.acceptBi();
    final request = utf8.decode((await _readFrame(receive)).data);
    if (request != 'request') {
      throw FormatException('unexpected request: $request');
    }

    await _writeFrame(send, 'response');
    await _writeFrame(send, 'event-1');
    await _writeFrame(send, 'event-2');
    await send.finish();
    stdout.writeln('IROH_SPIKE_SERVED ${connection.remoteId.toZ32()}');
  } finally {
    await endpoint.close();
  }
}

Future<void> _runClient(String encodedAddress, _Transport transport) async {
  final address = EndpointAddr.decode(base64Url.decode(encodedAddress));
  final endpoint = await Endpoint.bind(relayMode: transport.relayMode);

  try {
    final connection = await endpoint
        .connect(address, _alpn.codeUnits)
        .timeout(const Duration(seconds: 30));
    if (connection.remoteId != address.id) {
      throw StateError('connected endpoint does not match the pinned id');
    }

    final (send, receive) = await connection.openBi();
    await _writeFrame(send, 'request');

    final messages = <String>[
      utf8.decode((await _readFrame(receive)).data),
      utf8.decode((await _readFrame(receive)).data),
      utf8.decode((await _readFrame(receive)).data),
    ];
    if (messages.join(',') != 'response,event-1,event-2') {
      throw StateError('unexpected messages: $messages');
    }

    await send.finish();
    stdout.writeln(
      'IROH_SPIKE_OK ${connection.remoteId.toZ32()} ${messages.join(',')}',
    );
  } finally {
    await endpoint.close();
  }
}

Future<void> _printIdentity(File secretFile) async {
  final secretKey = await _loadOrCreateSecret(secretFile);
  final endpoint = await Endpoint.bind(
    secretKey: secretKey,
    relayMode: RelayMode.disabled,
  );
  try {
    stdout.writeln('IROH_SPIKE_ID ${endpoint.id.toZ32()}');
  } finally {
    await endpoint.close();
  }
}

Future<SecretKey> _loadOrCreateSecret(File file) async {
  if (await file.exists()) {
    return SecretKey.fromBytes(await file.readAsBytes());
  }

  await file.parent.create(recursive: true);
  final secret = SecretKey.generate();
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsBytes(secret.toBytes(), flush: true);
  await temporary.rename(file.path);
  return secret;
}

Future<EndpointAddr> _advertisedAddress(
  Endpoint endpoint,
  _Transport transport,
) async {
  if (transport == _Transport.direct) {
    return EndpointAddr(
      endpoint.id,
      ipAddrs: _loopbackAddresses(endpoint.boundSockets),
    );
  }

  var address = endpoint.addr;
  if (address.relayUrls.isEmpty) {
    address = await endpoint
        .watchAddr()
        .firstWhere((candidate) => candidate.relayUrls.isNotEmpty)
        .timeout(const Duration(seconds: 30));
  }
  return EndpointAddr(endpoint.id, relayUrls: address.relayUrls);
}

List<String> _loopbackAddresses(List<String> boundAddresses) {
  final result = <String>[];
  for (final address in boundAddresses) {
    final separator = address.lastIndexOf(':');
    if (separator == -1) continue;
    final host = address.substring(0, separator);
    final port = address.substring(separator + 1);
    result.add(
      host.startsWith('[') || host.contains(':')
          ? '[::1]:$port'
          : '127.0.0.1:$port',
    );
  }
  if (result.isEmpty) {
    throw StateError('Iroh endpoint did not expose a bound socket');
  }
  return result;
}

Future<void> _writeFrame(SendStream stream, String value) async {
  final payload = pb.Bytes(data: utf8.encode(value)).writeToBuffer();
  if (payload.length > _maxFrameLength) {
    throw RangeError.range(payload.length, 0, _maxFrameLength, 'frameLength');
  }

  final header = ByteData(4)..setUint32(0, payload.length, Endian.big);
  await stream.writeAll(header.buffer.asUint8List());
  await stream.writeAll(payload);
}

Future<pb.Bytes> _readFrame(RecvStream stream) async {
  final header = await stream.readExact(4);
  final length = ByteData.sublistView(header).getUint32(0, Endian.big);
  if (length > _maxFrameLength) {
    throw FormatException('frame length $length exceeds $_maxFrameLength');
  }
  return pb.Bytes.fromBuffer(await stream.readExact(length));
}

enum _Transport {
  direct(RelayMode.disabled),
  relay(RelayMode.n0Default);

  const _Transport(this.relayMode);

  final RelayMode relayMode;
}

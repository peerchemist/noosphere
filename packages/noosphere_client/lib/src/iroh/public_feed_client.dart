import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/public_feed.dart';
import 'package:noosphere_protocol/wire.dart' as wire;
import 'package:synchronized/synchronized.dart';

import 'config.dart';
import 'endpoint.dart';

final class PublicFeedException(final wire.ProtocolErrorCode code)
    implements Exception {
  @override
  String toString() => 'PublicFeedException(${code.name})';
}

/// Verified checkpoint with its exact signed envelope for caching/redistribution.
/// The pin must come from a trusted source, never from the response itself.
final class PublicFeedCheckpoint._(
  final PublicFeedPage page,
  Uint8List envelope,
) {
  final Uint8List _envelope = Uint8List.fromList(envelope);
  Uint8List toBytes() => Uint8List.fromList(_envelope);

  static PublicFeedCheckpoint verify(
    List<int> envelope,
    EndpointId coordinatorId,
  ) {
    if (envelope.length > publicFeedMaxResponseBytes) {
      throw const FormatException('Public feed envelope too large');
    }
    final signed = wire.SignedPublicFeedPage.fromBuffer(envelope);
    final canonicalEnvelope = wire.SignedPublicFeedPage(
      page: signed.page,
      signature: signed.signature,
    ).writeToBuffer();
    if (!const ListEquality<int>().equals(envelope, canonicalEnvelope)) {
      throw const FormatException('Noncanonical public feed envelope');
    }
    if (!coordinatorId.verify(
      publicFeedCheckpointBytes(signed.page),
      Signature.fromBytes(signed.signature),
    )) {
      throw const FormatException('Invalid public feed checkpoint signature');
    }
    return PublicFeedCheckpoint._(
      PublicFeedPage.fromBytes(signed.page),
      Uint8List.fromList(envelope),
    );
  }
}

/// Owns a fresh ephemeral endpoint and exposes only fetch/close, without any
/// participant key callback, session, client storage, or FROST initialization.
final class PublicFeedClient._(
  final IrohClientTransportConfig _config,
  final IrohClientEndpoint _endpoint,
  final Connection _connection,
) {
  static Future<PublicFeedClient> connect(
    EndpointAddr address,
    EndpointId pinnedCoordinatorId, {
    IrohRelayConfig? relay,
    String? nativeLibraryPath,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration rpcTimeout = const Duration(seconds: 15),
  }) async {
    // Reject an inconsistent address before binding a local endpoint.
    if (address.id != pinnedCoordinatorId) {
      throw PinnedEndpointMismatchException(
        expected: pinnedCoordinatorId,
        actual: address.id,
      );
    }
    final config = IrohClientTransportConfig(
      bootstrapAddress: address,
      pinnedServerId: pinnedCoordinatorId,
      alpn: noospherePublicFeedAlpn,
      relay: relay,
      nativeLibraryPath: nativeLibraryPath,
      connectTimeout: connectTimeout,
      rpcTimeout: rpcTimeout,
      maxMessageLength: publicFeedMaxResponseBytes,
    );
    final endpoint = await IrohClientEndpoint.bind(config);
    try {
      return PublicFeedClient._(
        config,
        endpoint,
        await endpoint.connect(config),
      );
    } catch (_) {
      await endpoint.close();
      rethrow;
    }
  }

  final Lock _fetchLock = Lock();
  bool _closed = false;
  Future<void>? _closing;
  bool get isClosed => _closed;

  Future<PublicFeedPage> fetch(
    PublicFeedId feedId, {
    int afterCursor = 0,
    int limit = 100,
  }) async => (await fetchCheckpoint(
    feedId,
    afterCursor: afterCursor,
    limit: limit,
  )).page;

  Future<PublicFeedCheckpoint> fetchCheckpoint(
    PublicFeedId feedId, {
    int afterCursor = 0,
    int limit = 100,
  }) {
    RangeError.checkValueInInterval(
      afterCursor,
      0,
      publicFeedMaxCursor,
      'afterCursor',
    );
    return _fetchLock.synchronized(
      () =>
          _fetch(feedId, afterCursor, limit.clamp(1, publicFeedMaxPageEntries)),
    );
  }

  Future<PublicFeedCheckpoint> _fetch(
    PublicFeedId feedId,
    int afterCursor,
    int limit,
  ) async {
    if (_closed) throw StateError('public feed client is closed');
    final request = wire.GetPublicFeedRequest(
      feedId: feedId.toBytes(),
      afterCursor: afterCursor,
      limit: limit,
    );
    final (send, receive) = await _connection.openBi().timeout(
      _config.rpcTimeout,
    );
    final reader = wire.QuicStreamReader(_chunks(receive));
    try {
      await send
          .writeAll([
            ...wire.encodeQuicVarInt(wire.PublicFeedOperation.getPublicFeed.id),
            ...request.writeToBuffer(),
          ])
          .timeout(_config.rpcTimeout);
      await send.finish().timeout(_config.rpcTimeout);
      final status = await reader.readVarInt().timeout(_config.rpcTimeout);
      final body = await reader
          .readToEnd(maxLength: publicFeedMaxResponseBytes)
          .timeout(_config.rpcTimeout);
      if (status == wire.RpcResponseStatus.error) {
        throw PublicFeedException(wire.ProtocolError.fromBuffer(body).code);
      }
      if (status != wire.RpcResponseStatus.success) {
        throw const FormatException('Invalid public response status');
      }
      final checkpoint = PublicFeedCheckpoint.verify(
        body,
        _config.pinnedServerId,
      );
      if (checkpoint.page.feedId != feedId ||
          checkpoint.page.afterCursor != afterCursor ||
          checkpoint.page.entries.length > limit) {
        throw const FormatException(
          'Public feed response does not match request',
        );
      }
      return checkpoint;
    } on Object {
      // Timeout is not cancellation. Close this polling connection so that
      // pending native I/O cannot accumulate across subsequent fetches.
      _connection.close(reason: 'public polling failed'.codeUnits);
      try {
        await close();
      } on Exception {
        // Preserve the polling failure.
      }
      rethrow;
    } finally {
      try {
        await receive.stop(0).timeout(_config.rpcTimeout);
      } on Exception {
        // Preserve the original result/failure if the peer already closed.
      }
      try {
        await reader.cancel();
      } on Exception {
        // Preserve the polling result if the decoder already closed.
      }
    }
  }

  Future<void> close() {
    _closed = true;
    _connection.close(reason: 'public polling complete'.codeUnits);
    return _closing ??= _endpoint.close();
  }
}

Stream<List<int>> _chunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(4096);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

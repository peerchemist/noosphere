import 'dart:async';
import 'dart:math';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere/public_feed.dart';
import 'package:noosphere/wire.dart';

import '../config/iroh.dart';
import 'dispatcher.dart';

/// A deliberately separate transport handler with no signer connection context.
final class PublicFeedConnectionHandler({
  required final Connection connection,
  required final IrohDispatcher dispatcher,
  required final IrohConfig config,
  required final SecretKey signingKey,
}) {
  final Set<Future<void>> _streams = {};

  Future<void> run() async {
    try {
      while (true) {
        final (send, receive) = await connection.acceptBi();
        if (_streams.length >= config.maxStreamsPerConnection) {
          await send.reset(1);
          await receive.stop(1);
          continue;
        }
        late final Future<void> handling;
        handling = _handle(
          send,
          receive,
        ).whenComplete(() => _streams.remove(handling));
        _streams.add(handling);
      }
    } on IrohConnectionException {
      // Normal connection closure; there is no participant to disconnect.
    } finally {
      await Future.wait(_streams.toList(), eagerError: false);
    }
  }

  Future<void> _handle(SendStream send, RecvStream receive) async {
    final reader = QuicStreamReader(_chunks(receive));
    try {
      final operation = await reader.readVarInt().timeout(config.rpcTimeout);
      if (operation != PublicFeedOperation.getPublicFeed.id) {
        await _error(
          send,
          ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
          'unsupported public operation',
        );
        return;
      }
      final body = await reader
          .readToEnd(maxLength: min(config.maxMessageLength, 256))
          .timeout(config.rpcTimeout);
      final request = GetPublicFeedRequest.fromBuffer(body);
      // uint64 values outside Dart's positive signed range become negative.
      final cursor = request.afterCursor.toInt();
      if (cursor < 0 || cursor > publicFeedMaxCursor) {
        throw const FormatException('Invalid cursor');
      }
      final feedId = PublicFeedId.fromBytes(request.feedId);
      final page = await dispatcher
          .getPublicFeed(feedId, cursor, request.limit)
          .timeout(config.rpcTimeout);
      if (page == null) {
        await _error(
          send,
          ProtocolErrorCode.PROTOCOL_ERROR_NOT_FOUND,
          'feed not found',
        );
        return;
      }
      final canonical = page.toBytes();
      final response = SignedPublicFeedPage(
        page: canonical,
        signature: signingKey
            .sign(publicFeedCheckpointBytes(canonical))
            .toBytes(),
      ).writeToBuffer();
      if (response.length >
          min(config.maxMessageLength, publicFeedMaxResponseBytes)) {
        await _error(
          send,
          ProtocolErrorCode.PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
          'public response limit',
        );
        return;
      }
      await send
          .writeAll(encodeQuicVarInt(RpcResponseStatus.success))
          .timeout(config.rpcTimeout);
      await send.writeAll(response).timeout(config.rpcTimeout);
    } on Exception {
      try {
        await _error(
          send,
          ProtocolErrorCode.PROTOCOL_ERROR_INVALID_REQUEST,
          'invalid public request',
        );
      } on Exception {
        // Stream or peer already closed. Never expose internal errors.
      }
    } finally {
      try {
        await send.finish().timeout(config.rpcTimeout);
      } on Exception {
        // Peer already closed/reset the response.
      }
      try {
        await receive.stop(0).timeout(config.rpcTimeout);
      } on Exception {
        // A FIN-completed receive half may already be closed.
      }
      try {
        await reader.cancel();
      } on Exception {
        // Decoder already closed.
      }
    }
  }

  Future<void> _error(
    SendStream send,
    ProtocolErrorCode code,
    String message,
  ) async {
    await send
        .writeAll(encodeQuicVarInt(RpcResponseStatus.error))
        .timeout(config.rpcTimeout);
    await send
        .writeAll(ProtocolError(code: code, message: message).writeToBuffer())
        .timeout(config.rpcTimeout);
  }
}

Stream<List<int>> _chunks(RecvStream receive) async* {
  while (true) {
    final chunk = await receive.read(4096);
    if (chunk == null) return;
    if (chunk.isNotEmpty) yield chunk;
  }
}

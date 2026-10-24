import 'dart:async';
import 'dart:math';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_protocol/public_feed.dart';
import 'package:noosphere_protocol/wire.dart';

import '../config/iroh.dart';
import 'dispatcher.dart';
import 'stream_policy.dart';

/// A deliberately separate transport handler with no signer connection context.
final class PublicFeedConnectionHandler({
  required final Connection connection,
  required final void Function(Object, StackTrace) onError,
  required final IrohDispatcher dispatcher,
  required final IrohConfig config,
  required final SecretKey signingKey,
}) {
  final IrohStreamPolicy _streamPolicy = IrohStreamPolicy(
    connection: connection,
    onError: onError,
    timeout: config.rpcTimeout,
    maxConcurrent: config.maxStreamsPerConnection,
    idleTimeout: config.rpcTimeout,
  );

  Future<void> run() async {
    _streamPolicy.startIdleDeadline();
    try {
      while (true) {
        final (send, receive) = await connection.acceptBi();
        await _streamPolicy.admit(
          send: send,
          receive: receive,
          handle: () => _handle(send, receive),
        );
      }
    } on IrohConnectionException {
      // Normal connection closure; there is no participant to disconnect.
    } finally {
      await _streamPolicy.drain();
    }
  }

  Future<void> _handle(SendStream send, RecvStream receive) async {
    final reader = QuicStreamReader(readIrohChunks(receive));
    var requestReceived = false;
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
          .readToEnd(
            maxLength: min(config.maxMessageLength, publicFeedMaxRequestBytes),
          )
          .timeout(config.rpcTimeout);
      requestReceived = true;
      final request = GetPublicFeedRequest.fromBuffer(body);
      final cursor = request.afterCursor;
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
    } catch (error) {
      if (!isIrohRequestError(error)) rethrow;
      try {
        await _error(
          send,
          commonIrohProtocolErrorCode(error),
          'invalid public request',
        );
      } on Exception {
        // Stream or peer already closed. Never expose internal errors.
      }
    } finally {
      await _streamPolicy.finishStream(
        send: send,
        receive: receive,
        reader: reader,
        requestReceived: requestReceived,
      );
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

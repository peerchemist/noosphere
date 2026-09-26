import 'dart:async';
import 'dart:math';

import '../client/client.dart';
import '../client/storage_interface.dart';
import '../config/client.dart';
import 'client_api.dart';
import 'config.dart';
import 'endpoint.dart';

/// Backoff used when opening a new Iroh connection and session after a
/// disconnect.
final class IrohReconnectConfig {
  const IrohReconnectConfig({
    this.initialDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2,
    this.jitter = 0.2,
  }) : assert(multiplier >= 1),
       assert(jitter >= 0 && jitter <= 1);

  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;
  final double jitter;

  Duration delayForAttempt(int attempt, double randomValue) {
    if (attempt < 0) throw RangeError.value(attempt, 'attempt');
    if (initialDelay.isNegative ||
        maxDelay < initialDelay ||
        multiplier < 1 ||
        jitter < 0 ||
        jitter > 1) {
      throw ArgumentError('invalid reconnect configuration');
    }
    if (randomValue < 0 || randomValue > 1) {
      throw RangeError.range(randomValue, 0, 1, 'randomValue');
    }
    final scaled = initialDelay.inMicroseconds * pow(multiplier, attempt);
    final jitterFactor = 1 - jitter + (2 * jitter * randomValue);
    final jittered = scaled * jitterFactor;
    return Duration(
      microseconds: min(jittered, maxDelay.inMicroseconds).round(),
    );
  }
}

/// Owns a sequence of independent [Client] sessions over Iroh.
///
/// A transport disconnect permanently ends the current session. This runtime
/// reconnects with backoff, performs a fresh login and exposes the replacement
/// [Client] through [sessions]. It never retries an in-flight mutating RPC.
final class ReconnectingIrohClient {
  ReconnectingIrohClient._({
    required this.clientConfig,
    required this._transportConfig,
    required this.store,
    required this.getPrivateKey,
    required this.reconnectConfig,
    required this._endpoint,
    required this._ownsEndpoint,
  });

  static Future<ReconnectingIrohClient> connect({
    required ClientConfig clientConfig,
    required IrohClientTransportConfig transportConfig,
    required ClientStorageInterface store,
    required GetPrivateKey getPrivateKey,
    IrohReconnectConfig reconnectConfig = const IrohReconnectConfig(),
    IrohClientEndpoint? endpoint,
  }) async {
    final rootEndpoint =
        endpoint ?? await IrohClientEndpoint.bind(transportConfig);
    final runtime = ReconnectingIrohClient._(
      clientConfig: clientConfig,
      transportConfig: transportConfig,
      store: store,
      getPrivateKey: getPrivateKey,
      reconnectConfig: reconnectConfig,
      endpoint: rootEndpoint,
      ownsEndpoint: endpoint == null,
    );
    try {
      await runtime._openSession();
      return runtime;
    } catch (_) {
      if (runtime._ownsEndpoint) await rootEndpoint.close();
      rethrow;
    }
  }

  final ClientConfig clientConfig;
  IrohClientTransportConfig _transportConfig;
  final ClientStorageInterface store;
  final GetPrivateKey getPrivateKey;
  final IrohReconnectConfig reconnectConfig;
  final IrohClientEndpoint _endpoint;
  final bool _ownsEndpoint;
  final Random _random = Random.secure();
  final StreamController<Client> _sessions = StreamController.broadcast();
  final Completer<void> _closedSignal = Completer();

  Client? _client;
  IrohClientApi? _api;
  Future<void>? _reconnecting;
  Future<void>? _closing;
  int _generation = 0;
  bool _closed = false;
  bool _connected = false;

  Client get current {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('no active Iroh client session');
    }
    return client;
  }

  /// Replacement clients created after successful reconnects. The initial
  /// client is available through [current]. Reconnect failures are emitted as
  /// stream errors while retries continue.
  Stream<Client> get sessions => _sessions.stream;

  bool get isConnected => _connected && !_closed;
  bool get isClosed => _closed;
  IrohClientTransportConfig get transportConfig => _transportConfig;

  /// Replaces connection hints used by the next reconnect attempt. The pinned
  /// server identity cannot be changed for an existing runtime.
  void updateTransportConfig(IrohClientTransportConfig config) {
    if (_closed) throw const IrohClientClosedException();
    if (config.pinnedServerId != _transportConfig.pinnedServerId) {
      throw ArgumentError.value(
        config.pinnedServerId,
        'config.pinnedServerId',
        'cannot change the pinned server identity',
      );
    }
    _transportConfig = config;
  }

  Future<Client> _openSession() async {
    final generation = ++_generation;
    final api = await IrohClientApi.connect(
      _transportConfig,
      endpoint: IrohClientEndpoint.borrowed(_endpoint.endpoint),
    );
    try {
      final client = await Client.login(
        config: clientConfig,
        api: api,
        store: store,
        getPrivateKey: getPrivateKey,
        onDisconnect: () => _onDisconnect(generation),
      );
      if (_closed || generation != _generation) {
        await client.logout();
        await api.close();
        throw const IrohClientClosedException();
      }
      _api = api;
      _client = client;
      _connected = true;
      return client;
    } catch (_) {
      await api.close();
      rethrow;
    }
  }

  void _onDisconnect(int generation) {
    if (_closed || generation != _generation || _reconnecting != null) return;
    _connected = false;
    _reconnecting = _reconnect().whenComplete(() => _reconnecting = null);
  }

  Future<void> _reconnect() async {
    var attempt = 0;
    while (!_closed) {
      final delay = reconnectConfig.delayForAttempt(
        attempt,
        _random.nextDouble(),
      );
      await Future.any([Future<void>.delayed(delay), _closedSignal.future]);
      if (_closed) return;
      try {
        final client = await _openSession();
        if (!_sessions.isClosed) _sessions.add(client);
        return;
      } catch (error, stackTrace) {
        if (_closed) return;
        if (!_sessions.isClosed) _sessions.addError(error, stackTrace);
        attempt++;
      }
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _connected = false;
    _generation++;
    _closedSignal.complete();

    final client = _client;
    final api = _api;
    final clientClosing = client?.logout() ?? Future<void>.value();
    final apiClosing = api?.close() ?? Future<void>.value();
    final endpointClosing = _ownsEndpoint
        ? _endpoint.close()
        : Future<void>.value();
    await Future.wait([apiClosing, endpointClosing], eagerError: false);
    await clientClosing;
    await _reconnecting;
    await _sessions.close();
  }
}

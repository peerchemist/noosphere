import 'dart:typed_data';

import 'package:iroh_quic/iroh_quic.dart';
import 'package:noosphere_client/noosphere_client.dart';

enum IrohConnectionPhase {
  connected,
  challengeIssued,
  authenticated,
  sessionAttached,
  ready,
  closed,
}

final class ConnectionContext {
  ConnectionContext({
    required this.connectionId,
    required this.remoteEndpointId,
  });

  final int connectionId;
  final EndpointId remoteEndpointId;
  IrohConnectionPhase _phase = IrohConnectionPhase.connected;
  AuthChallenge? _pendingChallenge;
  Uint8List? _pendingGroupFingerprint;
  Identifier? _pendingParticipantId;
  Uint8List? _groupFingerprint;
  Identifier? _participantId;
  SessionID? _sessionId;

  IrohConnectionPhase get phase => _phase;
  Uint8List? get groupFingerprint =>
      _groupFingerprint == null ? null : Uint8List.fromList(_groupFingerprint!);
  Uint8List? get boundGroupFingerprint {
    final value = _groupFingerprint ?? _pendingGroupFingerprint;
    return value == null ? null : Uint8List.fromList(value);
  }

  Identifier? get participantId => _participantId;
  Identifier? get pendingParticipantId => _pendingParticipantId;
  SessionID? get sessionId => _sessionId;
  AuthChallenge? get pendingChallenge => _pendingChallenge;
  bool get isClosed => _phase == IrohConnectionPhase.closed;
  bool get hasGroupBinding =>
      _groupFingerprint != null || _pendingGroupFingerprint != null;

  bool belongsToGroup(List<int> fingerprint) {
    final current = _groupFingerprint ?? _pendingGroupFingerprint;
    if (current == null || current.length != fingerprint.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != fingerprint[i]) return false;
    }
    return true;
  }

  void issueChallenge({
    required AuthChallenge challenge,
    required List<int> groupFingerprint,
    required Identifier participantId,
  }) {
    _requirePhase(IrohConnectionPhase.connected);
    _pendingChallenge = challenge;
    _pendingGroupFingerprint = Uint8List.fromList(groupFingerprint);
    _pendingParticipantId = participantId;
    _phase = IrohConnectionPhase.challengeIssued;
  }

  bool acceptsChallenge(AuthChallenge challenge) =>
      _phase == IrohConnectionPhase.challengeIssued &&
      _pendingChallenge == challenge;

  void authenticate() {
    _requirePhase(IrohConnectionPhase.challengeIssued);
    _groupFingerprint = _pendingGroupFingerprint;
    _participantId = _pendingParticipantId;
    _pendingChallenge = null;
    _pendingGroupFingerprint = null;
    _pendingParticipantId = null;
    _phase = IrohConnectionPhase.authenticated;
  }

  void attachSession(SessionID sessionId) {
    _requirePhase(IrohConnectionPhase.authenticated);
    _sessionId = sessionId;
    _phase = IrohConnectionPhase.sessionAttached;
  }

  void markReady() {
    _requirePhase(IrohConnectionPhase.sessionAttached);
    _phase = IrohConnectionPhase.ready;
  }

  void close() {
    _pendingChallenge = null;
    _pendingGroupFingerprint = null;
    _pendingParticipantId = null;
    _sessionId = null;
    _phase = IrohConnectionPhase.closed;
  }

  void ensureOpen() {
    if (isClosed) throw StateError('connection context is closed');
  }

  void _requirePhase(IrohConnectionPhase expected) {
    ensureOpen();
    if (_phase != expected) {
      throw StateError('expected connection phase $expected, got $_phase');
    }
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/domain.dart';
import 'package:noosphere_client/src/client/cached_storage.dart';
import 'package:noosphere_client/src/client/dkg_in_progress.dart';
import 'package:noosphere_client/src/client/frost_key_with_details.dart';
import 'package:noosphere_client/src/client/state/sigs.dart';
import 'package:noosphere_client/src/config/client.dart';
import 'package:synchronized/extension.dart';

import 'events.dart';
import 'key_construction.dart';
import 'signatures_request.dart';
import 'storage_interface.dart';
import 'state/state.dart';
import 'state/dkg.dart';

part 'client_dkg.dart';
part 'client_signing.dart';
part 'client_key_sharing.dart';
part 'client_events.dart';
part 'client_session.dart';

typedef GetPrivateKey = Future<cl.ECPrivateKey> Function(KeyPurpose purpose);

/// An exception thrown when the server misbehaves
class ServerMisbehaviour implements Exception {
  final String message;

  ServerMisbehaviour(this.message);
  ServerMisbehaviour.noParticipant()
    : this("Participant identifier outside of group");
  ServerMisbehaviour.invalidDkgThreshold() : this("DKG threshold is too high");
  ServerMisbehaviour.duplicateDkg() : this("DKG names are not unique");
  ServerMisbehaviour.invalidSignature() : this("Invalid signature");
  ServerMisbehaviour.duplicateCommitment() : this("Duplicate commitment");
  ServerMisbehaviour.wrongParticipant() : this("Incorrect participant id");
  ServerMisbehaviour.badExpiry() : this("Expiry outside of bounds");
  ServerMisbehaviour.commitmentNotRound1()
    : this("Commitment given outside of round 1");
  ServerMisbehaviour.secretNotRound2()
    : this("Secret share given outside of round 2");
  ServerMisbehaviour.alreadyHaveSecret()
    : this("Already have DKG secret for participant");
  ServerMisbehaviour.ackNotRequested() : this("Gave ACK that wasn't requested");
  ServerMisbehaviour.duplicateSigsReq() : this("Duplicate signatures request");
  ServerMisbehaviour.duplicateSigsReqRounds()
    : this("Duplicate signatures request IDs for rounds");
  ServerMisbehaviour.emptySigRounds() : this("List of signing rounds is empty");
  ServerMisbehaviour.sigRoundOutOfRange()
    : this("Round signature index out of range");
  ServerMisbehaviour.duplicateSignRound()
    : this("ROAST round already requested");
  ServerMisbehaviour.wrongCommitmentNum()
    : this("Incorrect number of round commitments");
  ServerMisbehaviour.missingOurId()
    : this("Own signing commitment missing from set");
  ServerMisbehaviour.missingSigsReq()
    : this("Received signing round on login without associated request");
  ServerMisbehaviour.emptySignatures()
    : this("List of completed signatures is empty");
  ServerMisbehaviour.wrongSigNum()
    : this("Incorrect number of completed signatures");
  ServerMisbehaviour.prematureSigs()
    : this("Signatures responded before shares");
  ServerMisbehaviour.invalidCompleteSig()
    : this("Completed signature is invalid");

  @override
  String toString() => "ServerMisbehaviour: $message";
}

/// A high-level abstraction of a FROST participant client with the server API.
/// Use the [login] factory to create a client.
///
/// [ClientEvent]s are passed to the [events] stream.
///
/// An error may also passed to the [events] stream. The Client will disconnect
/// upon an error and [login] must be called again.
class Client {
  // Reasonable wait before extending session to prevent excessive requests
  static const _minWait = Duration(seconds: 10);

  // Time to extend session before expiry
  static const _extendBufferTime = Duration(seconds: 15);

  // Min TTL, under which the server will be considered misbehaving.
  static const _minExpiryTTL = Duration(minutes: -2);

  final ClientConfig config;
  final ApiRequestInterface api;
  final ClientCachedStorage _store;
  Map<cl.ECCompressedPublicKey, FrostKeyWithDetails> get _keys => _store.keys;

  /// An asynchronous function to get the private key to allow for secure
  /// ephemeral access as needed.
  final GetPrivateKey getPrivateKey;
  final void Function() onDisconnect;

  late final ClientState _state;
  final _eventController = StreamController<ClientEvent>();
  late final StreamSubscription<Event> _eventSubscription;
  Future<void> _eventFuture = Future.value();
  bool _disconnecting = false;

  final _sigReqLock = Object();
  final _dkgReqLock = Object();
  final _dkgAckLock = Object();
  // Used as persistent locks for each key, even when the key object changes
  final _keyLocks = <cl.ECCompressedPublicKey, Object>{};

  static cl.ECPublicKey _getParticipantPubkeyForId(
    ClientConfig config,
    Identifier id,
  ) {
    final pubkey = config.group.participants[id];
    if (pubkey == null) throw ServerMisbehaviour.noParticipant();
    return pubkey;
  }

  static void _checkIdentifierSet(ClientConfig config, Set<Identifier> ids) {
    if (!config.allIds.containsAll(ids)) {
      throw ServerMisbehaviour.noParticipant();
    }
  }

  static void _checkOtherParticipantId(ClientConfig config, Identifier id) {
    _getParticipantPubkeyForId(config, id);
    if (id == config.id) throw ServerMisbehaviour.wrongParticipant();
  }

  static Set<Identifier> _idsFromCommitments(DkgCommitmentList commitments) {
    final idSet = commitments.map((c) => c.$1).toSet();
    if (idSet.length != commitments.length) {
      throw ServerMisbehaviour.duplicateCommitment();
    }
    return idSet;
  }

  static void _checkSigned(
    ClientConfig config,
    Signed signed,
    Identifier signer,
  ) {
    if (!signed.verify(_getParticipantPubkeyForId(config, signer))) {
      throw ServerMisbehaviour.invalidSignature();
    }
  }

  static void _checkDetailsEvent(ClientConfig config, DetailsEvent ev) {
    _checkSigned(config, ev.details, ev.creator);
    if (ev.expiry.ttl.compareTo(_minExpiryTTL) < 0) {
      throw ServerMisbehaviour.badExpiry();
    }
  }

  static void _checkNewDkg(ClientConfig config, NewDkgEvent dkg) {
    _checkDetailsEvent(config, dkg);

    final details = dkg.details.obj;
    if (details.threshold > config.groupN) {
      throw ServerMisbehaviour.invalidDkgThreshold();
    }

    _checkIdentifierSet(config, _idsFromCommitments(dkg.commitments));
  }

  static void _checkSignaturesProgress(
    ClientConfig config,
    SignaturesProgress progress,
  ) {
    if (progress.threshold > config.groupN ||
        progress.contributingParticipants.length > progress.threshold) {
      throw ServerMisbehaviour('Invalid signatures progress');
    }
    _checkIdentifierSet(config, progress.contributingParticipants);
  }

  // Check round information without state context
  static void _checkRounds(
    ClientConfig config,
    List<SignatureRoundStart> rounds,
  ) {
    if (rounds.isEmpty) {
      throw ServerMisbehaviour.emptySigRounds();
    }

    if (rounds.map((round) => round.sigI).toSet().length != rounds.length) {
      throw ServerMisbehaviour.duplicateSignRound();
    }

    for (final round in rounds) {
      // Check commitments contains client id
      final ids = round.commitments.map.keys.toSet();
      if (!ids.contains(config.id)) {
        throw ServerMisbehaviour.missingOurId();
      }

      // Check identifiers exist in group
      _checkIdentifierSet(config, ids);

      // Check that the signature index is nonnegative.
      if (round.sigI < 0) {
        throw ServerMisbehaviour.sigRoundOutOfRange();
      }
    }
  }

  Client._({
    required this.config,
    required this.api,
    required this._store,
    required SessionID sessionID,
    required Expiry sessionExpiry,
    required Stream<Event> events,
    required this.getPrivateKey,
    required this.onDisconnect,
  }) {
    _state = ClientState(
      sessionID: sessionID,
      expiry: sessionExpiry,
      onDkgExpired: _onDkgExpiry,
      onSigsReqExpired: _onSigsReqExpiry,
    );

    _setSessionExtendTimer();

    _eventSubscription = events.listen(
      (ev) => _eventFuture = _handleEvent(ev),
      onDone: () => _disconnect(),
      onError: (Object e) => _sendError(e),
    );
  }

  void _onDkgExpiry(ClientDkgState dkgState) => _sendEvent(
    RejectedDkgClientEvent(
      details: dkgState.details,
      participant: null,
      fault: DkgFault.expired,
    ),
  );

  void _onSigsReqExpiry(ClientSigsState sigsState) =>
      _sendEvent(SignaturesExpiryClientEvent(_sigsStateToObj(sigsState)));

  void _disconnect() {
    if (_disconnecting) return;
    _disconnecting = true;
    try {
      onDisconnect();
    } finally {
      unawaited(logout());
    }
  }

  void _sendEvent(ClientEvent ev) => _eventController.add(ev);
  void _sendError(Object err) {
    if (_eventController.isClosed) return;
    _eventController.addError(err);
    _disconnect();
  }

  /// Creates a new Client session with the server.
  ///
  /// The session will automatically be extended.
  ///
  /// The client shall remain alive until [logout] is called or until the server
  /// disconnects. [onDisconnect] will be called if a disconnection is detected.
  /// After a disconnect, the [events] stream will close and all methods should
  /// produce an exception.
  ///
  /// The [events] stream should be listened to immediately as events will
  /// continuously buffer until they are handled.
  static Future<Client> login({
    required ClientConfig config,
    required ApiRequestInterface api,
    required ClientStorageInterface store,
    required GetPrivateKey getPrivateKey,
    void Function()? onDisconnect,
  }) => _loginClient(
    config: config,
    api: api,
    store: store,
    getPrivateKey: getPrivateKey,
    onDisconnect: onDisconnect,
  );

  /// Request Distributed Key Generation for a proposed key with the given
  /// [details]. The DKG name must not be the same as any other in-progress DKG.
  /// [dkgExists] can be used to determine if a name already exists.
  ///
  /// The client will be assumed to have accepted the DKG.
  Future<void> requestDkg(NewDkgDetails details) => _requestDkg(details);

  Future<void> rejectDkg(String name) =>
      _runDkgSyncIfExists(name, (_) => _rejectDkgWithoutSync(name));

  Future<void> acceptDkg(String name) => _acceptDkg(name);

  /// Request signatures from the group
  Future<void> requestSignatures(SignaturesRequestDetails details) =>
      _requestSignatures(details);

  Future<void> rejectSignaturesRequest(SignaturesRequestId reqId) =>
      _runSigsReqSyncIfExists(reqId, _rejectSigsReq);

  Future<void> acceptSignaturesRequest(SignaturesRequestId reqId) =>
      _runSigsReqSyncIfExists(reqId, (sigsState) async {
        // Remove from rejected if it was
        await _store.removeRejectionOfSigsRequest(reqId);
        await _continueSigning(sigsState);
      });

  /// This method is dangerous. Only use this to reveal the private key for the
  /// FROST key with other participants.
  ///
  /// Shares the secret for the FROST key given by [groupKey]. If [toWhom] is
  /// omitted, it will be shared with all, otherwise it will only be shared with
  /// the participants provided.
  ///
  /// Once a participant has obtained a threshold of secret shares, it can
  /// construct the underlying private key for the FROST key.
  /// [SecretShareClientEvent] will be provided after processing a secret share.
  ///
  /// Secrets are shared with end-to-end encryption so the server will not be
  /// able to construct the key.
  Future<void> shareKeySecret(
    cl.ECCompressedPublicKey groupKey, {
    Set<Identifier>? toWhom,
  }) => _shareKeySecret(groupKey, toWhom: toWhom);

  /// Stops further activity of the client and waits for existing events to
  /// finish processing before completing.
  ///
  /// The client can no longer be used after this has been called
  Future<void> logout() async {
    // Ensure session is expired and that no more events shall be processed
    _state.sessionExtension?.cancel();
    _state.expiry = Expiry(Duration(days: -1));
    // Finish existing events
    await _eventFuture;
    // Cancel stream with server
    await _eventSubscription.cancel();
    final hasEventListener = _eventController.hasListener;
    final closeEvents = _eventController.close();
    if (hasEventListener) {
      await closeEvents;
    } else {
      unawaited(closeEvents);
    }
  }

  /// Determines if the in-progress DKG by [name] already exists.
  bool dkgExists(String name) => _state.nameToDkg.containsKey(name);

  /// Participants that are online according to the server
  Set<Identifier> get onlineParticipants =>
      Set.unmodifiable(_state.onlineParticipants);

  List<DkgInProgress> _getDkgProgress(bool accepted) => _state.nameToDkg.values
      .where((dkg) => _dkgIsAccepted(dkg) == accepted)
      .map((dkg) => dkg.progress(config.id))
      .toList();

  /// Requests for DKGs that the client can accept or reject
  List<DkgInProgress> get dkgRequests => _getDkgProgress(false);

  /// Status of DKGs that the client has accepted
  List<DkgInProgress> get acceptedDkgs => _getDkgProgress(true);

  /// Obtains all keys, mapping the group key to the full details
  Map<cl.ECCompressedPublicKey, FrostKeyWithDetails> get keys =>
      Map.unmodifiable({
        for (final entry in _store.keys.entries)
          entry.key: FrostKeyWithDetails.fromBytes(entry.value.toBytes()),
      });

  SignaturesRequest _sigsStateToObj(ClientSigsState sigsState) =>
      SignaturesRequest(
        details: sigsState.details,
        creator: sigsState.creator,
        expiry: sigsState.expiry,
        status: _store.sigsRejected.containsKey(sigsState.details.id)
            ? SignaturesRequestStatus.rejected
            : (
              // If we have provided nonces, then we have accepted the request
              _store.sigNonces.containsKey(sigsState.details.id)
                  ? SignaturesRequestStatus.accepted
                  : SignaturesRequestStatus.waiting),
        progress: sigsState.progress,
      );

  /// A list of all outstanding signatures requests, including those already
  /// accepted or rejected by the client.
  List<SignaturesRequest> get signaturesRequests =>
      _state.sigRequests.values.map(_sigsStateToObj).toList();

  /// A stream of events to keep track of state changes that occur. If an error
  /// is provided on this stream, the stream will immediately close afterwards.
  ///
  /// If there is an error, the client may have lost connection to the server,
  /// or the server may be malfunctioning. When an error is received, the client
  /// will be disconnected and [onDisconnect] shall be called. No more events or
  /// errors shall be given and this stream will close. A new login should be
  /// attempted whereby all DKG requests will need to be re-accepted.
  ///
  /// This stream should be listened to immediately and continuously from login
  /// to prevent a large number of events being buffered.
  Stream<ClientEvent> get events => _eventController.stream;
}

/// CONSUMERS OF THIS LIBRARY SHOULD AVOID THIS
///
/// Used for testing purposes only. The state is not intended as part of the
/// library interface and may break backwards compatibility.
ClientState getHiddenClientStateForTestsDoNotUse(Client client) =>
    client._state;

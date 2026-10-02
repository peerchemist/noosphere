import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere/api/types/signatures_request_details.dart';
import 'package:noosphere/api/types/signed.dart';
import 'package:noosphere/common/serial.dart';
import 'package:frosty/frosty.dart';
import 'package:noosphere/api/events.dart';
import 'package:noosphere/api/types/expirable.dart';
import 'package:noosphere/api/types/expiry.dart';
import 'package:noosphere/api/types/onetime_numbers.dart';

/// Provides details of completed signatures upon login
class CompletedSignaturesRequest with cl.Writable, NoosphereWritable {
  final Signed<SignaturesRequestDetails> details;
  final List<cl.SchnorrSignature> signatures;
  final Identifier creator;
  CompletedSignaturesRequest({
    required this.details,
    required List<cl.SchnorrSignature> signatures,
    required this.creator,
  }) : signatures = List.unmodifiable(signatures);

  CompletedSignaturesRequest.fromReader(cl.BytesReader reader)
    : this(
        details: Signed.fromReader(
          reader,
          () => SignaturesRequestDetails.fromReaderAllowNegativeExpiry(reader),
        ),
        signatures: reader.readSignatureVector(),
        creator: reader.readIdentifier(),
      );
  factory CompletedSignaturesRequest.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, CompletedSignaturesRequest.fromReader);

  @override
  void write(cl.Writer writer) {
    details.write(writer);
    writer.writeSignatureVector(signatures);
    writer.writeIdentifier(creator);
  }
}

/// Provides the participant with a [SessionID] and information about the
/// current state of signing and DKG requests.
///
/// [write()] and [toBytes()] does not include any streamed events and the
/// stream must be provided when constructing from bytes.
class LoginCompleteResponse
    with cl.Writable, NoosphereWritable
    implements Expirable {
  /// The session id required to communicate with authenticated methods
  final SessionID id;
  @override
  /// The expiry of the session. The session has to be extended before this or
  /// the session will be removed from the server.
  final Expiry expiry;

  /// The time that the server started. Secret shares that were shared before
  /// the start time can be resent.
  final DateTime startTime;

  /// The participants who are currently online
  final Set<Identifier> _onlineParticipants;

  /// An owned copy for consumers that maintain a live participant set.
  Set<Identifier> get onlineParticipants => Set.of(_onlineParticipants);

  /// Outstanding new DKG requests that require a commitment and all commitments
  /// that have been received by online participants.
  final List<NewDkgEvent> newDkgs;

  /// Current signature requests that require a commitment
  final List<SignaturesRequestEvent> sigRequests;

  /// Details of ROAST rounds that the server is waiting on. The signing nonces
  /// must be stored between sessions so that a participant can proceed with a
  /// round.
  final List<SignatureNewRoundsEvent> sigRounds;

  /// Completed signatures that the participant may not have received whilst
  /// logged out
  final List<CompletedSignaturesRequest> completedSigs;

  /// Secret key shares provided to the participant which were not previously
  /// acknowledged.
  final List<SecretShareEvent> secretShares;

  /// A stream of events of type [Event] that the client should listen to for
  /// this session. The client must listen to this stream as soon as it is
  /// provided to ensure no events are missed.
  final Stream<Event> events;

  LoginCompleteResponse({
    required this.id,
    required this.expiry,
    required this.startTime,
    required Set<Identifier> onlineParticipants,
    required List<NewDkgEvent> newDkgs,
    required List<SignaturesRequestEvent> sigRequests,
    required List<SignatureNewRoundsEvent> sigRounds,
    required List<CompletedSignaturesRequest> completedSigs,
    required List<SecretShareEvent> secretShares,
    required this.events,
  }) : _onlineParticipants = Set.unmodifiable(onlineParticipants),
       newDkgs = List.unmodifiable(newDkgs),
       sigRequests = List.unmodifiable(sigRequests),
       sigRounds = List.unmodifiable(sigRounds),
       completedSigs = List.unmodifiable(completedSigs),
       secretShares = List.unmodifiable(secretShares);

  LoginCompleteResponse.fromReader(cl.BytesReader reader, Stream<Event> events)
    : this(
        id: SessionID.fromReader(reader),
        expiry: Expiry.fromReader(reader),
        startTime: reader.readTime(),
        onlineParticipants: reader.readIdentifierVector().toSet(),
        newDkgs: reader.readWritableVector(
          (bytes) => NewDkgEvent.fromBytes(bytes),
        ),
        sigRequests: reader.readWritableVector(
          (bytes) => SignaturesRequestEvent.fromBytes(bytes),
        ),
        sigRounds: reader.readWritableVector(
          (bytes) => SignatureNewRoundsEvent.fromBytes(bytes),
        ),
        completedSigs: reader.readWritableVector(
          (bytes) => CompletedSignaturesRequest.fromBytes(bytes),
        ),
        secretShares: reader.readWritableVector(
          (bytes) => SecretShareEvent.fromBytes(bytes),
        ),
        events: events,
      );

  factory LoginCompleteResponse.fromBytes(
    Uint8List bytes,
    Stream<Event> events,
  ) => readNoosphere(
    bytes,
    (reader) => LoginCompleteResponse.fromReader(reader, events),
  );

  @override
  void write(cl.Writer writer) {
    id.write(writer);
    expiry.write(writer);
    writer.writeTime(startTime);
    writer.writeIdentifierVector(onlineParticipants);

    for (final evList in [
      newDkgs,
      sigRequests,
      sigRounds,
      completedSigs,
      secretShares,
    ]) {
      writer.writeWritableVector(evList);
    }
  }
}

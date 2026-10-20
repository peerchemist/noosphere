/// Transport-independent ROAST domain model and request contract.
library;

export 'package:frosty/frosty.dart';

export 'src/domain/events.dart';
export 'src/domain/hd_derivation.dart';
export 'src/domain/request_interface.dart';
export 'src/domain/responses/expirable_auth_challenge.dart';
export 'src/domain/responses/login_complete.dart';
export 'src/domain/responses/signatures.dart';
export 'src/domain/types/bytes_mappable.dart';
export 'src/domain/types/cancelled_signatures_request.dart';
export 'src/domain/types/dkg_ack.dart';
export 'src/domain/types/dkg_ack_request.dart';
export 'src/domain/types/dkg_ceremony_snapshot.dart';
export 'src/domain/types/dkg_encrypted_secret.dart';
export 'src/domain/types/encrypted_key_share.dart';
export 'src/domain/types/expirable.dart';
export 'src/domain/types/expiry.dart';
export 'src/domain/types/key_was_constructed.dart';
export 'src/domain/types/new_dkg_details.dart';
export 'src/domain/types/onetime_numbers.dart';
export 'src/domain/types/signature_metadata.dart';
export 'src/domain/types/signature_reply.dart';
export 'src/domain/types/signature_round_start.dart';
export 'src/domain/types/signatures_progress.dart';
export 'src/domain/types/signatures_request_details.dart';
export 'src/domain/types/signed.dart';
export 'src/domain/types/signed_dkg_ack.dart';
export 'src/domain/types/signed_message.dart';
export 'src/domain/types/signed_message_payload.dart';
export 'src/domain/types/single_signature_details.dart';
export 'group_transition.dart';
export 'room.dart';

/// R&D baseline; revised in place until the first stable protocol release.
const int noosphereRoastProtocolVersion = 4;

/// Transport-independent ROAST domain model and request contract.
library;

export 'package:frosty/frosty.dart';

export 'api/events.dart';
export 'api/request_interface.dart';
export 'api/responses/expirable_auth_challenge.dart';
export 'api/responses/login_complete.dart';
export 'api/responses/signatures.dart';
export 'api/types/bytes_mappable.dart';
export 'api/types/dkg_ack.dart';
export 'api/types/dkg_ack_request.dart';
export 'api/types/dkg_encrypted_secret.dart';
export 'api/types/encrypted_key_share.dart';
export 'api/types/expirable.dart';
export 'api/types/expiry.dart';
export 'api/types/key_was_constructed.dart';
export 'api/types/new_dkg_details.dart';
export 'api/types/onetime_numbers.dart';
export 'api/types/signature_metadata.dart';
export 'api/types/signature_reply.dart';
export 'api/types/signature_round_start.dart';
export 'api/types/signatures_request_details.dart';
export 'api/types/signed.dart';
export 'api/types/signed_dkg_ack.dart';
export 'api/types/single_signature_details.dart';
export 'room.dart';

/// R&D baseline; revised in place until the first stable protocol release.
const int noosphereRoastProtocolVersion = 1;

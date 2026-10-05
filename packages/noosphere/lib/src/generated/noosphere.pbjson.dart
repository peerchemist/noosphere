// This is a generated file - do not edit.
//
// Generated from noosphere.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use signaturesProgressStageDescriptor instead')
const SignaturesProgressStage$json = {
  '1': 'SignaturesProgressStage',
  '2': [
    {'1': 'SIGNATURES_PROGRESS_COLLECTING', '2': 0},
    {'1': 'SIGNATURES_PROGRESS_SIGNING', '2': 1},
    {'1': 'SIGNATURES_PROGRESS_COMPLETED', '2': 2},
    {'1': 'SIGNATURES_PROGRESS_FAILED', '2': 3},
  ],
};

/// Descriptor for `SignaturesProgressStage`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List signaturesProgressStageDescriptor = $convert.base64Decode(
    'ChdTaWduYXR1cmVzUHJvZ3Jlc3NTdGFnZRIiCh5TSUdOQVRVUkVTX1BST0dSRVNTX0NPTExFQ1'
    'RJTkcQABIfChtTSUdOQVRVUkVTX1BST0dSRVNTX1NJR05JTkcQARIhCh1TSUdOQVRVUkVTX1BS'
    'T0dSRVNTX0NPTVBMRVRFRBACEh4KGlNJR05BVFVSRVNfUFJPR1JFU1NfRkFJTEVEEAM=');

@$core.Deprecated('Use protocolErrorCodeDescriptor instead')
const ProtocolErrorCode$json = {
  '1': 'ProtocolErrorCode',
  '2': [
    {'1': 'PROTOCOL_ERROR_UNSPECIFIED', '2': 0},
    {'1': 'PROTOCOL_ERROR_INVALID_REQUEST', '2': 1},
    {'1': 'PROTOCOL_ERROR_UNAUTHENTICATED', '2': 2},
    {'1': 'PROTOCOL_ERROR_UNSUPPORTED_VERSION', '2': 3},
    {'1': 'PROTOCOL_ERROR_RESOURCE_EXHAUSTED', '2': 4},
    {'1': 'PROTOCOL_ERROR_DEADLINE_EXCEEDED', '2': 5},
    {'1': 'PROTOCOL_ERROR_INTERNAL', '2': 6},
    {'1': 'PROTOCOL_ERROR_UNKNOWN_OUTCOME', '2': 7},
    {'1': 'PROTOCOL_ERROR_SESSION_NOT_FOUND', '2': 8},
    {'1': 'PROTOCOL_ERROR_SESSION_EXPIRED', '2': 9},
  ],
};

/// Descriptor for `ProtocolErrorCode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List protocolErrorCodeDescriptor = $convert.base64Decode(
    'ChFQcm90b2NvbEVycm9yQ29kZRIeChpQUk9UT0NPTF9FUlJPUl9VTlNQRUNJRklFRBAAEiIKHl'
    'BST1RPQ09MX0VSUk9SX0lOVkFMSURfUkVRVUVTVBABEiIKHlBST1RPQ09MX0VSUk9SX1VOQVVU'
    'SEVOVElDQVRFRBACEiYKIlBST1RPQ09MX0VSUk9SX1VOU1VQUE9SVEVEX1ZFUlNJT04QAxIlCi'
    'FQUk9UT0NPTF9FUlJPUl9SRVNPVVJDRV9FWEhBVVNURUQQBBIkCiBQUk9UT0NPTF9FUlJPUl9E'
    'RUFETElORV9FWENFRURFRBAFEhsKF1BST1RPQ09MX0VSUk9SX0lOVEVSTkFMEAYSIgoeUFJPVE'
    '9DT0xfRVJST1JfVU5LTk9XTl9PVVRDT01FEAcSJAogUFJPVE9DT0xfRVJST1JfU0VTU0lPTl9O'
    'T1RfRk9VTkQQCBIiCh5QUk9UT0NPTF9FUlJPUl9TRVNTSU9OX0VYUElSRUQQCQ==');

@$core.Deprecated('Use bytesDescriptor instead')
const Bytes$json = {
  '1': 'Bytes',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `Bytes`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List bytesDescriptor =
    $convert.base64Decode('CgVCeXRlcxISCgRkYXRhGAEgASgMUgRkYXRh');

@$core.Deprecated('Use loginRequestDescriptor instead')
const LoginRequest$json = {
  '1': 'LoginRequest',
  '2': [
    {
      '1': 'group_fingerprint',
      '3': 1,
      '4': 1,
      '5': 12,
      '10': 'groupFingerprint'
    },
    {'1': 'participant_id', '3': 2, '4': 1, '5': 12, '10': 'participantId'},
    {'1': 'protocol_version', '3': 3, '4': 1, '5': 13, '10': 'protocolVersion'},
  ],
};

/// Descriptor for `LoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginRequestDescriptor = $convert.base64Decode(
    'CgxMb2dpblJlcXVlc3QSKwoRZ3JvdXBfZmluZ2VycHJpbnQYASABKAxSEGdyb3VwRmluZ2VycH'
    'JpbnQSJQoOcGFydGljaXBhbnRfaWQYAiABKAxSDXBhcnRpY2lwYW50SWQSKQoQcHJvdG9jb2xf'
    'dmVyc2lvbhgDIAEoDVIPcHJvdG9jb2xWZXJzaW9u');

@$core.Deprecated('Use signedAuthChallengeDescriptor instead')
const SignedAuthChallenge$json = {
  '1': 'SignedAuthChallenge',
  '2': [
    {'1': 'signature', '3': 1, '4': 1, '5': 12, '10': 'signature'},
    {'1': 'challenge', '3': 2, '4': 1, '5': 12, '10': 'challenge'},
  ],
};

/// Descriptor for `SignedAuthChallenge`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signedAuthChallengeDescriptor = $convert.base64Decode(
    'ChNTaWduZWRBdXRoQ2hhbGxlbmdlEhwKCXNpZ25hdHVyZRgBIAEoDFIJc2lnbmF0dXJlEhwKCW'
    'NoYWxsZW5nZRgCIAEoDFIJY2hhbGxlbmdl');

@$core.Deprecated('Use dkgRequestDescriptor instead')
const DkgRequest$json = {
  '1': 'DkgRequest',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'signed_details', '3': 2, '4': 1, '5': 12, '10': 'signedDetails'},
    {'1': 'commitment', '3': 3, '4': 1, '5': 12, '10': 'commitment'},
  ],
};

/// Descriptor for `DkgRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgRequestDescriptor = $convert.base64Decode(
    'CgpEa2dSZXF1ZXN0EhAKA3NpZBgBIAEoDFIDc2lkEiUKDnNpZ25lZF9kZXRhaWxzGAIgASgMUg'
    '1zaWduZWREZXRhaWxzEh4KCmNvbW1pdG1lbnQYAyABKAxSCmNvbW1pdG1lbnQ=');

@$core.Deprecated('Use dkgToRejectDescriptor instead')
const DkgToReject$json = {
  '1': 'DkgToReject',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `DkgToReject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgToRejectDescriptor = $convert.base64Decode(
    'CgtEa2dUb1JlamVjdBIQCgNzaWQYASABKAxSA3NpZBISCgRuYW1lGAIgASgJUgRuYW1l');

@$core.Deprecated('Use dkgCommitmentDescriptor instead')
const DkgCommitment$json = {
  '1': 'DkgCommitment',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'commitment', '3': 3, '4': 1, '5': 12, '10': 'commitment'},
  ],
};

/// Descriptor for `DkgCommitment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgCommitmentDescriptor = $convert.base64Decode(
    'Cg1Ea2dDb21taXRtZW50EhAKA3NpZBgBIAEoDFIDc2lkEhIKBG5hbWUYAiABKAlSBG5hbWUSHg'
    'oKY29tbWl0bWVudBgDIAEoDFIKY29tbWl0bWVudA==');

@$core.Deprecated('Use dkgSecretDescriptor instead')
const DkgSecret$json = {
  '1': 'DkgSecret',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 12, '10': 'id'},
    {'1': 'secret', '3': 2, '4': 1, '5': 12, '10': 'secret'},
  ],
};

/// Descriptor for `DkgSecret`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgSecretDescriptor = $convert.base64Decode(
    'CglEa2dTZWNyZXQSDgoCaWQYASABKAxSAmlkEhYKBnNlY3JldBgCIAEoDFIGc2VjcmV0');

@$core.Deprecated('Use dkgRound2Descriptor instead')
const DkgRound2$json = {
  '1': 'DkgRound2',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'commitment_set_signature',
      '3': 3,
      '4': 1,
      '5': 12,
      '10': 'commitmentSetSignature'
    },
    {
      '1': 'secrets',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.noosphere.DkgSecret',
      '10': 'secrets'
    },
  ],
};

/// Descriptor for `DkgRound2`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgRound2Descriptor = $convert.base64Decode(
    'CglEa2dSb3VuZDISEAoDc2lkGAEgASgMUgNzaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRI4Chhjb2'
    '1taXRtZW50X3NldF9zaWduYXR1cmUYAyABKAxSFmNvbW1pdG1lbnRTZXRTaWduYXR1cmUSLgoH'
    'c2VjcmV0cxgEIAMoCzIULm5vb3NwaGVyZS5Ea2dTZWNyZXRSB3NlY3JldHM=');

@$core.Deprecated('Use dkgAcksDescriptor instead')
const DkgAcks$json = {
  '1': 'DkgAcks',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'acks', '3': 2, '4': 3, '5': 12, '10': 'acks'},
  ],
};

/// Descriptor for `DkgAcks`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgAcksDescriptor = $convert.base64Decode(
    'CgdEa2dBY2tzEhAKA3NpZBgBIAEoDFIDc2lkEhIKBGFja3MYAiADKAxSBGFja3M=');

@$core.Deprecated('Use dkgAckRequestDescriptor instead')
const DkgAckRequest$json = {
  '1': 'DkgAckRequest',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'requests', '3': 2, '4': 3, '5': 12, '10': 'requests'},
  ],
};

/// Descriptor for `DkgAckRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgAckRequestDescriptor = $convert.base64Decode(
    'Cg1Ea2dBY2tSZXF1ZXN0EhAKA3NpZBgBIAEoDFIDc2lkEhoKCHJlcXVlc3RzGAIgAygMUghyZX'
    'F1ZXN0cw==');

@$core.Deprecated('Use signaturesRequestDescriptor instead')
const SignaturesRequest$json = {
  '1': 'SignaturesRequest',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'keys', '3': 2, '4': 3, '5': 12, '10': 'keys'},
    {'1': 'signed_details', '3': 3, '4': 1, '5': 12, '10': 'signedDetails'},
    {'1': 'commitments', '3': 4, '4': 3, '5': 12, '10': 'commitments'},
  ],
};

/// Descriptor for `SignaturesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signaturesRequestDescriptor = $convert.base64Decode(
    'ChFTaWduYXR1cmVzUmVxdWVzdBIQCgNzaWQYASABKAxSA3NpZBISCgRrZXlzGAIgAygMUgRrZX'
    'lzEiUKDnNpZ25lZF9kZXRhaWxzGAMgASgMUg1zaWduZWREZXRhaWxzEiAKC2NvbW1pdG1lbnRz'
    'GAQgAygMUgtjb21taXRtZW50cw==');

@$core.Deprecated('Use signaturesRejectionDescriptor instead')
const SignaturesRejection$json = {
  '1': 'SignaturesRejection',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'req_id', '3': 2, '4': 1, '5': 12, '10': 'reqId'},
  ],
};

/// Descriptor for `SignaturesRejection`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signaturesRejectionDescriptor = $convert.base64Decode(
    'ChNTaWduYXR1cmVzUmVqZWN0aW9uEhAKA3NpZBgBIAEoDFIDc2lkEhUKBnJlcV9pZBgCIAEoDF'
    'IFcmVxSWQ=');

@$core.Deprecated('Use signaturesRepliesDescriptor instead')
const SignaturesReplies$json = {
  '1': 'SignaturesReplies',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'req_id', '3': 2, '4': 1, '5': 12, '10': 'reqId'},
    {'1': 'replies', '3': 3, '4': 3, '5': 12, '10': 'replies'},
  ],
};

/// Descriptor for `SignaturesReplies`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signaturesRepliesDescriptor = $convert.base64Decode(
    'ChFTaWduYXR1cmVzUmVwbGllcxIQCgNzaWQYASABKAxSA3NpZBIVCgZyZXFfaWQYAiABKAxSBX'
    'JlcUlkEhgKB3JlcGxpZXMYAyADKAxSB3JlcGxpZXM=');

@$core.Deprecated('Use encryptedSecretDescriptor instead')
const EncryptedSecret$json = {
  '1': 'EncryptedSecret',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 12, '10': 'id'},
    {'1': 'share', '3': 2, '4': 1, '5': 12, '10': 'share'},
  ],
};

/// Descriptor for `EncryptedSecret`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List encryptedSecretDescriptor = $convert.base64Decode(
    'Cg9FbmNyeXB0ZWRTZWNyZXQSDgoCaWQYASABKAxSAmlkEhQKBXNoYXJlGAIgASgMUgVzaGFyZQ'
    '==');

@$core.Deprecated('Use secretShareDescriptor instead')
const SecretShare$json = {
  '1': 'SecretShare',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'group_key', '3': 2, '4': 1, '5': 12, '10': 'groupKey'},
    {
      '1': 'secrets',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.noosphere.EncryptedSecret',
      '10': 'secrets'
    },
  ],
};

/// Descriptor for `SecretShare`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List secretShareDescriptor = $convert.base64Decode(
    'CgtTZWNyZXRTaGFyZRIQCgNzaWQYASABKAxSA3NpZBIbCglncm91cF9rZXkYAiABKAxSCGdyb3'
    'VwS2V5EjQKB3NlY3JldHMYAyADKAsyGi5ub29zcGhlcmUuRW5jcnlwdGVkU2VjcmV0UgdzZWNy'
    'ZXRz');

@$core.Deprecated('Use constructedKeyDescriptor instead')
const ConstructedKey$json = {
  '1': 'ConstructedKey',
  '2': [
    {'1': 'sid', '3': 1, '4': 1, '5': 12, '10': 'sid'},
    {'1': 'constructed_key', '3': 2, '4': 1, '5': 12, '10': 'constructedKey'},
  ],
};

/// Descriptor for `ConstructedKey`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List constructedKeyDescriptor = $convert.base64Decode(
    'Cg5Db25zdHJ1Y3RlZEtleRIQCgNzaWQYASABKAxSA3NpZBInCg9jb25zdHJ1Y3RlZF9rZXkYAi'
    'ABKAxSDmNvbnN0cnVjdGVkS2V5');

@$core.Deprecated('Use participantStatusEventDescriptor instead')
const ParticipantStatusEvent$json = {
  '1': 'ParticipantStatusEvent',
  '2': [
    {'1': 'participant_id', '3': 1, '4': 1, '5': 12, '10': 'participantId'},
    {'1': 'logged_in', '3': 2, '4': 1, '5': 8, '10': 'loggedIn'},
  ],
};

/// Descriptor for `ParticipantStatusEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List participantStatusEventDescriptor =
    $convert.base64Decode(
        'ChZQYXJ0aWNpcGFudFN0YXR1c0V2ZW50EiUKDnBhcnRpY2lwYW50X2lkGAEgASgMUg1wYXJ0aW'
        'NpcGFudElkEhsKCWxvZ2dlZF9pbhgCIAEoCFIIbG9nZ2VkSW4=');

@$core.Deprecated('Use dkgEventCommitmentDescriptor instead')
const DkgEventCommitment$json = {
  '1': 'DkgEventCommitment',
  '2': [
    {'1': 'participant_id', '3': 1, '4': 1, '5': 12, '10': 'participantId'},
    {'1': 'commitment', '3': 2, '4': 1, '5': 12, '10': 'commitment'},
  ],
};

/// Descriptor for `DkgEventCommitment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgEventCommitmentDescriptor = $convert.base64Decode(
    'ChJEa2dFdmVudENvbW1pdG1lbnQSJQoOcGFydGljaXBhbnRfaWQYASABKAxSDXBhcnRpY2lwYW'
    '50SWQSHgoKY29tbWl0bWVudBgCIAEoDFIKY29tbWl0bWVudA==');

@$core.Deprecated('Use newDkgEventDescriptor instead')
const NewDkgEvent$json = {
  '1': 'NewDkgEvent',
  '2': [
    {'1': 'signed_details', '3': 1, '4': 1, '5': 12, '10': 'signedDetails'},
    {'1': 'creator_id', '3': 2, '4': 1, '5': 12, '10': 'creatorId'},
    {
      '1': 'commitments',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.noosphere.DkgEventCommitment',
      '10': 'commitments'
    },
  ],
};

/// Descriptor for `NewDkgEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List newDkgEventDescriptor = $convert.base64Decode(
    'CgtOZXdEa2dFdmVudBIlCg5zaWduZWRfZGV0YWlscxgBIAEoDFINc2lnbmVkRGV0YWlscxIdCg'
    'pjcmVhdG9yX2lkGAIgASgMUgljcmVhdG9ySWQSPwoLY29tbWl0bWVudHMYAyADKAsyHS5ub29z'
    'cGhlcmUuRGtnRXZlbnRDb21taXRtZW50Ugtjb21taXRtZW50cw==');

@$core.Deprecated('Use dkgCommitmentEventDescriptor instead')
const DkgCommitmentEvent$json = {
  '1': 'DkgCommitmentEvent',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'participant_id', '3': 2, '4': 1, '5': 12, '10': 'participantId'},
    {'1': 'commitment', '3': 3, '4': 1, '5': 12, '10': 'commitment'},
  ],
};

/// Descriptor for `DkgCommitmentEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgCommitmentEventDescriptor = $convert.base64Decode(
    'ChJEa2dDb21taXRtZW50RXZlbnQSEgoEbmFtZRgBIAEoCVIEbmFtZRIlCg5wYXJ0aWNpcGFudF'
    '9pZBgCIAEoDFINcGFydGljaXBhbnRJZBIeCgpjb21taXRtZW50GAMgASgMUgpjb21taXRtZW50');

@$core.Deprecated('Use dkgRejectEventDescriptor instead')
const DkgRejectEvent$json = {
  '1': 'DkgRejectEvent',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'participant_id', '3': 2, '4': 1, '5': 12, '10': 'participantId'},
  ],
};

/// Descriptor for `DkgRejectEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgRejectEventDescriptor = $convert.base64Decode(
    'Cg5Ea2dSZWplY3RFdmVudBISCgRuYW1lGAEgASgJUgRuYW1lEiUKDnBhcnRpY2lwYW50X2lkGA'
    'IgASgMUg1wYXJ0aWNpcGFudElk');

@$core.Deprecated('Use dkgRound2ShareEventDescriptor instead')
const DkgRound2ShareEvent$json = {
  '1': 'DkgRound2ShareEvent',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'commitment_set_signature',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'commitmentSetSignature'
    },
    {'1': 'sender_id', '3': 3, '4': 1, '5': 12, '10': 'senderId'},
    {'1': 'encrypted_secret', '3': 4, '4': 1, '5': 12, '10': 'encryptedSecret'},
  ],
};

/// Descriptor for `DkgRound2ShareEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgRound2ShareEventDescriptor = $convert.base64Decode(
    'ChNEa2dSb3VuZDJTaGFyZUV2ZW50EhIKBG5hbWUYASABKAlSBG5hbWUSOAoYY29tbWl0bWVudF'
    '9zZXRfc2lnbmF0dXJlGAIgASgMUhZjb21taXRtZW50U2V0U2lnbmF0dXJlEhsKCXNlbmRlcl9p'
    'ZBgDIAEoDFIIc2VuZGVySWQSKQoQZW5jcnlwdGVkX3NlY3JldBgEIAEoDFIPZW5jcnlwdGVkU2'
    'VjcmV0');

@$core.Deprecated('Use dkgAckEventDescriptor instead')
const DkgAckEvent$json = {
  '1': 'DkgAckEvent',
  '2': [
    {'1': 'acks', '3': 1, '4': 3, '5': 12, '10': 'acks'},
  ],
};

/// Descriptor for `DkgAckEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgAckEventDescriptor =
    $convert.base64Decode('CgtEa2dBY2tFdmVudBISCgRhY2tzGAEgAygMUgRhY2tz');

@$core.Deprecated('Use dkgAckRequestEventDescriptor instead')
const DkgAckRequestEvent$json = {
  '1': 'DkgAckRequestEvent',
  '2': [
    {'1': 'requests', '3': 1, '4': 3, '5': 12, '10': 'requests'},
  ],
};

/// Descriptor for `DkgAckRequestEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dkgAckRequestEventDescriptor =
    $convert.base64Decode(
        'ChJEa2dBY2tSZXF1ZXN0RXZlbnQSGgoIcmVxdWVzdHMYASADKAxSCHJlcXVlc3Rz');

@$core.Deprecated('Use signaturesProgressDescriptor instead')
const SignaturesProgress$json = {
  '1': 'SignaturesProgress',
  '2': [
    {'1': 'threshold', '3': 1, '4': 1, '5': 13, '10': 'threshold'},
    {
      '1': 'contributing_participant_ids',
      '3': 2,
      '4': 3,
      '5': 12,
      '10': 'contributingParticipantIds'
    },
    {
      '1': 'stage',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.noosphere.SignaturesProgressStage',
      '9': 0,
      '10': 'stage',
      '17': true
    },
  ],
  '8': [
    {'1': '_stage'},
  ],
};

/// Descriptor for `SignaturesProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signaturesProgressDescriptor = $convert.base64Decode(
    'ChJTaWduYXR1cmVzUHJvZ3Jlc3MSHAoJdGhyZXNob2xkGAEgASgNUgl0aHJlc2hvbGQSQAocY2'
    '9udHJpYnV0aW5nX3BhcnRpY2lwYW50X2lkcxgCIAMoDFIaY29udHJpYnV0aW5nUGFydGljaXBh'
    'bnRJZHMSPQoFc3RhZ2UYAyABKA4yIi5ub29zcGhlcmUuU2lnbmF0dXJlc1Byb2dyZXNzU3RhZ2'
    'VIAFIFc3RhZ2WIAQFCCAoGX3N0YWdl');

@$core.Deprecated('Use signaturesRequestEventDescriptor instead')
const SignaturesRequestEvent$json = {
  '1': 'SignaturesRequestEvent',
  '2': [
    {'1': 'signed_details', '3': 1, '4': 1, '5': 12, '10': 'signedDetails'},
    {'1': 'creator_id', '3': 2, '4': 1, '5': 12, '10': 'creatorId'},
    {
      '1': 'progress',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesProgress',
      '10': 'progress'
    },
  ],
};

/// Descriptor for `SignaturesRequestEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signaturesRequestEventDescriptor = $convert.base64Decode(
    'ChZTaWduYXR1cmVzUmVxdWVzdEV2ZW50EiUKDnNpZ25lZF9kZXRhaWxzGAEgASgMUg1zaWduZW'
    'REZXRhaWxzEh0KCmNyZWF0b3JfaWQYAiABKAxSCWNyZWF0b3JJZBI5Cghwcm9ncmVzcxgDIAEo'
    'CzIdLm5vb3NwaGVyZS5TaWduYXR1cmVzUHJvZ3Jlc3NSCHByb2dyZXNz');

@$core.Deprecated('Use signatureRoundStartDescriptor instead')
const SignatureRoundStart$json = {
  '1': 'SignatureRoundStart',
  '2': [
    {'1': 'signature_index', '3': 1, '4': 1, '5': 13, '10': 'signatureIndex'},
    {'1': 'commitment_set', '3': 2, '4': 1, '5': 12, '10': 'commitmentSet'},
  ],
};

/// Descriptor for `SignatureRoundStart`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signatureRoundStartDescriptor = $convert.base64Decode(
    'ChNTaWduYXR1cmVSb3VuZFN0YXJ0EicKD3NpZ25hdHVyZV9pbmRleBgBIAEoDVIOc2lnbmF0dX'
    'JlSW5kZXgSJQoOY29tbWl0bWVudF9zZXQYAiABKAxSDWNvbW1pdG1lbnRTZXQ=');

@$core.Deprecated('Use signatureNewRoundsEventDescriptor instead')
const SignatureNewRoundsEvent$json = {
  '1': 'SignatureNewRoundsEvent',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 12, '10': 'requestId'},
    {
      '1': 'rounds',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.noosphere.SignatureRoundStart',
      '10': 'rounds'
    },
  ],
};

/// Descriptor for `SignatureNewRoundsEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signatureNewRoundsEventDescriptor = $convert.base64Decode(
    'ChdTaWduYXR1cmVOZXdSb3VuZHNFdmVudBIdCgpyZXF1ZXN0X2lkGAEgASgMUglyZXF1ZXN0SW'
    'QSNgoGcm91bmRzGAIgAygLMh4ubm9vc3BoZXJlLlNpZ25hdHVyZVJvdW5kU3RhcnRSBnJvdW5k'
    'cw==');

@$core.Deprecated('Use signaturesCompleteEventDescriptor instead')
const SignaturesCompleteEvent$json = {
  '1': 'SignaturesCompleteEvent',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 12, '10': 'requestId'},
    {'1': 'signatures', '3': 2, '4': 3, '5': 12, '10': 'signatures'},
  ],
};

/// Descriptor for `SignaturesCompleteEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signaturesCompleteEventDescriptor =
    $convert.base64Decode(
        'ChdTaWduYXR1cmVzQ29tcGxldGVFdmVudBIdCgpyZXF1ZXN0X2lkGAEgASgMUglyZXF1ZXN0SW'
        'QSHgoKc2lnbmF0dXJlcxgCIAMoDFIKc2lnbmF0dXJlcw==');

@$core.Deprecated('Use signaturesFailureEventDescriptor instead')
const SignaturesFailureEvent$json = {
  '1': 'SignaturesFailureEvent',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 12, '10': 'requestId'},
  ],
};

/// Descriptor for `SignaturesFailureEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signaturesFailureEventDescriptor =
    $convert.base64Decode(
        'ChZTaWduYXR1cmVzRmFpbHVyZUV2ZW50Eh0KCnJlcXVlc3RfaWQYASABKAxSCXJlcXVlc3RJZA'
        '==');

@$core.Deprecated('Use keepaliveEventDescriptor instead')
const KeepaliveEvent$json = {
  '1': 'KeepaliveEvent',
};

/// Descriptor for `KeepaliveEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keepaliveEventDescriptor =
    $convert.base64Decode('Cg5LZWVwYWxpdmVFdmVudA==');

@$core.Deprecated('Use secretShareEventDescriptor instead')
const SecretShareEvent$json = {
  '1': 'SecretShareEvent',
  '2': [
    {'1': 'sender_id', '3': 1, '4': 1, '5': 12, '10': 'senderId'},
    {'1': 'group_key', '3': 2, '4': 1, '5': 12, '10': 'groupKey'},
    {
      '1': 'encrypted_key_share',
      '3': 3,
      '4': 1,
      '5': 12,
      '10': 'encryptedKeyShare'
    },
  ],
};

/// Descriptor for `SecretShareEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List secretShareEventDescriptor = $convert.base64Decode(
    'ChBTZWNyZXRTaGFyZUV2ZW50EhsKCXNlbmRlcl9pZBgBIAEoDFIIc2VuZGVySWQSGwoJZ3JvdX'
    'Bfa2V5GAIgASgMUghncm91cEtleRIuChNlbmNyeXB0ZWRfa2V5X3NoYXJlGAMgASgMUhFlbmNy'
    'eXB0ZWRLZXlTaGFyZQ==');

@$core.Deprecated('Use constructedKeyEventDescriptor instead')
const ConstructedKeyEvent$json = {
  '1': 'ConstructedKeyEvent',
  '2': [
    {'1': 'participant_id', '3': 1, '4': 1, '5': 12, '10': 'participantId'},
    {
      '1': 'signed_constructed_key',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'signedConstructedKey'
    },
  ],
};

/// Descriptor for `ConstructedKeyEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List constructedKeyEventDescriptor = $convert.base64Decode(
    'ChNDb25zdHJ1Y3RlZEtleUV2ZW50EiUKDnBhcnRpY2lwYW50X2lkGAEgASgMUg1wYXJ0aWNpcG'
    'FudElkEjQKFnNpZ25lZF9jb25zdHJ1Y3RlZF9rZXkYAiABKAxSFHNpZ25lZENvbnN0cnVjdGVk'
    'S2V5');

@$core.Deprecated('Use signaturesProgressEventDescriptor instead')
const SignaturesProgressEvent$json = {
  '1': 'SignaturesProgressEvent',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 12, '10': 'requestId'},
    {
      '1': 'progress',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesProgress',
      '10': 'progress'
    },
  ],
};

/// Descriptor for `SignaturesProgressEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signaturesProgressEventDescriptor = $convert.base64Decode(
    'ChdTaWduYXR1cmVzUHJvZ3Jlc3NFdmVudBIdCgpyZXF1ZXN0X2lkGAEgASgMUglyZXF1ZXN0SW'
    'QSOQoIcHJvZ3Jlc3MYAiABKAsyHS5ub29zcGhlcmUuU2lnbmF0dXJlc1Byb2dyZXNzUghwcm9n'
    'cmVzcw==');

@$core.Deprecated('Use eventMessageDescriptor instead')
const EventMessage$json = {
  '1': 'EventMessage',
  '2': [
    {
      '1': 'participant_status',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.ParticipantStatusEvent',
      '9': 0,
      '10': 'participantStatus'
    },
    {
      '1': 'new_dkg',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.noosphere.NewDkgEvent',
      '9': 0,
      '10': 'newDkg'
    },
    {
      '1': 'dkg_commitment',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgCommitmentEvent',
      '9': 0,
      '10': 'dkgCommitment'
    },
    {
      '1': 'dkg_reject',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgRejectEvent',
      '9': 0,
      '10': 'dkgReject'
    },
    {
      '1': 'dkg_round2_share',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgRound2ShareEvent',
      '9': 0,
      '10': 'dkgRound2Share'
    },
    {
      '1': 'dkg_ack',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgAckEvent',
      '9': 0,
      '10': 'dkgAck'
    },
    {
      '1': 'dkg_ack_request',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgAckRequestEvent',
      '9': 0,
      '10': 'dkgAckRequest'
    },
    {
      '1': 'signatures_request',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesRequestEvent',
      '9': 0,
      '10': 'signaturesRequest'
    },
    {
      '1': 'signature_new_rounds',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignatureNewRoundsEvent',
      '9': 0,
      '10': 'signatureNewRounds'
    },
    {
      '1': 'signatures_complete',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesCompleteEvent',
      '9': 0,
      '10': 'signaturesComplete'
    },
    {
      '1': 'signatures_failure',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesFailureEvent',
      '9': 0,
      '10': 'signaturesFailure'
    },
    {
      '1': 'keepalive',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.noosphere.KeepaliveEvent',
      '9': 0,
      '10': 'keepalive'
    },
    {
      '1': 'secret_share',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SecretShareEvent',
      '9': 0,
      '10': 'secretShare'
    },
    {
      '1': 'constructed_key',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.noosphere.ConstructedKeyEvent',
      '9': 0,
      '10': 'constructedKey'
    },
    {
      '1': 'signatures_progress',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesProgressEvent',
      '9': 0,
      '10': 'signaturesProgress'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `EventMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventMessageDescriptor = $convert.base64Decode(
    'CgxFdmVudE1lc3NhZ2USUgoScGFydGljaXBhbnRfc3RhdHVzGAEgASgLMiEubm9vc3BoZXJlLl'
    'BhcnRpY2lwYW50U3RhdHVzRXZlbnRIAFIRcGFydGljaXBhbnRTdGF0dXMSMQoHbmV3X2RrZxgC'
    'IAEoCzIWLm5vb3NwaGVyZS5OZXdEa2dFdmVudEgAUgZuZXdEa2cSRgoOZGtnX2NvbW1pdG1lbn'
    'QYAyABKAsyHS5ub29zcGhlcmUuRGtnQ29tbWl0bWVudEV2ZW50SABSDWRrZ0NvbW1pdG1lbnQS'
    'OgoKZGtnX3JlamVjdBgEIAEoCzIZLm5vb3NwaGVyZS5Ea2dSZWplY3RFdmVudEgAUglka2dSZW'
    'plY3QSSgoQZGtnX3JvdW5kMl9zaGFyZRgFIAEoCzIeLm5vb3NwaGVyZS5Ea2dSb3VuZDJTaGFy'
    'ZUV2ZW50SABSDmRrZ1JvdW5kMlNoYXJlEjEKB2RrZ19hY2sYBiABKAsyFi5ub29zcGhlcmUuRG'
    'tnQWNrRXZlbnRIAFIGZGtnQWNrEkcKD2RrZ19hY2tfcmVxdWVzdBgHIAEoCzIdLm5vb3NwaGVy'
    'ZS5Ea2dBY2tSZXF1ZXN0RXZlbnRIAFINZGtnQWNrUmVxdWVzdBJSChJzaWduYXR1cmVzX3JlcX'
    'Vlc3QYCCABKAsyIS5ub29zcGhlcmUuU2lnbmF0dXJlc1JlcXVlc3RFdmVudEgAUhFzaWduYXR1'
    'cmVzUmVxdWVzdBJWChRzaWduYXR1cmVfbmV3X3JvdW5kcxgJIAEoCzIiLm5vb3NwaGVyZS5TaW'
    'duYXR1cmVOZXdSb3VuZHNFdmVudEgAUhJzaWduYXR1cmVOZXdSb3VuZHMSVQoTc2lnbmF0dXJl'
    'c19jb21wbGV0ZRgKIAEoCzIiLm5vb3NwaGVyZS5TaWduYXR1cmVzQ29tcGxldGVFdmVudEgAUh'
    'JzaWduYXR1cmVzQ29tcGxldGUSUgoSc2lnbmF0dXJlc19mYWlsdXJlGAsgASgLMiEubm9vc3Bo'
    'ZXJlLlNpZ25hdHVyZXNGYWlsdXJlRXZlbnRIAFIRc2lnbmF0dXJlc0ZhaWx1cmUSOQoJa2VlcG'
    'FsaXZlGAwgASgLMhkubm9vc3BoZXJlLktlZXBhbGl2ZUV2ZW50SABSCWtlZXBhbGl2ZRJACgxz'
    'ZWNyZXRfc2hhcmUYDSABKAsyGy5ub29zcGhlcmUuU2VjcmV0U2hhcmVFdmVudEgAUgtzZWNyZX'
    'RTaGFyZRJJCg9jb25zdHJ1Y3RlZF9rZXkYDiABKAsyHi5ub29zcGhlcmUuQ29uc3RydWN0ZWRL'
    'ZXlFdmVudEgAUg5jb25zdHJ1Y3RlZEtleRJVChNzaWduYXR1cmVzX3Byb2dyZXNzGA8gASgLMi'
    'Iubm9vc3BoZXJlLlNpZ25hdHVyZXNQcm9ncmVzc0V2ZW50SABSEnNpZ25hdHVyZXNQcm9ncmVz'
    'c0IHCgVldmVudA==');

@$core.Deprecated('Use protocolErrorDescriptor instead')
const ProtocolError$json = {
  '1': 'ProtocolError',
  '2': [
    {
      '1': 'code',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.noosphere.ProtocolErrorCode',
      '10': 'code'
    },
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'retryable', '3': 3, '4': 1, '5': 8, '10': 'retryable'},
    {
      '1': 'room_failure_code',
      '3': 4,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'roomFailureCode',
      '17': true
    },
  ],
  '8': [
    {'1': '_room_failure_code'},
  ],
};

/// Descriptor for `ProtocolError`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolErrorDescriptor = $convert.base64Decode(
    'Cg1Qcm90b2NvbEVycm9yEjAKBGNvZGUYASABKA4yHC5ub29zcGhlcmUuUHJvdG9jb2xFcnJvck'
    'NvZGVSBGNvZGUSGAoHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZRIcCglyZXRyeWFibGUYAyABKAhS'
    'CXJldHJ5YWJsZRIvChFyb29tX2ZhaWx1cmVfY29kZRgEIAEoDUgAUg9yb29tRmFpbHVyZUNvZG'
    'WIAQFCFAoSX3Jvb21fZmFpbHVyZV9jb2Rl');

@$core.Deprecated('Use emptySuccessDescriptor instead')
const EmptySuccess$json = {
  '1': 'EmptySuccess',
};

/// Descriptor for `EmptySuccess`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptySuccessDescriptor =
    $convert.base64Decode('CgxFbXB0eVN1Y2Nlc3M=');

@$core.Deprecated('Use loginResponseDescriptor instead')
const LoginResponse$json = {
  '1': 'LoginResponse',
  '2': [
    {'1': 'challenge', '3': 1, '4': 1, '5': 12, '10': 'challenge'},
  ],
};

/// Descriptor for `LoginResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginResponseDescriptor = $convert.base64Decode(
    'Cg1Mb2dpblJlc3BvbnNlEhwKCWNoYWxsZW5nZRgBIAEoDFIJY2hhbGxlbmdl');

@$core.Deprecated('Use respondToChallengeResponseDescriptor instead')
const RespondToChallengeResponse$json = {
  '1': 'RespondToChallengeResponse',
  '2': [
    {
      '1': 'authenticated',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'authenticated'
    },
  ],
};

/// Descriptor for `RespondToChallengeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List respondToChallengeResponseDescriptor =
    $convert.base64Decode(
        'ChpSZXNwb25kVG9DaGFsbGVuZ2VSZXNwb25zZRI9Cg1hdXRoZW50aWNhdGVkGAEgASgLMhcubm'
        '9vc3BoZXJlLkVtcHR5U3VjY2Vzc1INYXV0aGVudGljYXRlZA==');

@$core.Deprecated('Use extendSessionResponseDescriptor instead')
const ExtendSessionResponse$json = {
  '1': 'ExtendSessionResponse',
  '2': [
    {'1': 'expiry', '3': 1, '4': 1, '5': 12, '10': 'expiry'},
  ],
};

/// Descriptor for `ExtendSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List extendSessionResponseDescriptor =
    $convert.base64Decode(
        'ChVFeHRlbmRTZXNzaW9uUmVzcG9uc2USFgoGZXhwaXJ5GAEgASgMUgZleHBpcnk=');

@$core.Deprecated('Use requestNewDkgResponseDescriptor instead')
const RequestNewDkgResponse$json = {
  '1': 'RequestNewDkgResponse',
  '2': [
    {
      '1': 'success',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'success'
    },
  ],
};

/// Descriptor for `RequestNewDkgResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestNewDkgResponseDescriptor = $convert.base64Decode(
    'ChVSZXF1ZXN0TmV3RGtnUmVzcG9uc2USMQoHc3VjY2VzcxgBIAEoCzIXLm5vb3NwaGVyZS5FbX'
    'B0eVN1Y2Nlc3NSB3N1Y2Nlc3M=');

@$core.Deprecated('Use rejectDkgResponseDescriptor instead')
const RejectDkgResponse$json = {
  '1': 'RejectDkgResponse',
  '2': [
    {
      '1': 'success',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'success'
    },
  ],
};

/// Descriptor for `RejectDkgResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rejectDkgResponseDescriptor = $convert.base64Decode(
    'ChFSZWplY3REa2dSZXNwb25zZRIxCgdzdWNjZXNzGAEgASgLMhcubm9vc3BoZXJlLkVtcHR5U3'
    'VjY2Vzc1IHc3VjY2Vzcw==');

@$core.Deprecated('Use submitDkgCommitmentResponseDescriptor instead')
const SubmitDkgCommitmentResponse$json = {
  '1': 'SubmitDkgCommitmentResponse',
  '2': [
    {
      '1': 'success',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'success'
    },
  ],
};

/// Descriptor for `SubmitDkgCommitmentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitDkgCommitmentResponseDescriptor =
    $convert.base64Decode(
        'ChtTdWJtaXREa2dDb21taXRtZW50UmVzcG9uc2USMQoHc3VjY2VzcxgBIAEoCzIXLm5vb3NwaG'
        'VyZS5FbXB0eVN1Y2Nlc3NSB3N1Y2Nlc3M=');

@$core.Deprecated('Use submitDkgRound2ResponseDescriptor instead')
const SubmitDkgRound2Response$json = {
  '1': 'SubmitDkgRound2Response',
  '2': [
    {
      '1': 'success',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'success'
    },
  ],
};

/// Descriptor for `SubmitDkgRound2Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitDkgRound2ResponseDescriptor =
    $convert.base64Decode(
        'ChdTdWJtaXREa2dSb3VuZDJSZXNwb25zZRIxCgdzdWNjZXNzGAEgASgLMhcubm9vc3BoZXJlLk'
        'VtcHR5U3VjY2Vzc1IHc3VjY2Vzcw==');

@$core.Deprecated('Use sendDkgAcksResponseDescriptor instead')
const SendDkgAcksResponse$json = {
  '1': 'SendDkgAcksResponse',
  '2': [
    {
      '1': 'success',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'success'
    },
  ],
};

/// Descriptor for `SendDkgAcksResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendDkgAcksResponseDescriptor = $convert.base64Decode(
    'ChNTZW5kRGtnQWNrc1Jlc3BvbnNlEjEKB3N1Y2Nlc3MYASABKAsyFy5ub29zcGhlcmUuRW1wdH'
    'lTdWNjZXNzUgdzdWNjZXNz');

@$core.Deprecated('Use requestDkgAcksResponseDescriptor instead')
const RequestDkgAcksResponse$json = {
  '1': 'RequestDkgAcksResponse',
  '2': [
    {'1': 'acks', '3': 1, '4': 3, '5': 12, '10': 'acks'},
  ],
};

/// Descriptor for `RequestDkgAcksResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestDkgAcksResponseDescriptor =
    $convert.base64Decode(
        'ChZSZXF1ZXN0RGtnQWNrc1Jlc3BvbnNlEhIKBGFja3MYASADKAxSBGFja3M=');

@$core.Deprecated('Use requestSignaturesResponseDescriptor instead')
const RequestSignaturesResponse$json = {
  '1': 'RequestSignaturesResponse',
  '2': [
    {
      '1': 'success',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'success'
    },
  ],
};

/// Descriptor for `RequestSignaturesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestSignaturesResponseDescriptor =
    $convert.base64Decode(
        'ChlSZXF1ZXN0U2lnbmF0dXJlc1Jlc3BvbnNlEjEKB3N1Y2Nlc3MYASABKAsyFy5ub29zcGhlcm'
        'UuRW1wdHlTdWNjZXNzUgdzdWNjZXNz');

@$core.Deprecated('Use rejectSignaturesRequestResponseDescriptor instead')
const RejectSignaturesRequestResponse$json = {
  '1': 'RejectSignaturesRequestResponse',
  '2': [
    {
      '1': 'success',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'success'
    },
  ],
};

/// Descriptor for `RejectSignaturesRequestResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rejectSignaturesRequestResponseDescriptor =
    $convert.base64Decode(
        'Ch9SZWplY3RTaWduYXR1cmVzUmVxdWVzdFJlc3BvbnNlEjEKB3N1Y2Nlc3MYASABKAsyFy5ub2'
        '9zcGhlcmUuRW1wdHlTdWNjZXNzUgdzdWNjZXNz');

@$core.Deprecated('Use noSignatureUpdateDescriptor instead')
const NoSignatureUpdate$json = {
  '1': 'NoSignatureUpdate',
};

/// Descriptor for `NoSignatureUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List noSignatureUpdateDescriptor =
    $convert.base64Decode('ChFOb1NpZ25hdHVyZVVwZGF0ZQ==');

@$core.Deprecated('Use newSignatureRoundDescriptor instead')
const NewSignatureRound$json = {
  '1': 'NewSignatureRound',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `NewSignatureRound`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List newSignatureRoundDescriptor = $convert
    .base64Decode('ChFOZXdTaWduYXR1cmVSb3VuZBISCgRkYXRhGAEgASgMUgRkYXRh');

@$core.Deprecated('Use completedSignaturesDescriptor instead')
const CompletedSignatures$json = {
  '1': 'CompletedSignatures',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `CompletedSignatures`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completedSignaturesDescriptor = $convert
    .base64Decode('ChNDb21wbGV0ZWRTaWduYXR1cmVzEhIKBGRhdGEYASABKAxSBGRhdGE=');

@$core.Deprecated('Use submitSignatureRepliesResponseDescriptor instead')
const SubmitSignatureRepliesResponse$json = {
  '1': 'SubmitSignatureRepliesResponse',
  '2': [
    {
      '1': 'no_update',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.NoSignatureUpdate',
      '9': 0,
      '10': 'noUpdate'
    },
    {
      '1': 'new_round',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.noosphere.NewSignatureRound',
      '9': 0,
      '10': 'newRound'
    },
    {
      '1': 'completed',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.noosphere.CompletedSignatures',
      '9': 0,
      '10': 'completed'
    },
  ],
  '8': [
    {'1': 'outcome'},
  ],
};

/// Descriptor for `SubmitSignatureRepliesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitSignatureRepliesResponseDescriptor = $convert.base64Decode(
    'Ch5TdWJtaXRTaWduYXR1cmVSZXBsaWVzUmVzcG9uc2USOwoJbm9fdXBkYXRlGAEgASgLMhwubm'
    '9vc3BoZXJlLk5vU2lnbmF0dXJlVXBkYXRlSABSCG5vVXBkYXRlEjsKCW5ld19yb3VuZBgCIAEo'
    'CzIcLm5vb3NwaGVyZS5OZXdTaWduYXR1cmVSb3VuZEgAUghuZXdSb3VuZBI+Cgljb21wbGV0ZW'
    'QYAyABKAsyHi5ub29zcGhlcmUuQ29tcGxldGVkU2lnbmF0dXJlc0gAUgljb21wbGV0ZWRCCQoH'
    'b3V0Y29tZQ==');

@$core.Deprecated('Use shareSecretShareResponseDescriptor instead')
const ShareSecretShareResponse$json = {
  '1': 'ShareSecretShareResponse',
  '2': [
    {
      '1': 'constructed_key_events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.noosphere.ConstructedKeyEvent',
      '10': 'constructedKeyEvents'
    },
  ],
};

/// Descriptor for `ShareSecretShareResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareSecretShareResponseDescriptor = $convert.base64Decode(
    'ChhTaGFyZVNlY3JldFNoYXJlUmVzcG9uc2USVAoWY29uc3RydWN0ZWRfa2V5X2V2ZW50cxgBIA'
    'MoCzIeLm5vb3NwaGVyZS5Db25zdHJ1Y3RlZEtleUV2ZW50UhRjb25zdHJ1Y3RlZEtleUV2ZW50'
    'cw==');

@$core.Deprecated('Use ackKeyConstructedResponseDescriptor instead')
const AckKeyConstructedResponse$json = {
  '1': 'AckKeyConstructedResponse',
  '2': [
    {
      '1': 'success',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EmptySuccess',
      '10': 'success'
    },
  ],
};

/// Descriptor for `AckKeyConstructedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ackKeyConstructedResponseDescriptor =
    $convert.base64Decode(
        'ChlBY2tLZXlDb25zdHJ1Y3RlZFJlc3BvbnNlEjEKB3N1Y2Nlc3MYASABKAsyFy5ub29zcGhlcm'
        'UuRW1wdHlTdWNjZXNzUgdzdWNjZXNz');

@$core.Deprecated('Use beginEnrollmentRequestDescriptor instead')
const BeginEnrollmentRequest$json = {
  '1': 'BeginEnrollmentRequest',
  '2': [
    {'1': 'invite', '3': 1, '4': 1, '5': 12, '10': 'invite'},
    {
      '1': 'participant_public_key',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'participantPublicKey'
    },
  ],
};

/// Descriptor for `BeginEnrollmentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beginEnrollmentRequestDescriptor =
    $convert.base64Decode(
        'ChZCZWdpbkVucm9sbG1lbnRSZXF1ZXN0EhYKBmludml0ZRgBIAEoDFIGaW52aXRlEjQKFnBhcn'
        'RpY2lwYW50X3B1YmxpY19rZXkYAiABKAxSFHBhcnRpY2lwYW50UHVibGljS2V5');

@$core.Deprecated('Use beginEnrollmentResponseDescriptor instead')
const BeginEnrollmentResponse$json = {
  '1': 'BeginEnrollmentResponse',
  '2': [
    {'1': 'challenge', '3': 1, '4': 1, '5': 12, '10': 'challenge'},
  ],
};

/// Descriptor for `BeginEnrollmentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beginEnrollmentResponseDescriptor =
    $convert.base64Decode(
        'ChdCZWdpbkVucm9sbG1lbnRSZXNwb25zZRIcCgljaGFsbGVuZ2UYASABKAxSCWNoYWxsZW5nZQ'
        '==');

@$core.Deprecated('Use redeemRoomInviteRequestDescriptor instead')
const RedeemRoomInviteRequest$json = {
  '1': 'RedeemRoomInviteRequest',
  '2': [
    {'1': 'transcript', '3': 1, '4': 1, '5': 12, '10': 'transcript'},
    {'1': 'signature', '3': 2, '4': 1, '5': 12, '10': 'signature'},
  ],
};

/// Descriptor for `RedeemRoomInviteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List redeemRoomInviteRequestDescriptor =
    $convert.base64Decode(
        'ChdSZWRlZW1Sb29tSW52aXRlUmVxdWVzdBIeCgp0cmFuc2NyaXB0GAEgASgMUgp0cmFuc2NyaX'
        'B0EhwKCXNpZ25hdHVyZRgCIAEoDFIJc2lnbmF0dXJl');

@$core.Deprecated('Use redeemRoomInviteResponseDescriptor instead')
const RedeemRoomInviteResponse$json = {
  '1': 'RedeemRoomInviteResponse',
  '2': [
    {'1': 'snapshot', '3': 1, '4': 1, '5': 12, '10': 'snapshot'},
  ],
};

/// Descriptor for `RedeemRoomInviteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List redeemRoomInviteResponseDescriptor =
    $convert.base64Decode(
        'ChhSZWRlZW1Sb29tSW52aXRlUmVzcG9uc2USGgoIc25hcHNob3QYASABKAxSCHNuYXBzaG90');

@$core.Deprecated('Use rpcRequestDescriptor instead')
const RpcRequest$json = {
  '1': 'RpcRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 12, '10': 'requestId'},
    {
      '1': 'login',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.noosphere.LoginRequest',
      '9': 0,
      '10': 'login'
    },
    {
      '1': 'respond_to_challenge',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignedAuthChallenge',
      '9': 0,
      '10': 'respondToChallenge'
    },
    {
      '1': 'extend_session',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.noosphere.Bytes',
      '9': 0,
      '10': 'extendSession'
    },
    {
      '1': 'request_new_dkg',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgRequest',
      '9': 0,
      '10': 'requestNewDkg'
    },
    {
      '1': 'reject_dkg',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgToReject',
      '9': 0,
      '10': 'rejectDkg'
    },
    {
      '1': 'submit_dkg_commitment',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgCommitment',
      '9': 0,
      '10': 'submitDkgCommitment'
    },
    {
      '1': 'submit_dkg_round2',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgRound2',
      '9': 0,
      '10': 'submitDkgRound2'
    },
    {
      '1': 'send_dkg_acks',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgAcks',
      '9': 0,
      '10': 'sendDkgAcks'
    },
    {
      '1': 'request_dkg_acks',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.noosphere.DkgAckRequest',
      '9': 0,
      '10': 'requestDkgAcks'
    },
    {
      '1': 'request_signatures',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesRequest',
      '9': 0,
      '10': 'requestSignatures'
    },
    {
      '1': 'reject_signatures_request',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesRejection',
      '9': 0,
      '10': 'rejectSignaturesRequest'
    },
    {
      '1': 'submit_signature_replies',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SignaturesReplies',
      '9': 0,
      '10': 'submitSignatureReplies'
    },
    {
      '1': 'share_secret_share',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SecretShare',
      '9': 0,
      '10': 'shareSecretShare'
    },
    {
      '1': 'ack_key_constructed',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.noosphere.ConstructedKey',
      '9': 0,
      '10': 'ackKeyConstructed'
    },
    {
      '1': 'begin_enrollment',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.noosphere.BeginEnrollmentRequest',
      '9': 0,
      '10': 'beginEnrollment'
    },
    {
      '1': 'redeem_room_invite',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RedeemRoomInviteRequest',
      '9': 0,
      '10': 'redeemRoomInvite'
    },
  ],
  '8': [
    {'1': 'request'},
  ],
};

/// Descriptor for `RpcRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rpcRequestDescriptor = $convert.base64Decode(
    'CgpScGNSZXF1ZXN0Eh0KCnJlcXVlc3RfaWQYASABKAxSCXJlcXVlc3RJZBIvCgVsb2dpbhgKIA'
    'EoCzIXLm5vb3NwaGVyZS5Mb2dpblJlcXVlc3RIAFIFbG9naW4SUgoUcmVzcG9uZF90b19jaGFs'
    'bGVuZ2UYCyABKAsyHi5ub29zcGhlcmUuU2lnbmVkQXV0aENoYWxsZW5nZUgAUhJyZXNwb25kVG'
    '9DaGFsbGVuZ2USOQoOZXh0ZW5kX3Nlc3Npb24YDCABKAsyEC5ub29zcGhlcmUuQnl0ZXNIAFIN'
    'ZXh0ZW5kU2Vzc2lvbhI/Cg9yZXF1ZXN0X25ld19ka2cYDSABKAsyFS5ub29zcGhlcmUuRGtnUm'
    'VxdWVzdEgAUg1yZXF1ZXN0TmV3RGtnEjcKCnJlamVjdF9ka2cYDiABKAsyFi5ub29zcGhlcmUu'
    'RGtnVG9SZWplY3RIAFIJcmVqZWN0RGtnEk4KFXN1Ym1pdF9ka2dfY29tbWl0bWVudBgPIAEoCz'
    'IYLm5vb3NwaGVyZS5Ea2dDb21taXRtZW50SABSE3N1Ym1pdERrZ0NvbW1pdG1lbnQSQgoRc3Vi'
    'bWl0X2RrZ19yb3VuZDIYECABKAsyFC5ub29zcGhlcmUuRGtnUm91bmQySABSD3N1Ym1pdERrZ1'
    'JvdW5kMhI4Cg1zZW5kX2RrZ19hY2tzGBEgASgLMhIubm9vc3BoZXJlLkRrZ0Fja3NIAFILc2Vu'
    'ZERrZ0Fja3MSRAoQcmVxdWVzdF9ka2dfYWNrcxgSIAEoCzIYLm5vb3NwaGVyZS5Ea2dBY2tSZX'
    'F1ZXN0SABSDnJlcXVlc3REa2dBY2tzEk0KEnJlcXVlc3Rfc2lnbmF0dXJlcxgTIAEoCzIcLm5v'
    'b3NwaGVyZS5TaWduYXR1cmVzUmVxdWVzdEgAUhFyZXF1ZXN0U2lnbmF0dXJlcxJcChlyZWplY3'
    'Rfc2lnbmF0dXJlc19yZXF1ZXN0GBQgASgLMh4ubm9vc3BoZXJlLlNpZ25hdHVyZXNSZWplY3Rp'
    'b25IAFIXcmVqZWN0U2lnbmF0dXJlc1JlcXVlc3QSWAoYc3VibWl0X3NpZ25hdHVyZV9yZXBsaW'
    'VzGBUgASgLMhwubm9vc3BoZXJlLlNpZ25hdHVyZXNSZXBsaWVzSABSFnN1Ym1pdFNpZ25hdHVy'
    'ZVJlcGxpZXMSRgoSc2hhcmVfc2VjcmV0X3NoYXJlGBYgASgLMhYubm9vc3BoZXJlLlNlY3JldF'
    'NoYXJlSABSEHNoYXJlU2VjcmV0U2hhcmUSSwoTYWNrX2tleV9jb25zdHJ1Y3RlZBgXIAEoCzIZ'
    'Lm5vb3NwaGVyZS5Db25zdHJ1Y3RlZEtleUgAUhFhY2tLZXlDb25zdHJ1Y3RlZBJOChBiZWdpbl'
    '9lbnJvbGxtZW50GBggASgLMiEubm9vc3BoZXJlLkJlZ2luRW5yb2xsbWVudFJlcXVlc3RIAFIP'
    'YmVnaW5FbnJvbGxtZW50ElIKEnJlZGVlbV9yb29tX2ludml0ZRgZIAEoCzIiLm5vb3NwaGVyZS'
    '5SZWRlZW1Sb29tSW52aXRlUmVxdWVzdEgAUhByZWRlZW1Sb29tSW52aXRlQgkKB3JlcXVlc3Q=');

@$core.Deprecated('Use rpcResponseDescriptor instead')
const RpcResponse$json = {
  '1': 'RpcResponse',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 12, '10': 'requestId'},
    {
      '1': 'login',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.noosphere.LoginResponse',
      '9': 0,
      '10': 'login'
    },
    {
      '1': 'respond_to_challenge',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RespondToChallengeResponse',
      '9': 0,
      '10': 'respondToChallenge'
    },
    {
      '1': 'extend_session',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.noosphere.ExtendSessionResponse',
      '9': 0,
      '10': 'extendSession'
    },
    {
      '1': 'request_new_dkg',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RequestNewDkgResponse',
      '9': 0,
      '10': 'requestNewDkg'
    },
    {
      '1': 'reject_dkg',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RejectDkgResponse',
      '9': 0,
      '10': 'rejectDkg'
    },
    {
      '1': 'submit_dkg_commitment',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SubmitDkgCommitmentResponse',
      '9': 0,
      '10': 'submitDkgCommitment'
    },
    {
      '1': 'submit_dkg_round2',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SubmitDkgRound2Response',
      '9': 0,
      '10': 'submitDkgRound2'
    },
    {
      '1': 'send_dkg_acks',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SendDkgAcksResponse',
      '9': 0,
      '10': 'sendDkgAcks'
    },
    {
      '1': 'request_dkg_acks',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RequestDkgAcksResponse',
      '9': 0,
      '10': 'requestDkgAcks'
    },
    {
      '1': 'request_signatures',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RequestSignaturesResponse',
      '9': 0,
      '10': 'requestSignatures'
    },
    {
      '1': 'reject_signatures_request',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RejectSignaturesRequestResponse',
      '9': 0,
      '10': 'rejectSignaturesRequest'
    },
    {
      '1': 'submit_signature_replies',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SubmitSignatureRepliesResponse',
      '9': 0,
      '10': 'submitSignatureReplies'
    },
    {
      '1': 'share_secret_share',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.noosphere.ShareSecretShareResponse',
      '9': 0,
      '10': 'shareSecretShare'
    },
    {
      '1': 'ack_key_constructed',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.noosphere.AckKeyConstructedResponse',
      '9': 0,
      '10': 'ackKeyConstructed'
    },
    {
      '1': 'begin_enrollment',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.noosphere.BeginEnrollmentResponse',
      '9': 0,
      '10': 'beginEnrollment'
    },
    {
      '1': 'redeem_room_invite',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RedeemRoomInviteResponse',
      '9': 0,
      '10': 'redeemRoomInvite'
    },
    {
      '1': 'error',
      '3': 100,
      '4': 1,
      '5': 11,
      '6': '.noosphere.ProtocolError',
      '9': 0,
      '10': 'error'
    },
  ],
  '8': [
    {'1': 'response'},
  ],
};

/// Descriptor for `RpcResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rpcResponseDescriptor = $convert.base64Decode(
    'CgtScGNSZXNwb25zZRIdCgpyZXF1ZXN0X2lkGAEgASgMUglyZXF1ZXN0SWQSMAoFbG9naW4YCi'
    'ABKAsyGC5ub29zcGhlcmUuTG9naW5SZXNwb25zZUgAUgVsb2dpbhJZChRyZXNwb25kX3RvX2No'
    'YWxsZW5nZRgLIAEoCzIlLm5vb3NwaGVyZS5SZXNwb25kVG9DaGFsbGVuZ2VSZXNwb25zZUgAUh'
    'JyZXNwb25kVG9DaGFsbGVuZ2USSQoOZXh0ZW5kX3Nlc3Npb24YDCABKAsyIC5ub29zcGhlcmUu'
    'RXh0ZW5kU2Vzc2lvblJlc3BvbnNlSABSDWV4dGVuZFNlc3Npb24SSgoPcmVxdWVzdF9uZXdfZG'
    'tnGA0gASgLMiAubm9vc3BoZXJlLlJlcXVlc3ROZXdEa2dSZXNwb25zZUgAUg1yZXF1ZXN0TmV3'
    'RGtnEj0KCnJlamVjdF9ka2cYDiABKAsyHC5ub29zcGhlcmUuUmVqZWN0RGtnUmVzcG9uc2VIAF'
    'IJcmVqZWN0RGtnElwKFXN1Ym1pdF9ka2dfY29tbWl0bWVudBgPIAEoCzImLm5vb3NwaGVyZS5T'
    'dWJtaXREa2dDb21taXRtZW50UmVzcG9uc2VIAFITc3VibWl0RGtnQ29tbWl0bWVudBJQChFzdW'
    'JtaXRfZGtnX3JvdW5kMhgQIAEoCzIiLm5vb3NwaGVyZS5TdWJtaXREa2dSb3VuZDJSZXNwb25z'
    'ZUgAUg9zdWJtaXREa2dSb3VuZDISRAoNc2VuZF9ka2dfYWNrcxgRIAEoCzIeLm5vb3NwaGVyZS'
    '5TZW5kRGtnQWNrc1Jlc3BvbnNlSABSC3NlbmREa2dBY2tzEk0KEHJlcXVlc3RfZGtnX2Fja3MY'
    'EiABKAsyIS5ub29zcGhlcmUuUmVxdWVzdERrZ0Fja3NSZXNwb25zZUgAUg5yZXF1ZXN0RGtnQW'
    'NrcxJVChJyZXF1ZXN0X3NpZ25hdHVyZXMYEyABKAsyJC5ub29zcGhlcmUuUmVxdWVzdFNpZ25h'
    'dHVyZXNSZXNwb25zZUgAUhFyZXF1ZXN0U2lnbmF0dXJlcxJoChlyZWplY3Rfc2lnbmF0dXJlc1'
    '9yZXF1ZXN0GBQgASgLMioubm9vc3BoZXJlLlJlamVjdFNpZ25hdHVyZXNSZXF1ZXN0UmVzcG9u'
    'c2VIAFIXcmVqZWN0U2lnbmF0dXJlc1JlcXVlc3QSZQoYc3VibWl0X3NpZ25hdHVyZV9yZXBsaW'
    'VzGBUgASgLMikubm9vc3BoZXJlLlN1Ym1pdFNpZ25hdHVyZVJlcGxpZXNSZXNwb25zZUgAUhZz'
    'dWJtaXRTaWduYXR1cmVSZXBsaWVzElMKEnNoYXJlX3NlY3JldF9zaGFyZRgWIAEoCzIjLm5vb3'
    'NwaGVyZS5TaGFyZVNlY3JldFNoYXJlUmVzcG9uc2VIAFIQc2hhcmVTZWNyZXRTaGFyZRJWChNh'
    'Y2tfa2V5X2NvbnN0cnVjdGVkGBcgASgLMiQubm9vc3BoZXJlLkFja0tleUNvbnN0cnVjdGVkUm'
    'VzcG9uc2VIAFIRYWNrS2V5Q29uc3RydWN0ZWQSTwoQYmVnaW5fZW5yb2xsbWVudBgYIAEoCzIi'
    'Lm5vb3NwaGVyZS5CZWdpbkVucm9sbG1lbnRSZXNwb25zZUgAUg9iZWdpbkVucm9sbG1lbnQSUw'
    'oScmVkZWVtX3Jvb21faW52aXRlGBkgASgLMiMubm9vc3BoZXJlLlJlZGVlbVJvb21JbnZpdGVS'
    'ZXNwb25zZUgAUhByZWRlZW1Sb29tSW52aXRlEjAKBWVycm9yGGQgASgLMhgubm9vc3BoZXJlLl'
    'Byb3RvY29sRXJyb3JIAFIFZXJyb3JCCgoIcmVzcG9uc2U=');

@$core.Deprecated('Use startSessionDescriptor instead')
const StartSession$json = {
  '1': 'StartSession',
};

/// Descriptor for `StartSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSessionDescriptor =
    $convert.base64Decode('CgxTdGFydFNlc3Npb24=');

@$core.Deprecated('Use sessionStartedDescriptor instead')
const SessionStarted$json = {
  '1': 'SessionStarted',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 12, '10': 'sessionId'},
    {'1': 'snapshot', '3': 2, '4': 1, '5': 12, '10': 'snapshot'},
  ],
};

/// Descriptor for `SessionStarted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionStartedDescriptor = $convert.base64Decode(
    'Cg5TZXNzaW9uU3RhcnRlZBIdCgpzZXNzaW9uX2lkGAEgASgMUglzZXNzaW9uSWQSGgoIc25hcH'
    'Nob3QYAiABKAxSCHNuYXBzaG90');

@$core.Deprecated('Use readyDescriptor instead')
const Ready$json = {
  '1': 'Ready',
};

/// Descriptor for `Ready`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List readyDescriptor =
    $convert.base64Decode('CgVSZWFkeQ==');

@$core.Deprecated('Use logoutDescriptor instead')
const Logout$json = {
  '1': 'Logout',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 12, '10': 'sessionId'},
  ],
};

/// Descriptor for `Logout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutDescriptor = $convert
    .base64Decode('CgZMb2dvdXQSHQoKc2Vzc2lvbl9pZBgBIAEoDFIJc2Vzc2lvbklk');

@$core.Deprecated('Use envelopeDescriptor instead')
const Envelope$json = {
  '1': 'Envelope',
  '2': [
    {'1': 'wire_version', '3': 1, '4': 1, '5': 13, '10': 'wireVersion'},
    {
      '1': 'rpc_request',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RpcRequest',
      '9': 0,
      '10': 'rpcRequest'
    },
    {
      '1': 'rpc_response',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.noosphere.RpcResponse',
      '9': 0,
      '10': 'rpcResponse'
    },
    {
      '1': 'start_session',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.noosphere.StartSession',
      '9': 0,
      '10': 'startSession'
    },
    {
      '1': 'session_started',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.noosphere.SessionStarted',
      '9': 0,
      '10': 'sessionStarted'
    },
    {
      '1': 'ready',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.noosphere.Ready',
      '9': 0,
      '10': 'ready'
    },
    {
      '1': 'logout',
      '3': 27,
      '4': 1,
      '5': 11,
      '6': '.noosphere.Logout',
      '9': 0,
      '10': 'logout'
    },
    {
      '1': 'event',
      '3': 28,
      '4': 1,
      '5': 11,
      '6': '.noosphere.EventMessage',
      '9': 0,
      '10': 'event'
    },
    {
      '1': 'error',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.noosphere.ProtocolError',
      '9': 0,
      '10': 'error'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `Envelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List envelopeDescriptor = $convert.base64Decode(
    'CghFbnZlbG9wZRIhCgx3aXJlX3ZlcnNpb24YASABKA1SC3dpcmVWZXJzaW9uEjgKC3JwY19yZX'
    'F1ZXN0GAogASgLMhUubm9vc3BoZXJlLlJwY1JlcXVlc3RIAFIKcnBjUmVxdWVzdBI7CgxycGNf'
    'cmVzcG9uc2UYCyABKAsyFi5ub29zcGhlcmUuUnBjUmVzcG9uc2VIAFILcnBjUmVzcG9uc2USPg'
    'oNc3RhcnRfc2Vzc2lvbhgUIAEoCzIXLm5vb3NwaGVyZS5TdGFydFNlc3Npb25IAFIMc3RhcnRT'
    'ZXNzaW9uEkQKD3Nlc3Npb25fc3RhcnRlZBgVIAEoCzIZLm5vb3NwaGVyZS5TZXNzaW9uU3Rhcn'
    'RlZEgAUg5zZXNzaW9uU3RhcnRlZBIoCgVyZWFkeRgZIAEoCzIQLm5vb3NwaGVyZS5SZWFkeUgA'
    'UgVyZWFkeRIrCgZsb2dvdXQYGyABKAsyES5ub29zcGhlcmUuTG9nb3V0SABSBmxvZ291dBIvCg'
    'VldmVudBgcIAEoCzIXLm5vb3NwaGVyZS5FdmVudE1lc3NhZ2VIAFIFZXZlbnQSMAoFZXJyb3IY'
    'HSABKAsyGC5ub29zcGhlcmUuUHJvdG9jb2xFcnJvckgAUgVlcnJvckIJCgdwYXlsb2Fk');

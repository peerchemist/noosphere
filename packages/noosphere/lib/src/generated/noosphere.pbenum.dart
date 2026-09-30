// This is a generated file - do not edit.
//
// Generated from noosphere.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SignaturesResponseType extends $pb.ProtobufEnum {
  static const SignaturesResponseType SIGNATURES_RESPONSE_EMPTY =
      SignaturesResponseType._(
          0, _omitEnumNames ? '' : 'SIGNATURES_RESPONSE_EMPTY');
  static const SignaturesResponseType SIGNATURES_RESPONSE_NEW_ROUND =
      SignaturesResponseType._(
          1, _omitEnumNames ? '' : 'SIGNATURES_RESPONSE_NEW_ROUND');
  static const SignaturesResponseType SIGNATURES_RESPONSE_COMPLETE =
      SignaturesResponseType._(
          2, _omitEnumNames ? '' : 'SIGNATURES_RESPONSE_COMPLETE');

  static const $core.List<SignaturesResponseType> values =
      <SignaturesResponseType>[
    SIGNATURES_RESPONSE_EMPTY,
    SIGNATURES_RESPONSE_NEW_ROUND,
    SIGNATURES_RESPONSE_COMPLETE,
  ];

  static final $core.List<SignaturesResponseType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SignaturesResponseType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SignaturesResponseType._(super.value, super.name);
}

class EventType extends $pb.ProtobufEnum {
  static const EventType PARTICIPANT_STATUS_EVENT =
      EventType._(0, _omitEnumNames ? '' : 'PARTICIPANT_STATUS_EVENT');
  static const EventType NEW_DKG_EVENT =
      EventType._(1, _omitEnumNames ? '' : 'NEW_DKG_EVENT');
  static const EventType DKG_COMMITMENT_EVENT =
      EventType._(2, _omitEnumNames ? '' : 'DKG_COMMITMENT_EVENT');
  static const EventType DKG_REJECT_EVENT =
      EventType._(3, _omitEnumNames ? '' : 'DKG_REJECT_EVENT');
  static const EventType DKG_ROUND2_SHARE_EVENT =
      EventType._(4, _omitEnumNames ? '' : 'DKG_ROUND2_SHARE_EVENT');
  static const EventType DKG_ACK_EVENT =
      EventType._(5, _omitEnumNames ? '' : 'DKG_ACK_EVENT');
  static const EventType DKG_ACK_REQUEST_EVENT =
      EventType._(6, _omitEnumNames ? '' : 'DKG_ACK_REQUEST_EVENT');
  static const EventType SIG_REQ_EVENT =
      EventType._(7, _omitEnumNames ? '' : 'SIG_REQ_EVENT');
  static const EventType SIG_NEW_ROUNDS_EVENT =
      EventType._(8, _omitEnumNames ? '' : 'SIG_NEW_ROUNDS_EVENT');
  static const EventType SIG_COMPLETE_EVENT =
      EventType._(9, _omitEnumNames ? '' : 'SIG_COMPLETE_EVENT');
  static const EventType SIG_FAILURE_EVENT =
      EventType._(10, _omitEnumNames ? '' : 'SIG_FAILURE_EVENT');
  static const EventType KEEPALIVE_EVENT =
      EventType._(11, _omitEnumNames ? '' : 'KEEPALIVE_EVENT');
  static const EventType SECRET_SHARE_EVENT =
      EventType._(12, _omitEnumNames ? '' : 'SECRET_SHARE_EVENT');
  static const EventType CONSTRUCTED_KEY_EVENT =
      EventType._(13, _omitEnumNames ? '' : 'CONSTRUCTED_KEY_EVENT');
  static const EventType SIG_PROGRESS_EVENT =
      EventType._(14, _omitEnumNames ? '' : 'SIG_PROGRESS_EVENT');

  static const $core.List<EventType> values = <EventType>[
    PARTICIPANT_STATUS_EVENT,
    NEW_DKG_EVENT,
    DKG_COMMITMENT_EVENT,
    DKG_REJECT_EVENT,
    DKG_ROUND2_SHARE_EVENT,
    DKG_ACK_EVENT,
    DKG_ACK_REQUEST_EVENT,
    SIG_REQ_EVENT,
    SIG_NEW_ROUNDS_EVENT,
    SIG_COMPLETE_EVENT,
    SIG_FAILURE_EVENT,
    KEEPALIVE_EVENT,
    SECRET_SHARE_EVENT,
    CONSTRUCTED_KEY_EVENT,
    SIG_PROGRESS_EVENT,
  ];

  static final $core.List<EventType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 14);
  static EventType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EventType._(super.value, super.name);
}

class ProtocolErrorCode extends $pb.ProtobufEnum {
  static const ProtocolErrorCode PROTOCOL_ERROR_UNSPECIFIED =
      ProtocolErrorCode._(
          0, _omitEnumNames ? '' : 'PROTOCOL_ERROR_UNSPECIFIED');
  static const ProtocolErrorCode PROTOCOL_ERROR_INVALID_REQUEST =
      ProtocolErrorCode._(
          1, _omitEnumNames ? '' : 'PROTOCOL_ERROR_INVALID_REQUEST');
  static const ProtocolErrorCode PROTOCOL_ERROR_UNAUTHENTICATED =
      ProtocolErrorCode._(
          2, _omitEnumNames ? '' : 'PROTOCOL_ERROR_UNAUTHENTICATED');
  static const ProtocolErrorCode PROTOCOL_ERROR_UNSUPPORTED_VERSION =
      ProtocolErrorCode._(
          3, _omitEnumNames ? '' : 'PROTOCOL_ERROR_UNSUPPORTED_VERSION');
  static const ProtocolErrorCode PROTOCOL_ERROR_RESOURCE_EXHAUSTED =
      ProtocolErrorCode._(
          4, _omitEnumNames ? '' : 'PROTOCOL_ERROR_RESOURCE_EXHAUSTED');
  static const ProtocolErrorCode PROTOCOL_ERROR_DEADLINE_EXCEEDED =
      ProtocolErrorCode._(
          5, _omitEnumNames ? '' : 'PROTOCOL_ERROR_DEADLINE_EXCEEDED');
  static const ProtocolErrorCode PROTOCOL_ERROR_INTERNAL =
      ProtocolErrorCode._(6, _omitEnumNames ? '' : 'PROTOCOL_ERROR_INTERNAL');
  static const ProtocolErrorCode PROTOCOL_ERROR_UNKNOWN_OUTCOME =
      ProtocolErrorCode._(
          7, _omitEnumNames ? '' : 'PROTOCOL_ERROR_UNKNOWN_OUTCOME');
  static const ProtocolErrorCode PROTOCOL_ERROR_SESSION_NOT_FOUND =
      ProtocolErrorCode._(
          8, _omitEnumNames ? '' : 'PROTOCOL_ERROR_SESSION_NOT_FOUND');
  static const ProtocolErrorCode PROTOCOL_ERROR_SESSION_EXPIRED =
      ProtocolErrorCode._(
          9, _omitEnumNames ? '' : 'PROTOCOL_ERROR_SESSION_EXPIRED');

  static const $core.List<ProtocolErrorCode> values = <ProtocolErrorCode>[
    PROTOCOL_ERROR_UNSPECIFIED,
    PROTOCOL_ERROR_INVALID_REQUEST,
    PROTOCOL_ERROR_UNAUTHENTICATED,
    PROTOCOL_ERROR_UNSUPPORTED_VERSION,
    PROTOCOL_ERROR_RESOURCE_EXHAUSTED,
    PROTOCOL_ERROR_DEADLINE_EXCEEDED,
    PROTOCOL_ERROR_INTERNAL,
    PROTOCOL_ERROR_UNKNOWN_OUTCOME,
    PROTOCOL_ERROR_SESSION_NOT_FOUND,
    PROTOCOL_ERROR_SESSION_EXPIRED,
  ];

  static final $core.List<ProtocolErrorCode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 9);
  static ProtocolErrorCode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProtocolErrorCode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');

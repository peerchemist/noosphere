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

class SignaturesProgressStage extends $pb.ProtobufEnum {
  static const SignaturesProgressStage SIGNATURES_PROGRESS_COLLECTING =
      SignaturesProgressStage._(
          0, _omitEnumNames ? '' : 'SIGNATURES_PROGRESS_COLLECTING');
  static const SignaturesProgressStage SIGNATURES_PROGRESS_SIGNING =
      SignaturesProgressStage._(
          1, _omitEnumNames ? '' : 'SIGNATURES_PROGRESS_SIGNING');
  static const SignaturesProgressStage SIGNATURES_PROGRESS_COMPLETED =
      SignaturesProgressStage._(
          2, _omitEnumNames ? '' : 'SIGNATURES_PROGRESS_COMPLETED');
  static const SignaturesProgressStage SIGNATURES_PROGRESS_FAILED =
      SignaturesProgressStage._(
          3, _omitEnumNames ? '' : 'SIGNATURES_PROGRESS_FAILED');

  static const $core.List<SignaturesProgressStage> values =
      <SignaturesProgressStage>[
    SIGNATURES_PROGRESS_COLLECTING,
    SIGNATURES_PROGRESS_SIGNING,
    SIGNATURES_PROGRESS_COMPLETED,
    SIGNATURES_PROGRESS_FAILED,
  ];

  static final $core.List<SignaturesProgressStage?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static SignaturesProgressStage? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SignaturesProgressStage._(super.value, super.name);
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

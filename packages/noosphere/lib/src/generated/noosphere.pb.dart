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

import 'noosphere.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'noosphere.pbenum.dart';

class Bytes extends $pb.GeneratedMessage {
  factory Bytes({
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (data != null) result.data = data;
    return result;
  }

  Bytes._();

  factory Bytes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Bytes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Bytes',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Bytes clone() => Bytes()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Bytes copyWith(void Function(Bytes) updates) =>
      super.copyWith((message) => updates(message as Bytes)) as Bytes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Bytes create() => Bytes._();
  @$core.override
  Bytes createEmptyInstance() => create();
  static $pb.PbList<Bytes> createRepeated() => $pb.PbList<Bytes>();
  @$core.pragma('dart2js:noInline')
  static Bytes getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Bytes>(create);
  static Bytes? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
}

class RepeatedBytes extends $pb.GeneratedMessage {
  factory RepeatedBytes({
    $core.Iterable<$core.List<$core.int>>? data,
  }) {
    final result = create();
    if (data != null) result.data.addAll(data);
    return result;
  }

  RepeatedBytes._();

  factory RepeatedBytes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RepeatedBytes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RepeatedBytes',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..p<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RepeatedBytes clone() => RepeatedBytes()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RepeatedBytes copyWith(void Function(RepeatedBytes) updates) =>
      super.copyWith((message) => updates(message as RepeatedBytes))
          as RepeatedBytes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RepeatedBytes create() => RepeatedBytes._();
  @$core.override
  RepeatedBytes createEmptyInstance() => create();
  static $pb.PbList<RepeatedBytes> createRepeated() =>
      $pb.PbList<RepeatedBytes>();
  @$core.pragma('dart2js:noInline')
  static RepeatedBytes getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RepeatedBytes>(create);
  static RepeatedBytes? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.List<$core.int>> get data => $_getList(0);
}

class SignaturesResponse extends $pb.GeneratedMessage {
  factory SignaturesResponse({
    SignaturesResponseType? type,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (data != null) result.data = data;
    return result;
  }

  SignaturesResponse._();

  factory SignaturesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..e<SignaturesResponseType>(
        1, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE,
        defaultOrMaker: SignaturesResponseType.SIGNATURES_RESPONSE_EMPTY,
        valueOf: SignaturesResponseType.valueOf,
        enumValues: SignaturesResponseType.values)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesResponse clone() => SignaturesResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesResponse copyWith(void Function(SignaturesResponse) updates) =>
      super.copyWith((message) => updates(message as SignaturesResponse))
          as SignaturesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesResponse create() => SignaturesResponse._();
  @$core.override
  SignaturesResponse createEmptyInstance() => create();
  static $pb.PbList<SignaturesResponse> createRepeated() =>
      $pb.PbList<SignaturesResponse>();
  @$core.pragma('dart2js:noInline')
  static SignaturesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesResponse>(create);
  static SignaturesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  SignaturesResponseType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(SignaturesResponseType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

class Empty extends $pb.GeneratedMessage {
  factory Empty() => create();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => Empty()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Empty create() => Empty._();
  @$core.override
  Empty createEmptyInstance() => create();
  static $pb.PbList<Empty> createRepeated() => $pb.PbList<Empty>();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);
  static Empty? _defaultInstance;
}

class LoginRequest extends $pb.GeneratedMessage {
  factory LoginRequest({
    $core.List<$core.int>? groupFingerprint,
    $core.List<$core.int>? participantId,
    $core.int? protocolVersion,
  }) {
    final result = create();
    if (groupFingerprint != null) result.groupFingerprint = groupFingerprint;
    if (participantId != null) result.participantId = participantId;
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    return result;
  }

  LoginRequest._();

  factory LoginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'groupFingerprint', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'participantId', $pb.PbFieldType.OY)
    ..a<$core.int>(
        3, _omitFieldNames ? '' : 'protocolVersion', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginRequest clone() => LoginRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginRequest copyWith(void Function(LoginRequest) updates) =>
      super.copyWith((message) => updates(message as LoginRequest))
          as LoginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginRequest create() => LoginRequest._();
  @$core.override
  LoginRequest createEmptyInstance() => create();
  static $pb.PbList<LoginRequest> createRepeated() =>
      $pb.PbList<LoginRequest>();
  @$core.pragma('dart2js:noInline')
  static LoginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginRequest>(create);
  static LoginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get groupFingerprint => $_getN(0);
  @$pb.TagNumber(1)
  set groupFingerprint($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGroupFingerprint() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupFingerprint() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get participantId => $_getN(1);
  @$pb.TagNumber(2)
  set participantId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParticipantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearParticipantId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get protocolVersion => $_getIZ(2);
  @$pb.TagNumber(3)
  set protocolVersion($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProtocolVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearProtocolVersion() => $_clearField(3);
}

class SignedAuthChallenge extends $pb.GeneratedMessage {
  factory SignedAuthChallenge({
    $core.List<$core.int>? signature,
    $core.List<$core.int>? challenge,
  }) {
    final result = create();
    if (signature != null) result.signature = signature;
    if (challenge != null) result.challenge = challenge;
    return result;
  }

  SignedAuthChallenge._();

  factory SignedAuthChallenge.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignedAuthChallenge.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignedAuthChallenge',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'challenge', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedAuthChallenge clone() => SignedAuthChallenge()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignedAuthChallenge copyWith(void Function(SignedAuthChallenge) updates) =>
      super.copyWith((message) => updates(message as SignedAuthChallenge))
          as SignedAuthChallenge;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignedAuthChallenge create() => SignedAuthChallenge._();
  @$core.override
  SignedAuthChallenge createEmptyInstance() => create();
  static $pb.PbList<SignedAuthChallenge> createRepeated() =>
      $pb.PbList<SignedAuthChallenge>();
  @$core.pragma('dart2js:noInline')
  static SignedAuthChallenge getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignedAuthChallenge>(create);
  static SignedAuthChallenge? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get signature => $_getN(0);
  @$pb.TagNumber(1)
  set signature($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignature() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignature() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get challenge => $_getN(1);
  @$pb.TagNumber(2)
  set challenge($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChallenge() => $_has(1);
  @$pb.TagNumber(2)
  void clearChallenge() => $_clearField(2);
}

class DkgRequest extends $pb.GeneratedMessage {
  factory DkgRequest({
    $core.List<$core.int>? sid,
    $core.List<$core.int>? signedDetails,
    $core.List<$core.int>? commitment,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (signedDetails != null) result.signedDetails = signedDetails;
    if (commitment != null) result.commitment = commitment;
    return result;
  }

  DkgRequest._();

  factory DkgRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signedDetails', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'commitment', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgRequest clone() => DkgRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgRequest copyWith(void Function(DkgRequest) updates) =>
      super.copyWith((message) => updates(message as DkgRequest)) as DkgRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgRequest create() => DkgRequest._();
  @$core.override
  DkgRequest createEmptyInstance() => create();
  static $pb.PbList<DkgRequest> createRepeated() => $pb.PbList<DkgRequest>();
  @$core.pragma('dart2js:noInline')
  static DkgRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgRequest>(create);
  static DkgRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get signedDetails => $_getN(1);
  @$pb.TagNumber(2)
  set signedDetails($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignedDetails() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignedDetails() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get commitment => $_getN(2);
  @$pb.TagNumber(3)
  set commitment($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommitment() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommitment() => $_clearField(3);
}

class DkgToReject extends $pb.GeneratedMessage {
  factory DkgToReject({
    $core.List<$core.int>? sid,
    $core.String? name,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (name != null) result.name = name;
    return result;
  }

  DkgToReject._();

  factory DkgToReject.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgToReject.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgToReject',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgToReject clone() => DkgToReject()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgToReject copyWith(void Function(DkgToReject) updates) =>
      super.copyWith((message) => updates(message as DkgToReject))
          as DkgToReject;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgToReject create() => DkgToReject._();
  @$core.override
  DkgToReject createEmptyInstance() => create();
  static $pb.PbList<DkgToReject> createRepeated() => $pb.PbList<DkgToReject>();
  @$core.pragma('dart2js:noInline')
  static DkgToReject getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgToReject>(create);
  static DkgToReject? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

class DkgCommitment extends $pb.GeneratedMessage {
  factory DkgCommitment({
    $core.List<$core.int>? sid,
    $core.String? name,
    $core.List<$core.int>? commitment,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (name != null) result.name = name;
    if (commitment != null) result.commitment = commitment;
    return result;
  }

  DkgCommitment._();

  factory DkgCommitment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgCommitment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgCommitment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'commitment', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgCommitment clone() => DkgCommitment()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgCommitment copyWith(void Function(DkgCommitment) updates) =>
      super.copyWith((message) => updates(message as DkgCommitment))
          as DkgCommitment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgCommitment create() => DkgCommitment._();
  @$core.override
  DkgCommitment createEmptyInstance() => create();
  static $pb.PbList<DkgCommitment> createRepeated() =>
      $pb.PbList<DkgCommitment>();
  @$core.pragma('dart2js:noInline')
  static DkgCommitment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgCommitment>(create);
  static DkgCommitment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get commitment => $_getN(2);
  @$pb.TagNumber(3)
  set commitment($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommitment() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommitment() => $_clearField(3);
}

class DkgSecret extends $pb.GeneratedMessage {
  factory DkgSecret({
    $core.List<$core.int>? id,
    $core.List<$core.int>? secret,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (secret != null) result.secret = secret;
    return result;
  }

  DkgSecret._();

  factory DkgSecret.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgSecret.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgSecret',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'secret', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgSecret clone() => DkgSecret()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgSecret copyWith(void Function(DkgSecret) updates) =>
      super.copyWith((message) => updates(message as DkgSecret)) as DkgSecret;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgSecret create() => DkgSecret._();
  @$core.override
  DkgSecret createEmptyInstance() => create();
  static $pb.PbList<DkgSecret> createRepeated() => $pb.PbList<DkgSecret>();
  @$core.pragma('dart2js:noInline')
  static DkgSecret getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DkgSecret>(create);
  static DkgSecret? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get id => $_getN(0);
  @$pb.TagNumber(1)
  set id($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get secret => $_getN(1);
  @$pb.TagNumber(2)
  set secret($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSecret() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecret() => $_clearField(2);
}

class DkgRound2 extends $pb.GeneratedMessage {
  factory DkgRound2({
    $core.List<$core.int>? sid,
    $core.String? name,
    $core.List<$core.int>? commitmentSetSignature,
    $core.Iterable<DkgSecret>? secrets,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (name != null) result.name = name;
    if (commitmentSetSignature != null)
      result.commitmentSetSignature = commitmentSetSignature;
    if (secrets != null) result.secrets.addAll(secrets);
    return result;
  }

  DkgRound2._();

  factory DkgRound2.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgRound2.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgRound2',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'commitmentSetSignature', $pb.PbFieldType.OY)
    ..pc<DkgSecret>(4, _omitFieldNames ? '' : 'secrets', $pb.PbFieldType.PM,
        subBuilder: DkgSecret.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgRound2 clone() => DkgRound2()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgRound2 copyWith(void Function(DkgRound2) updates) =>
      super.copyWith((message) => updates(message as DkgRound2)) as DkgRound2;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgRound2 create() => DkgRound2._();
  @$core.override
  DkgRound2 createEmptyInstance() => create();
  static $pb.PbList<DkgRound2> createRepeated() => $pb.PbList<DkgRound2>();
  @$core.pragma('dart2js:noInline')
  static DkgRound2 getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DkgRound2>(create);
  static DkgRound2? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get commitmentSetSignature => $_getN(2);
  @$pb.TagNumber(3)
  set commitmentSetSignature($core.List<$core.int> value) =>
      $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommitmentSetSignature() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommitmentSetSignature() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<DkgSecret> get secrets => $_getList(3);
}

class DkgAcks extends $pb.GeneratedMessage {
  factory DkgAcks({
    $core.List<$core.int>? sid,
    $core.Iterable<$core.List<$core.int>>? acks,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (acks != null) result.acks.addAll(acks);
    return result;
  }

  DkgAcks._();

  factory DkgAcks.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgAcks.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgAcks',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'acks', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgAcks clone() => DkgAcks()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgAcks copyWith(void Function(DkgAcks) updates) =>
      super.copyWith((message) => updates(message as DkgAcks)) as DkgAcks;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgAcks create() => DkgAcks._();
  @$core.override
  DkgAcks createEmptyInstance() => create();
  static $pb.PbList<DkgAcks> createRepeated() => $pb.PbList<DkgAcks>();
  @$core.pragma('dart2js:noInline')
  static DkgAcks getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DkgAcks>(create);
  static DkgAcks? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get acks => $_getList(1);
}

class DkgAckRequest extends $pb.GeneratedMessage {
  factory DkgAckRequest({
    $core.List<$core.int>? sid,
    $core.Iterable<$core.List<$core.int>>? requests,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (requests != null) result.requests.addAll(requests);
    return result;
  }

  DkgAckRequest._();

  factory DkgAckRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgAckRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgAckRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'requests', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgAckRequest clone() => DkgAckRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgAckRequest copyWith(void Function(DkgAckRequest) updates) =>
      super.copyWith((message) => updates(message as DkgAckRequest))
          as DkgAckRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgAckRequest create() => DkgAckRequest._();
  @$core.override
  DkgAckRequest createEmptyInstance() => create();
  static $pb.PbList<DkgAckRequest> createRepeated() =>
      $pb.PbList<DkgAckRequest>();
  @$core.pragma('dart2js:noInline')
  static DkgAckRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgAckRequest>(create);
  static DkgAckRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get requests => $_getList(1);
}

class SignaturesRequest extends $pb.GeneratedMessage {
  factory SignaturesRequest({
    $core.List<$core.int>? sid,
    $core.Iterable<$core.List<$core.int>>? keys,
    $core.List<$core.int>? signedDetails,
    $core.Iterable<$core.List<$core.int>>? commitments,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (keys != null) result.keys.addAll(keys);
    if (signedDetails != null) result.signedDetails = signedDetails;
    if (commitments != null) result.commitments.addAll(commitments);
    return result;
  }

  SignaturesRequest._();

  factory SignaturesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'keys', $pb.PbFieldType.PY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signedDetails', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'commitments', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesRequest clone() => SignaturesRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesRequest copyWith(void Function(SignaturesRequest) updates) =>
      super.copyWith((message) => updates(message as SignaturesRequest))
          as SignaturesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesRequest create() => SignaturesRequest._();
  @$core.override
  SignaturesRequest createEmptyInstance() => create();
  static $pb.PbList<SignaturesRequest> createRepeated() =>
      $pb.PbList<SignaturesRequest>();
  @$core.pragma('dart2js:noInline')
  static SignaturesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesRequest>(create);
  static SignaturesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get keys => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signedDetails => $_getN(2);
  @$pb.TagNumber(3)
  set signedDetails($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignedDetails() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignedDetails() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.List<$core.int>> get commitments => $_getList(3);
}

class SignaturesRejection extends $pb.GeneratedMessage {
  factory SignaturesRejection({
    $core.List<$core.int>? sid,
    $core.List<$core.int>? reqId,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (reqId != null) result.reqId = reqId;
    return result;
  }

  SignaturesRejection._();

  factory SignaturesRejection.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesRejection.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesRejection',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'reqId', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesRejection clone() => SignaturesRejection()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesRejection copyWith(void Function(SignaturesRejection) updates) =>
      super.copyWith((message) => updates(message as SignaturesRejection))
          as SignaturesRejection;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesRejection create() => SignaturesRejection._();
  @$core.override
  SignaturesRejection createEmptyInstance() => create();
  static $pb.PbList<SignaturesRejection> createRepeated() =>
      $pb.PbList<SignaturesRejection>();
  @$core.pragma('dart2js:noInline')
  static SignaturesRejection getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesRejection>(create);
  static SignaturesRejection? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get reqId => $_getN(1);
  @$pb.TagNumber(2)
  set reqId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReqId() => $_has(1);
  @$pb.TagNumber(2)
  void clearReqId() => $_clearField(2);
}

class SignaturesReplies extends $pb.GeneratedMessage {
  factory SignaturesReplies({
    $core.List<$core.int>? sid,
    $core.List<$core.int>? reqId,
    $core.Iterable<$core.List<$core.int>>? replies,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (reqId != null) result.reqId = reqId;
    if (replies != null) result.replies.addAll(replies);
    return result;
  }

  SignaturesReplies._();

  factory SignaturesReplies.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesReplies.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesReplies',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'reqId', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'replies', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesReplies clone() => SignaturesReplies()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesReplies copyWith(void Function(SignaturesReplies) updates) =>
      super.copyWith((message) => updates(message as SignaturesReplies))
          as SignaturesReplies;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesReplies create() => SignaturesReplies._();
  @$core.override
  SignaturesReplies createEmptyInstance() => create();
  static $pb.PbList<SignaturesReplies> createRepeated() =>
      $pb.PbList<SignaturesReplies>();
  @$core.pragma('dart2js:noInline')
  static SignaturesReplies getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesReplies>(create);
  static SignaturesReplies? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get reqId => $_getN(1);
  @$pb.TagNumber(2)
  set reqId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReqId() => $_has(1);
  @$pb.TagNumber(2)
  void clearReqId() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.List<$core.int>> get replies => $_getList(2);
}

class EncryptedSecret extends $pb.GeneratedMessage {
  factory EncryptedSecret({
    $core.List<$core.int>? id,
    $core.List<$core.int>? share,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (share != null) result.share = share;
    return result;
  }

  EncryptedSecret._();

  factory EncryptedSecret.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EncryptedSecret.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EncryptedSecret',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'share', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncryptedSecret clone() => EncryptedSecret()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncryptedSecret copyWith(void Function(EncryptedSecret) updates) =>
      super.copyWith((message) => updates(message as EncryptedSecret))
          as EncryptedSecret;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EncryptedSecret create() => EncryptedSecret._();
  @$core.override
  EncryptedSecret createEmptyInstance() => create();
  static $pb.PbList<EncryptedSecret> createRepeated() =>
      $pb.PbList<EncryptedSecret>();
  @$core.pragma('dart2js:noInline')
  static EncryptedSecret getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EncryptedSecret>(create);
  static EncryptedSecret? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get id => $_getN(0);
  @$pb.TagNumber(1)
  set id($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get share => $_getN(1);
  @$pb.TagNumber(2)
  set share($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShare() => $_has(1);
  @$pb.TagNumber(2)
  void clearShare() => $_clearField(2);
}

class SecretShare extends $pb.GeneratedMessage {
  factory SecretShare({
    $core.List<$core.int>? sid,
    $core.List<$core.int>? groupKey,
    $core.Iterable<EncryptedSecret>? secrets,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (groupKey != null) result.groupKey = groupKey;
    if (secrets != null) result.secrets.addAll(secrets);
    return result;
  }

  SecretShare._();

  factory SecretShare.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SecretShare.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SecretShare',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'groupKey', $pb.PbFieldType.OY)
    ..pc<EncryptedSecret>(
        3, _omitFieldNames ? '' : 'secrets', $pb.PbFieldType.PM,
        subBuilder: EncryptedSecret.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecretShare clone() => SecretShare()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecretShare copyWith(void Function(SecretShare) updates) =>
      super.copyWith((message) => updates(message as SecretShare))
          as SecretShare;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SecretShare create() => SecretShare._();
  @$core.override
  SecretShare createEmptyInstance() => create();
  static $pb.PbList<SecretShare> createRepeated() => $pb.PbList<SecretShare>();
  @$core.pragma('dart2js:noInline')
  static SecretShare getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SecretShare>(create);
  static SecretShare? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get groupKey => $_getN(1);
  @$pb.TagNumber(2)
  set groupKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGroupKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroupKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<EncryptedSecret> get secrets => $_getList(2);
}

class ConstructedKey extends $pb.GeneratedMessage {
  factory ConstructedKey({
    $core.List<$core.int>? sid,
    $core.List<$core.int>? constructedKey,
  }) {
    final result = create();
    if (sid != null) result.sid = sid;
    if (constructedKey != null) result.constructedKey = constructedKey;
    return result;
  }

  ConstructedKey._();

  factory ConstructedKey.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConstructedKey.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConstructedKey',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'constructedKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConstructedKey clone() => ConstructedKey()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConstructedKey copyWith(void Function(ConstructedKey) updates) =>
      super.copyWith((message) => updates(message as ConstructedKey))
          as ConstructedKey;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConstructedKey create() => ConstructedKey._();
  @$core.override
  ConstructedKey createEmptyInstance() => create();
  static $pb.PbList<ConstructedKey> createRepeated() =>
      $pb.PbList<ConstructedKey>();
  @$core.pragma('dart2js:noInline')
  static ConstructedKey getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConstructedKey>(create);
  static ConstructedKey? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sid => $_getN(0);
  @$pb.TagNumber(1)
  set sid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get constructedKey => $_getN(1);
  @$pb.TagNumber(2)
  set constructedKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConstructedKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearConstructedKey() => $_clearField(2);
}

class Events extends $pb.GeneratedMessage {
  factory Events({
    EventType? type,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (data != null) result.data = data;
    return result;
  }

  Events._();

  factory Events.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Events.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Events',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..e<EventType>(1, _omitFieldNames ? '' : 'type', $pb.PbFieldType.OE,
        defaultOrMaker: EventType.PARTICIPANT_STATUS_EVENT,
        valueOf: EventType.valueOf,
        enumValues: EventType.values)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Events clone() => Events()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Events copyWith(void Function(Events) updates) =>
      super.copyWith((message) => updates(message as Events)) as Events;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Events create() => Events._();
  @$core.override
  Events createEmptyInstance() => create();
  static $pb.PbList<Events> createRepeated() => $pb.PbList<Events>();
  @$core.pragma('dart2js:noInline')
  static Events getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Events>(create);
  static Events? _defaultInstance;

  @$pb.TagNumber(1)
  EventType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(EventType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

class ProtocolError extends $pb.GeneratedMessage {
  factory ProtocolError({
    ProtocolErrorCode? code,
    $core.String? message,
    $core.bool? retryable,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    if (retryable != null) result.retryable = retryable;
    return result;
  }

  ProtocolError._();

  factory ProtocolError.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProtocolError.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtocolError',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..e<ProtocolErrorCode>(1, _omitFieldNames ? '' : 'code', $pb.PbFieldType.OE,
        defaultOrMaker: ProtocolErrorCode.PROTOCOL_ERROR_UNSPECIFIED,
        valueOf: ProtocolErrorCode.valueOf,
        enumValues: ProtocolErrorCode.values)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOB(3, _omitFieldNames ? '' : 'retryable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolError clone() => ProtocolError()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolError copyWith(void Function(ProtocolError) updates) =>
      super.copyWith((message) => updates(message as ProtocolError))
          as ProtocolError;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtocolError create() => ProtocolError._();
  @$core.override
  ProtocolError createEmptyInstance() => create();
  static $pb.PbList<ProtocolError> createRepeated() =>
      $pb.PbList<ProtocolError>();
  @$core.pragma('dart2js:noInline')
  static ProtocolError getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProtocolError>(create);
  static ProtocolError? _defaultInstance;

  @$pb.TagNumber(1)
  ProtocolErrorCode get code => $_getN(0);
  @$pb.TagNumber(1)
  set code(ProtocolErrorCode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get retryable => $_getBF(2);
  @$pb.TagNumber(3)
  set retryable($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRetryable() => $_has(2);
  @$pb.TagNumber(3)
  void clearRetryable() => $_clearField(3);
}

/// Successful result for operations which intentionally return no value.
class EmptySuccess extends $pb.GeneratedMessage {
  factory EmptySuccess() => create();

  EmptySuccess._();

  factory EmptySuccess.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EmptySuccess.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EmptySuccess',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EmptySuccess clone() => EmptySuccess()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EmptySuccess copyWith(void Function(EmptySuccess) updates) =>
      super.copyWith((message) => updates(message as EmptySuccess))
          as EmptySuccess;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EmptySuccess create() => EmptySuccess._();
  @$core.override
  EmptySuccess createEmptyInstance() => create();
  static $pb.PbList<EmptySuccess> createRepeated() =>
      $pb.PbList<EmptySuccess>();
  @$core.pragma('dart2js:noInline')
  static EmptySuccess getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EmptySuccess>(create);
  static EmptySuccess? _defaultInstance;
}

class LoginResponse extends $pb.GeneratedMessage {
  factory LoginResponse({
    $core.List<$core.int>? challenge,
  }) {
    final result = create();
    if (challenge != null) result.challenge = challenge;
    return result;
  }

  LoginResponse._();

  factory LoginResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'challenge', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginResponse clone() => LoginResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginResponse copyWith(void Function(LoginResponse) updates) =>
      super.copyWith((message) => updates(message as LoginResponse))
          as LoginResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginResponse create() => LoginResponse._();
  @$core.override
  LoginResponse createEmptyInstance() => create();
  static $pb.PbList<LoginResponse> createRepeated() =>
      $pb.PbList<LoginResponse>();
  @$core.pragma('dart2js:noInline')
  static LoginResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginResponse>(create);
  static LoginResponse? _defaultInstance;

  /// Serialized ExpirableAuthChallengeResponse domain object.
  @$pb.TagNumber(1)
  $core.List<$core.int> get challenge => $_getN(0);
  @$pb.TagNumber(1)
  set challenge($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChallenge() => $_has(0);
  @$pb.TagNumber(1)
  void clearChallenge() => $_clearField(1);
}

class RespondToChallengeResponse extends $pb.GeneratedMessage {
  factory RespondToChallengeResponse({
    EmptySuccess? authenticated,
  }) {
    final result = create();
    if (authenticated != null) result.authenticated = authenticated;
    return result;
  }

  RespondToChallengeResponse._();

  factory RespondToChallengeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RespondToChallengeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespondToChallengeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'authenticated',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespondToChallengeResponse clone() =>
      RespondToChallengeResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespondToChallengeResponse copyWith(
          void Function(RespondToChallengeResponse) updates) =>
      super.copyWith(
              (message) => updates(message as RespondToChallengeResponse))
          as RespondToChallengeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RespondToChallengeResponse create() => RespondToChallengeResponse._();
  @$core.override
  RespondToChallengeResponse createEmptyInstance() => create();
  static $pb.PbList<RespondToChallengeResponse> createRepeated() =>
      $pb.PbList<RespondToChallengeResponse>();
  @$core.pragma('dart2js:noInline')
  static RespondToChallengeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespondToChallengeResponse>(create);
  static RespondToChallengeResponse? _defaultInstance;

  /// Authentication succeeded; StartSession follows on the session stream.
  @$pb.TagNumber(1)
  EmptySuccess get authenticated => $_getN(0);
  @$pb.TagNumber(1)
  set authenticated(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthenticated() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthenticated() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureAuthenticated() => $_ensure(0);
}

class ExtendSessionResponse extends $pb.GeneratedMessage {
  factory ExtendSessionResponse({
    $core.List<$core.int>? expiry,
  }) {
    final result = create();
    if (expiry != null) result.expiry = expiry;
    return result;
  }

  ExtendSessionResponse._();

  factory ExtendSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExtendSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExtendSessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'expiry', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExtendSessionResponse clone() =>
      ExtendSessionResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExtendSessionResponse copyWith(
          void Function(ExtendSessionResponse) updates) =>
      super.copyWith((message) => updates(message as ExtendSessionResponse))
          as ExtendSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExtendSessionResponse create() => ExtendSessionResponse._();
  @$core.override
  ExtendSessionResponse createEmptyInstance() => create();
  static $pb.PbList<ExtendSessionResponse> createRepeated() =>
      $pb.PbList<ExtendSessionResponse>();
  @$core.pragma('dart2js:noInline')
  static ExtendSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExtendSessionResponse>(create);
  static ExtendSessionResponse? _defaultInstance;

  /// Serialized Expiry domain object.
  @$pb.TagNumber(1)
  $core.List<$core.int> get expiry => $_getN(0);
  @$pb.TagNumber(1)
  set expiry($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExpiry() => $_has(0);
  @$pb.TagNumber(1)
  void clearExpiry() => $_clearField(1);
}

class RequestNewDkgResponse extends $pb.GeneratedMessage {
  factory RequestNewDkgResponse({
    EmptySuccess? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  RequestNewDkgResponse._();

  factory RequestNewDkgResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RequestNewDkgResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestNewDkgResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'success',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestNewDkgResponse clone() =>
      RequestNewDkgResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestNewDkgResponse copyWith(
          void Function(RequestNewDkgResponse) updates) =>
      super.copyWith((message) => updates(message as RequestNewDkgResponse))
          as RequestNewDkgResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestNewDkgResponse create() => RequestNewDkgResponse._();
  @$core.override
  RequestNewDkgResponse createEmptyInstance() => create();
  static $pb.PbList<RequestNewDkgResponse> createRepeated() =>
      $pb.PbList<RequestNewDkgResponse>();
  @$core.pragma('dart2js:noInline')
  static RequestNewDkgResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RequestNewDkgResponse>(create);
  static RequestNewDkgResponse? _defaultInstance;

  @$pb.TagNumber(1)
  EmptySuccess get success => $_getN(0);
  @$pb.TagNumber(1)
  set success(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureSuccess() => $_ensure(0);
}

class RejectDkgResponse extends $pb.GeneratedMessage {
  factory RejectDkgResponse({
    EmptySuccess? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  RejectDkgResponse._();

  factory RejectDkgResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RejectDkgResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RejectDkgResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'success',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RejectDkgResponse clone() => RejectDkgResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RejectDkgResponse copyWith(void Function(RejectDkgResponse) updates) =>
      super.copyWith((message) => updates(message as RejectDkgResponse))
          as RejectDkgResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RejectDkgResponse create() => RejectDkgResponse._();
  @$core.override
  RejectDkgResponse createEmptyInstance() => create();
  static $pb.PbList<RejectDkgResponse> createRepeated() =>
      $pb.PbList<RejectDkgResponse>();
  @$core.pragma('dart2js:noInline')
  static RejectDkgResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RejectDkgResponse>(create);
  static RejectDkgResponse? _defaultInstance;

  @$pb.TagNumber(1)
  EmptySuccess get success => $_getN(0);
  @$pb.TagNumber(1)
  set success(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureSuccess() => $_ensure(0);
}

class SubmitDkgCommitmentResponse extends $pb.GeneratedMessage {
  factory SubmitDkgCommitmentResponse({
    EmptySuccess? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  SubmitDkgCommitmentResponse._();

  factory SubmitDkgCommitmentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitDkgCommitmentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitDkgCommitmentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'success',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitDkgCommitmentResponse clone() =>
      SubmitDkgCommitmentResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitDkgCommitmentResponse copyWith(
          void Function(SubmitDkgCommitmentResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SubmitDkgCommitmentResponse))
          as SubmitDkgCommitmentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitDkgCommitmentResponse create() =>
      SubmitDkgCommitmentResponse._();
  @$core.override
  SubmitDkgCommitmentResponse createEmptyInstance() => create();
  static $pb.PbList<SubmitDkgCommitmentResponse> createRepeated() =>
      $pb.PbList<SubmitDkgCommitmentResponse>();
  @$core.pragma('dart2js:noInline')
  static SubmitDkgCommitmentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitDkgCommitmentResponse>(create);
  static SubmitDkgCommitmentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  EmptySuccess get success => $_getN(0);
  @$pb.TagNumber(1)
  set success(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureSuccess() => $_ensure(0);
}

class SubmitDkgRound2Response extends $pb.GeneratedMessage {
  factory SubmitDkgRound2Response({
    EmptySuccess? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  SubmitDkgRound2Response._();

  factory SubmitDkgRound2Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitDkgRound2Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitDkgRound2Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'success',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitDkgRound2Response clone() =>
      SubmitDkgRound2Response()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitDkgRound2Response copyWith(
          void Function(SubmitDkgRound2Response) updates) =>
      super.copyWith((message) => updates(message as SubmitDkgRound2Response))
          as SubmitDkgRound2Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitDkgRound2Response create() => SubmitDkgRound2Response._();
  @$core.override
  SubmitDkgRound2Response createEmptyInstance() => create();
  static $pb.PbList<SubmitDkgRound2Response> createRepeated() =>
      $pb.PbList<SubmitDkgRound2Response>();
  @$core.pragma('dart2js:noInline')
  static SubmitDkgRound2Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitDkgRound2Response>(create);
  static SubmitDkgRound2Response? _defaultInstance;

  @$pb.TagNumber(1)
  EmptySuccess get success => $_getN(0);
  @$pb.TagNumber(1)
  set success(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureSuccess() => $_ensure(0);
}

class SendDkgAcksResponse extends $pb.GeneratedMessage {
  factory SendDkgAcksResponse({
    EmptySuccess? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  SendDkgAcksResponse._();

  factory SendDkgAcksResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendDkgAcksResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendDkgAcksResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'success',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendDkgAcksResponse clone() => SendDkgAcksResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendDkgAcksResponse copyWith(void Function(SendDkgAcksResponse) updates) =>
      super.copyWith((message) => updates(message as SendDkgAcksResponse))
          as SendDkgAcksResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendDkgAcksResponse create() => SendDkgAcksResponse._();
  @$core.override
  SendDkgAcksResponse createEmptyInstance() => create();
  static $pb.PbList<SendDkgAcksResponse> createRepeated() =>
      $pb.PbList<SendDkgAcksResponse>();
  @$core.pragma('dart2js:noInline')
  static SendDkgAcksResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendDkgAcksResponse>(create);
  static SendDkgAcksResponse? _defaultInstance;

  @$pb.TagNumber(1)
  EmptySuccess get success => $_getN(0);
  @$pb.TagNumber(1)
  set success(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureSuccess() => $_ensure(0);
}

class RequestDkgAcksResponse extends $pb.GeneratedMessage {
  factory RequestDkgAcksResponse({
    $core.Iterable<$core.List<$core.int>>? acks,
  }) {
    final result = create();
    if (acks != null) result.acks.addAll(acks);
    return result;
  }

  RequestDkgAcksResponse._();

  factory RequestDkgAcksResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RequestDkgAcksResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestDkgAcksResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..p<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'acks', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestDkgAcksResponse clone() =>
      RequestDkgAcksResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestDkgAcksResponse copyWith(
          void Function(RequestDkgAcksResponse) updates) =>
      super.copyWith((message) => updates(message as RequestDkgAcksResponse))
          as RequestDkgAcksResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestDkgAcksResponse create() => RequestDkgAcksResponse._();
  @$core.override
  RequestDkgAcksResponse createEmptyInstance() => create();
  static $pb.PbList<RequestDkgAcksResponse> createRepeated() =>
      $pb.PbList<RequestDkgAcksResponse>();
  @$core.pragma('dart2js:noInline')
  static RequestDkgAcksResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RequestDkgAcksResponse>(create);
  static RequestDkgAcksResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.List<$core.int>> get acks => $_getList(0);
}

class RequestSignaturesResponse extends $pb.GeneratedMessage {
  factory RequestSignaturesResponse({
    EmptySuccess? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  RequestSignaturesResponse._();

  factory RequestSignaturesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RequestSignaturesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestSignaturesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'success',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestSignaturesResponse clone() =>
      RequestSignaturesResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestSignaturesResponse copyWith(
          void Function(RequestSignaturesResponse) updates) =>
      super.copyWith((message) => updates(message as RequestSignaturesResponse))
          as RequestSignaturesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestSignaturesResponse create() => RequestSignaturesResponse._();
  @$core.override
  RequestSignaturesResponse createEmptyInstance() => create();
  static $pb.PbList<RequestSignaturesResponse> createRepeated() =>
      $pb.PbList<RequestSignaturesResponse>();
  @$core.pragma('dart2js:noInline')
  static RequestSignaturesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RequestSignaturesResponse>(create);
  static RequestSignaturesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  EmptySuccess get success => $_getN(0);
  @$pb.TagNumber(1)
  set success(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureSuccess() => $_ensure(0);
}

class RejectSignaturesRequestResponse extends $pb.GeneratedMessage {
  factory RejectSignaturesRequestResponse({
    EmptySuccess? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  RejectSignaturesRequestResponse._();

  factory RejectSignaturesRequestResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RejectSignaturesRequestResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RejectSignaturesRequestResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'success',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RejectSignaturesRequestResponse clone() =>
      RejectSignaturesRequestResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RejectSignaturesRequestResponse copyWith(
          void Function(RejectSignaturesRequestResponse) updates) =>
      super.copyWith(
              (message) => updates(message as RejectSignaturesRequestResponse))
          as RejectSignaturesRequestResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RejectSignaturesRequestResponse create() =>
      RejectSignaturesRequestResponse._();
  @$core.override
  RejectSignaturesRequestResponse createEmptyInstance() => create();
  static $pb.PbList<RejectSignaturesRequestResponse> createRepeated() =>
      $pb.PbList<RejectSignaturesRequestResponse>();
  @$core.pragma('dart2js:noInline')
  static RejectSignaturesRequestResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RejectSignaturesRequestResponse>(
          create);
  static RejectSignaturesRequestResponse? _defaultInstance;

  @$pb.TagNumber(1)
  EmptySuccess get success => $_getN(0);
  @$pb.TagNumber(1)
  set success(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureSuccess() => $_ensure(0);
}

class NoSignatureUpdate extends $pb.GeneratedMessage {
  factory NoSignatureUpdate() => create();

  NoSignatureUpdate._();

  factory NoSignatureUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NoSignatureUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NoSignatureUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoSignatureUpdate clone() => NoSignatureUpdate()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoSignatureUpdate copyWith(void Function(NoSignatureUpdate) updates) =>
      super.copyWith((message) => updates(message as NoSignatureUpdate))
          as NoSignatureUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NoSignatureUpdate create() => NoSignatureUpdate._();
  @$core.override
  NoSignatureUpdate createEmptyInstance() => create();
  static $pb.PbList<NoSignatureUpdate> createRepeated() =>
      $pb.PbList<NoSignatureUpdate>();
  @$core.pragma('dart2js:noInline')
  static NoSignatureUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NoSignatureUpdate>(create);
  static NoSignatureUpdate? _defaultInstance;
}

class NewSignatureRound extends $pb.GeneratedMessage {
  factory NewSignatureRound({
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (data != null) result.data = data;
    return result;
  }

  NewSignatureRound._();

  factory NewSignatureRound.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NewSignatureRound.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NewSignatureRound',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NewSignatureRound clone() => NewSignatureRound()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NewSignatureRound copyWith(void Function(NewSignatureRound) updates) =>
      super.copyWith((message) => updates(message as NewSignatureRound))
          as NewSignatureRound;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NewSignatureRound create() => NewSignatureRound._();
  @$core.override
  NewSignatureRound createEmptyInstance() => create();
  static $pb.PbList<NewSignatureRound> createRepeated() =>
      $pb.PbList<NewSignatureRound>();
  @$core.pragma('dart2js:noInline')
  static NewSignatureRound getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NewSignatureRound>(create);
  static NewSignatureRound? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
}

class CompletedSignatures extends $pb.GeneratedMessage {
  factory CompletedSignatures({
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (data != null) result.data = data;
    return result;
  }

  CompletedSignatures._();

  factory CompletedSignatures.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompletedSignatures.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompletedSignatures',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompletedSignatures clone() => CompletedSignatures()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompletedSignatures copyWith(void Function(CompletedSignatures) updates) =>
      super.copyWith((message) => updates(message as CompletedSignatures))
          as CompletedSignatures;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompletedSignatures create() => CompletedSignatures._();
  @$core.override
  CompletedSignatures createEmptyInstance() => create();
  static $pb.PbList<CompletedSignatures> createRepeated() =>
      $pb.PbList<CompletedSignatures>();
  @$core.pragma('dart2js:noInline')
  static CompletedSignatures getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompletedSignatures>(create);
  static CompletedSignatures? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
}

enum SubmitSignatureRepliesResponse_Outcome {
  noUpdate,
  newRound,
  completed,
  notSet
}

class SubmitSignatureRepliesResponse extends $pb.GeneratedMessage {
  factory SubmitSignatureRepliesResponse({
    NoSignatureUpdate? noUpdate,
    NewSignatureRound? newRound,
    CompletedSignatures? completed,
  }) {
    final result = create();
    if (noUpdate != null) result.noUpdate = noUpdate;
    if (newRound != null) result.newRound = newRound;
    if (completed != null) result.completed = completed;
    return result;
  }

  SubmitSignatureRepliesResponse._();

  factory SubmitSignatureRepliesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitSignatureRepliesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SubmitSignatureRepliesResponse_Outcome>
      _SubmitSignatureRepliesResponse_OutcomeByTag = {
    1: SubmitSignatureRepliesResponse_Outcome.noUpdate,
    2: SubmitSignatureRepliesResponse_Outcome.newRound,
    3: SubmitSignatureRepliesResponse_Outcome.completed,
    0: SubmitSignatureRepliesResponse_Outcome.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitSignatureRepliesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..aOM<NoSignatureUpdate>(1, _omitFieldNames ? '' : 'noUpdate',
        subBuilder: NoSignatureUpdate.create)
    ..aOM<NewSignatureRound>(2, _omitFieldNames ? '' : 'newRound',
        subBuilder: NewSignatureRound.create)
    ..aOM<CompletedSignatures>(3, _omitFieldNames ? '' : 'completed',
        subBuilder: CompletedSignatures.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitSignatureRepliesResponse clone() =>
      SubmitSignatureRepliesResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitSignatureRepliesResponse copyWith(
          void Function(SubmitSignatureRepliesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SubmitSignatureRepliesResponse))
          as SubmitSignatureRepliesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitSignatureRepliesResponse create() =>
      SubmitSignatureRepliesResponse._();
  @$core.override
  SubmitSignatureRepliesResponse createEmptyInstance() => create();
  static $pb.PbList<SubmitSignatureRepliesResponse> createRepeated() =>
      $pb.PbList<SubmitSignatureRepliesResponse>();
  @$core.pragma('dart2js:noInline')
  static SubmitSignatureRepliesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitSignatureRepliesResponse>(create);
  static SubmitSignatureRepliesResponse? _defaultInstance;

  SubmitSignatureRepliesResponse_Outcome whichOutcome() =>
      _SubmitSignatureRepliesResponse_OutcomeByTag[$_whichOneof(0)]!;
  void clearOutcome() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  NoSignatureUpdate get noUpdate => $_getN(0);
  @$pb.TagNumber(1)
  set noUpdate(NoSignatureUpdate value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNoUpdate() => $_has(0);
  @$pb.TagNumber(1)
  void clearNoUpdate() => $_clearField(1);
  @$pb.TagNumber(1)
  NoSignatureUpdate ensureNoUpdate() => $_ensure(0);

  @$pb.TagNumber(2)
  NewSignatureRound get newRound => $_getN(1);
  @$pb.TagNumber(2)
  set newRound(NewSignatureRound value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNewRound() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewRound() => $_clearField(2);
  @$pb.TagNumber(2)
  NewSignatureRound ensureNewRound() => $_ensure(1);

  @$pb.TagNumber(3)
  CompletedSignatures get completed => $_getN(2);
  @$pb.TagNumber(3)
  set completed(CompletedSignatures value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCompleted() => $_has(2);
  @$pb.TagNumber(3)
  void clearCompleted() => $_clearField(3);
  @$pb.TagNumber(3)
  CompletedSignatures ensureCompleted() => $_ensure(2);
}

class ShareSecretShareResponse extends $pb.GeneratedMessage {
  factory ShareSecretShareResponse({
    $core.Iterable<$core.List<$core.int>>? constructedKeyEvents,
  }) {
    final result = create();
    if (constructedKeyEvents != null)
      result.constructedKeyEvents.addAll(constructedKeyEvents);
    return result;
  }

  ShareSecretShareResponse._();

  factory ShareSecretShareResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShareSecretShareResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareSecretShareResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..p<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'constructedKeyEvents', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareSecretShareResponse clone() =>
      ShareSecretShareResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareSecretShareResponse copyWith(
          void Function(ShareSecretShareResponse) updates) =>
      super.copyWith((message) => updates(message as ShareSecretShareResponse))
          as ShareSecretShareResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShareSecretShareResponse create() => ShareSecretShareResponse._();
  @$core.override
  ShareSecretShareResponse createEmptyInstance() => create();
  static $pb.PbList<ShareSecretShareResponse> createRepeated() =>
      $pb.PbList<ShareSecretShareResponse>();
  @$core.pragma('dart2js:noInline')
  static ShareSecretShareResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShareSecretShareResponse>(create);
  static ShareSecretShareResponse? _defaultInstance;

  /// Serialized ConstructedKeyEvent domain objects.
  @$pb.TagNumber(1)
  $pb.PbList<$core.List<$core.int>> get constructedKeyEvents => $_getList(0);
}

class AckKeyConstructedResponse extends $pb.GeneratedMessage {
  factory AckKeyConstructedResponse({
    EmptySuccess? success,
  }) {
    final result = create();
    if (success != null) result.success = success;
    return result;
  }

  AckKeyConstructedResponse._();

  factory AckKeyConstructedResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AckKeyConstructedResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AckKeyConstructedResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOM<EmptySuccess>(1, _omitFieldNames ? '' : 'success',
        subBuilder: EmptySuccess.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AckKeyConstructedResponse clone() =>
      AckKeyConstructedResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AckKeyConstructedResponse copyWith(
          void Function(AckKeyConstructedResponse) updates) =>
      super.copyWith((message) => updates(message as AckKeyConstructedResponse))
          as AckKeyConstructedResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AckKeyConstructedResponse create() => AckKeyConstructedResponse._();
  @$core.override
  AckKeyConstructedResponse createEmptyInstance() => create();
  static $pb.PbList<AckKeyConstructedResponse> createRepeated() =>
      $pb.PbList<AckKeyConstructedResponse>();
  @$core.pragma('dart2js:noInline')
  static AckKeyConstructedResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AckKeyConstructedResponse>(create);
  static AckKeyConstructedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  EmptySuccess get success => $_getN(0);
  @$pb.TagNumber(1)
  set success(EmptySuccess value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
  @$pb.TagNumber(1)
  EmptySuccess ensureSuccess() => $_ensure(0);
}

enum RpcRequest_Request {
  login,
  respondToChallenge,
  extendSession,
  requestNewDkg,
  rejectDkg,
  submitDkgCommitment,
  submitDkgRound2,
  sendDkgAcks,
  requestDkgAcks,
  requestSignatures,
  rejectSignaturesRequest,
  submitSignatureReplies,
  shareSecretShare,
  ackKeyConstructed,
  notSet
}

class RpcRequest extends $pb.GeneratedMessage {
  factory RpcRequest({
    $core.List<$core.int>? requestId,
    LoginRequest? login,
    SignedAuthChallenge? respondToChallenge,
    Bytes? extendSession,
    DkgRequest? requestNewDkg,
    DkgToReject? rejectDkg,
    DkgCommitment? submitDkgCommitment,
    DkgRound2? submitDkgRound2,
    DkgAcks? sendDkgAcks,
    DkgAckRequest? requestDkgAcks,
    SignaturesRequest? requestSignatures,
    SignaturesRejection? rejectSignaturesRequest,
    SignaturesReplies? submitSignatureReplies,
    SecretShare? shareSecretShare,
    ConstructedKey? ackKeyConstructed,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (login != null) result.login = login;
    if (respondToChallenge != null)
      result.respondToChallenge = respondToChallenge;
    if (extendSession != null) result.extendSession = extendSession;
    if (requestNewDkg != null) result.requestNewDkg = requestNewDkg;
    if (rejectDkg != null) result.rejectDkg = rejectDkg;
    if (submitDkgCommitment != null)
      result.submitDkgCommitment = submitDkgCommitment;
    if (submitDkgRound2 != null) result.submitDkgRound2 = submitDkgRound2;
    if (sendDkgAcks != null) result.sendDkgAcks = sendDkgAcks;
    if (requestDkgAcks != null) result.requestDkgAcks = requestDkgAcks;
    if (requestSignatures != null) result.requestSignatures = requestSignatures;
    if (rejectSignaturesRequest != null)
      result.rejectSignaturesRequest = rejectSignaturesRequest;
    if (submitSignatureReplies != null)
      result.submitSignatureReplies = submitSignatureReplies;
    if (shareSecretShare != null) result.shareSecretShare = shareSecretShare;
    if (ackKeyConstructed != null) result.ackKeyConstructed = ackKeyConstructed;
    return result;
  }

  RpcRequest._();

  factory RpcRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RpcRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RpcRequest_Request>
      _RpcRequest_RequestByTag = {
    10: RpcRequest_Request.login,
    11: RpcRequest_Request.respondToChallenge,
    12: RpcRequest_Request.extendSession,
    13: RpcRequest_Request.requestNewDkg,
    14: RpcRequest_Request.rejectDkg,
    15: RpcRequest_Request.submitDkgCommitment,
    16: RpcRequest_Request.submitDkgRound2,
    17: RpcRequest_Request.sendDkgAcks,
    18: RpcRequest_Request.requestDkgAcks,
    19: RpcRequest_Request.requestSignatures,
    20: RpcRequest_Request.rejectSignaturesRequest,
    21: RpcRequest_Request.submitSignatureReplies,
    22: RpcRequest_Request.shareSecretShare,
    23: RpcRequest_Request.ackKeyConstructed,
    0: RpcRequest_Request.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RpcRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23])
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.OY)
    ..aOM<LoginRequest>(10, _omitFieldNames ? '' : 'login',
        subBuilder: LoginRequest.create)
    ..aOM<SignedAuthChallenge>(11, _omitFieldNames ? '' : 'respondToChallenge',
        subBuilder: SignedAuthChallenge.create)
    ..aOM<Bytes>(12, _omitFieldNames ? '' : 'extendSession',
        subBuilder: Bytes.create)
    ..aOM<DkgRequest>(13, _omitFieldNames ? '' : 'requestNewDkg',
        subBuilder: DkgRequest.create)
    ..aOM<DkgToReject>(14, _omitFieldNames ? '' : 'rejectDkg',
        subBuilder: DkgToReject.create)
    ..aOM<DkgCommitment>(15, _omitFieldNames ? '' : 'submitDkgCommitment',
        subBuilder: DkgCommitment.create)
    ..aOM<DkgRound2>(16, _omitFieldNames ? '' : 'submitDkgRound2',
        subBuilder: DkgRound2.create)
    ..aOM<DkgAcks>(17, _omitFieldNames ? '' : 'sendDkgAcks',
        subBuilder: DkgAcks.create)
    ..aOM<DkgAckRequest>(18, _omitFieldNames ? '' : 'requestDkgAcks',
        subBuilder: DkgAckRequest.create)
    ..aOM<SignaturesRequest>(19, _omitFieldNames ? '' : 'requestSignatures',
        subBuilder: SignaturesRequest.create)
    ..aOM<SignaturesRejection>(
        20, _omitFieldNames ? '' : 'rejectSignaturesRequest',
        subBuilder: SignaturesRejection.create)
    ..aOM<SignaturesReplies>(
        21, _omitFieldNames ? '' : 'submitSignatureReplies',
        subBuilder: SignaturesReplies.create)
    ..aOM<SecretShare>(22, _omitFieldNames ? '' : 'shareSecretShare',
        subBuilder: SecretShare.create)
    ..aOM<ConstructedKey>(23, _omitFieldNames ? '' : 'ackKeyConstructed',
        subBuilder: ConstructedKey.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RpcRequest clone() => RpcRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RpcRequest copyWith(void Function(RpcRequest) updates) =>
      super.copyWith((message) => updates(message as RpcRequest)) as RpcRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RpcRequest create() => RpcRequest._();
  @$core.override
  RpcRequest createEmptyInstance() => create();
  static $pb.PbList<RpcRequest> createRepeated() => $pb.PbList<RpcRequest>();
  @$core.pragma('dart2js:noInline')
  static RpcRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RpcRequest>(create);
  static RpcRequest? _defaultInstance;

  RpcRequest_Request whichRequest() =>
      _RpcRequest_RequestByTag[$_whichOneof(0)]!;
  void clearRequest() => $_clearField($_whichOneof(0));

  /// Opaque, non-empty identifier generated by the caller. It is stable across
  /// retries and scoped to the logical session.
  @$pb.TagNumber(1)
  $core.List<$core.int> get requestId => $_getN(0);
  @$pb.TagNumber(1)
  set requestId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(10)
  LoginRequest get login => $_getN(1);
  @$pb.TagNumber(10)
  set login(LoginRequest value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasLogin() => $_has(1);
  @$pb.TagNumber(10)
  void clearLogin() => $_clearField(10);
  @$pb.TagNumber(10)
  LoginRequest ensureLogin() => $_ensure(1);

  @$pb.TagNumber(11)
  SignedAuthChallenge get respondToChallenge => $_getN(2);
  @$pb.TagNumber(11)
  set respondToChallenge(SignedAuthChallenge value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRespondToChallenge() => $_has(2);
  @$pb.TagNumber(11)
  void clearRespondToChallenge() => $_clearField(11);
  @$pb.TagNumber(11)
  SignedAuthChallenge ensureRespondToChallenge() => $_ensure(2);

  @$pb.TagNumber(12)
  Bytes get extendSession => $_getN(3);
  @$pb.TagNumber(12)
  set extendSession(Bytes value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasExtendSession() => $_has(3);
  @$pb.TagNumber(12)
  void clearExtendSession() => $_clearField(12);
  @$pb.TagNumber(12)
  Bytes ensureExtendSession() => $_ensure(3);

  @$pb.TagNumber(13)
  DkgRequest get requestNewDkg => $_getN(4);
  @$pb.TagNumber(13)
  set requestNewDkg(DkgRequest value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRequestNewDkg() => $_has(4);
  @$pb.TagNumber(13)
  void clearRequestNewDkg() => $_clearField(13);
  @$pb.TagNumber(13)
  DkgRequest ensureRequestNewDkg() => $_ensure(4);

  @$pb.TagNumber(14)
  DkgToReject get rejectDkg => $_getN(5);
  @$pb.TagNumber(14)
  set rejectDkg(DkgToReject value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasRejectDkg() => $_has(5);
  @$pb.TagNumber(14)
  void clearRejectDkg() => $_clearField(14);
  @$pb.TagNumber(14)
  DkgToReject ensureRejectDkg() => $_ensure(5);

  @$pb.TagNumber(15)
  DkgCommitment get submitDkgCommitment => $_getN(6);
  @$pb.TagNumber(15)
  set submitDkgCommitment(DkgCommitment value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasSubmitDkgCommitment() => $_has(6);
  @$pb.TagNumber(15)
  void clearSubmitDkgCommitment() => $_clearField(15);
  @$pb.TagNumber(15)
  DkgCommitment ensureSubmitDkgCommitment() => $_ensure(6);

  @$pb.TagNumber(16)
  DkgRound2 get submitDkgRound2 => $_getN(7);
  @$pb.TagNumber(16)
  set submitDkgRound2(DkgRound2 value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasSubmitDkgRound2() => $_has(7);
  @$pb.TagNumber(16)
  void clearSubmitDkgRound2() => $_clearField(16);
  @$pb.TagNumber(16)
  DkgRound2 ensureSubmitDkgRound2() => $_ensure(7);

  @$pb.TagNumber(17)
  DkgAcks get sendDkgAcks => $_getN(8);
  @$pb.TagNumber(17)
  set sendDkgAcks(DkgAcks value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasSendDkgAcks() => $_has(8);
  @$pb.TagNumber(17)
  void clearSendDkgAcks() => $_clearField(17);
  @$pb.TagNumber(17)
  DkgAcks ensureSendDkgAcks() => $_ensure(8);

  @$pb.TagNumber(18)
  DkgAckRequest get requestDkgAcks => $_getN(9);
  @$pb.TagNumber(18)
  set requestDkgAcks(DkgAckRequest value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasRequestDkgAcks() => $_has(9);
  @$pb.TagNumber(18)
  void clearRequestDkgAcks() => $_clearField(18);
  @$pb.TagNumber(18)
  DkgAckRequest ensureRequestDkgAcks() => $_ensure(9);

  @$pb.TagNumber(19)
  SignaturesRequest get requestSignatures => $_getN(10);
  @$pb.TagNumber(19)
  set requestSignatures(SignaturesRequest value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasRequestSignatures() => $_has(10);
  @$pb.TagNumber(19)
  void clearRequestSignatures() => $_clearField(19);
  @$pb.TagNumber(19)
  SignaturesRequest ensureRequestSignatures() => $_ensure(10);

  @$pb.TagNumber(20)
  SignaturesRejection get rejectSignaturesRequest => $_getN(11);
  @$pb.TagNumber(20)
  set rejectSignaturesRequest(SignaturesRejection value) =>
      $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasRejectSignaturesRequest() => $_has(11);
  @$pb.TagNumber(20)
  void clearRejectSignaturesRequest() => $_clearField(20);
  @$pb.TagNumber(20)
  SignaturesRejection ensureRejectSignaturesRequest() => $_ensure(11);

  @$pb.TagNumber(21)
  SignaturesReplies get submitSignatureReplies => $_getN(12);
  @$pb.TagNumber(21)
  set submitSignatureReplies(SignaturesReplies value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasSubmitSignatureReplies() => $_has(12);
  @$pb.TagNumber(21)
  void clearSubmitSignatureReplies() => $_clearField(21);
  @$pb.TagNumber(21)
  SignaturesReplies ensureSubmitSignatureReplies() => $_ensure(12);

  @$pb.TagNumber(22)
  SecretShare get shareSecretShare => $_getN(13);
  @$pb.TagNumber(22)
  set shareSecretShare(SecretShare value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasShareSecretShare() => $_has(13);
  @$pb.TagNumber(22)
  void clearShareSecretShare() => $_clearField(22);
  @$pb.TagNumber(22)
  SecretShare ensureShareSecretShare() => $_ensure(13);

  @$pb.TagNumber(23)
  ConstructedKey get ackKeyConstructed => $_getN(14);
  @$pb.TagNumber(23)
  set ackKeyConstructed(ConstructedKey value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasAckKeyConstructed() => $_has(14);
  @$pb.TagNumber(23)
  void clearAckKeyConstructed() => $_clearField(23);
  @$pb.TagNumber(23)
  ConstructedKey ensureAckKeyConstructed() => $_ensure(14);
}

enum RpcResponse_Response {
  login,
  respondToChallenge,
  extendSession,
  requestNewDkg,
  rejectDkg,
  submitDkgCommitment,
  submitDkgRound2,
  sendDkgAcks,
  requestDkgAcks,
  requestSignatures,
  rejectSignaturesRequest,
  submitSignatureReplies,
  shareSecretShare,
  ackKeyConstructed,
  error,
  notSet
}

class RpcResponse extends $pb.GeneratedMessage {
  factory RpcResponse({
    $core.List<$core.int>? requestId,
    LoginResponse? login,
    RespondToChallengeResponse? respondToChallenge,
    ExtendSessionResponse? extendSession,
    RequestNewDkgResponse? requestNewDkg,
    RejectDkgResponse? rejectDkg,
    SubmitDkgCommitmentResponse? submitDkgCommitment,
    SubmitDkgRound2Response? submitDkgRound2,
    SendDkgAcksResponse? sendDkgAcks,
    RequestDkgAcksResponse? requestDkgAcks,
    RequestSignaturesResponse? requestSignatures,
    RejectSignaturesRequestResponse? rejectSignaturesRequest,
    SubmitSignatureRepliesResponse? submitSignatureReplies,
    ShareSecretShareResponse? shareSecretShare,
    AckKeyConstructedResponse? ackKeyConstructed,
    ProtocolError? error,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (login != null) result.login = login;
    if (respondToChallenge != null)
      result.respondToChallenge = respondToChallenge;
    if (extendSession != null) result.extendSession = extendSession;
    if (requestNewDkg != null) result.requestNewDkg = requestNewDkg;
    if (rejectDkg != null) result.rejectDkg = rejectDkg;
    if (submitDkgCommitment != null)
      result.submitDkgCommitment = submitDkgCommitment;
    if (submitDkgRound2 != null) result.submitDkgRound2 = submitDkgRound2;
    if (sendDkgAcks != null) result.sendDkgAcks = sendDkgAcks;
    if (requestDkgAcks != null) result.requestDkgAcks = requestDkgAcks;
    if (requestSignatures != null) result.requestSignatures = requestSignatures;
    if (rejectSignaturesRequest != null)
      result.rejectSignaturesRequest = rejectSignaturesRequest;
    if (submitSignatureReplies != null)
      result.submitSignatureReplies = submitSignatureReplies;
    if (shareSecretShare != null) result.shareSecretShare = shareSecretShare;
    if (ackKeyConstructed != null) result.ackKeyConstructed = ackKeyConstructed;
    if (error != null) result.error = error;
    return result;
  }

  RpcResponse._();

  factory RpcResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RpcResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RpcResponse_Response>
      _RpcResponse_ResponseByTag = {
    10: RpcResponse_Response.login,
    11: RpcResponse_Response.respondToChallenge,
    12: RpcResponse_Response.extendSession,
    13: RpcResponse_Response.requestNewDkg,
    14: RpcResponse_Response.rejectDkg,
    15: RpcResponse_Response.submitDkgCommitment,
    16: RpcResponse_Response.submitDkgRound2,
    17: RpcResponse_Response.sendDkgAcks,
    18: RpcResponse_Response.requestDkgAcks,
    19: RpcResponse_Response.requestSignatures,
    20: RpcResponse_Response.rejectSignaturesRequest,
    21: RpcResponse_Response.submitSignatureReplies,
    22: RpcResponse_Response.shareSecretShare,
    23: RpcResponse_Response.ackKeyConstructed,
    100: RpcResponse_Response.error,
    0: RpcResponse_Response.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RpcResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 100])
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.OY)
    ..aOM<LoginResponse>(10, _omitFieldNames ? '' : 'login',
        subBuilder: LoginResponse.create)
    ..aOM<RespondToChallengeResponse>(
        11, _omitFieldNames ? '' : 'respondToChallenge',
        subBuilder: RespondToChallengeResponse.create)
    ..aOM<ExtendSessionResponse>(12, _omitFieldNames ? '' : 'extendSession',
        subBuilder: ExtendSessionResponse.create)
    ..aOM<RequestNewDkgResponse>(13, _omitFieldNames ? '' : 'requestNewDkg',
        subBuilder: RequestNewDkgResponse.create)
    ..aOM<RejectDkgResponse>(14, _omitFieldNames ? '' : 'rejectDkg',
        subBuilder: RejectDkgResponse.create)
    ..aOM<SubmitDkgCommitmentResponse>(
        15, _omitFieldNames ? '' : 'submitDkgCommitment',
        subBuilder: SubmitDkgCommitmentResponse.create)
    ..aOM<SubmitDkgRound2Response>(16, _omitFieldNames ? '' : 'submitDkgRound2',
        subBuilder: SubmitDkgRound2Response.create)
    ..aOM<SendDkgAcksResponse>(17, _omitFieldNames ? '' : 'sendDkgAcks',
        subBuilder: SendDkgAcksResponse.create)
    ..aOM<RequestDkgAcksResponse>(18, _omitFieldNames ? '' : 'requestDkgAcks',
        subBuilder: RequestDkgAcksResponse.create)
    ..aOM<RequestSignaturesResponse>(
        19, _omitFieldNames ? '' : 'requestSignatures',
        subBuilder: RequestSignaturesResponse.create)
    ..aOM<RejectSignaturesRequestResponse>(
        20, _omitFieldNames ? '' : 'rejectSignaturesRequest',
        subBuilder: RejectSignaturesRequestResponse.create)
    ..aOM<SubmitSignatureRepliesResponse>(
        21, _omitFieldNames ? '' : 'submitSignatureReplies',
        subBuilder: SubmitSignatureRepliesResponse.create)
    ..aOM<ShareSecretShareResponse>(
        22, _omitFieldNames ? '' : 'shareSecretShare',
        subBuilder: ShareSecretShareResponse.create)
    ..aOM<AckKeyConstructedResponse>(
        23, _omitFieldNames ? '' : 'ackKeyConstructed',
        subBuilder: AckKeyConstructedResponse.create)
    ..aOM<ProtocolError>(100, _omitFieldNames ? '' : 'error',
        subBuilder: ProtocolError.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RpcResponse clone() => RpcResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RpcResponse copyWith(void Function(RpcResponse) updates) =>
      super.copyWith((message) => updates(message as RpcResponse))
          as RpcResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RpcResponse create() => RpcResponse._();
  @$core.override
  RpcResponse createEmptyInstance() => create();
  static $pb.PbList<RpcResponse> createRepeated() => $pb.PbList<RpcResponse>();
  @$core.pragma('dart2js:noInline')
  static RpcResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RpcResponse>(create);
  static RpcResponse? _defaultInstance;

  RpcResponse_Response whichResponse() =>
      _RpcResponse_ResponseByTag[$_whichOneof(0)]!;
  void clearResponse() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.List<$core.int> get requestId => $_getN(0);
  @$pb.TagNumber(1)
  set requestId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(10)
  LoginResponse get login => $_getN(1);
  @$pb.TagNumber(10)
  set login(LoginResponse value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasLogin() => $_has(1);
  @$pb.TagNumber(10)
  void clearLogin() => $_clearField(10);
  @$pb.TagNumber(10)
  LoginResponse ensureLogin() => $_ensure(1);

  @$pb.TagNumber(11)
  RespondToChallengeResponse get respondToChallenge => $_getN(2);
  @$pb.TagNumber(11)
  set respondToChallenge(RespondToChallengeResponse value) =>
      $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRespondToChallenge() => $_has(2);
  @$pb.TagNumber(11)
  void clearRespondToChallenge() => $_clearField(11);
  @$pb.TagNumber(11)
  RespondToChallengeResponse ensureRespondToChallenge() => $_ensure(2);

  @$pb.TagNumber(12)
  ExtendSessionResponse get extendSession => $_getN(3);
  @$pb.TagNumber(12)
  set extendSession(ExtendSessionResponse value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasExtendSession() => $_has(3);
  @$pb.TagNumber(12)
  void clearExtendSession() => $_clearField(12);
  @$pb.TagNumber(12)
  ExtendSessionResponse ensureExtendSession() => $_ensure(3);

  @$pb.TagNumber(13)
  RequestNewDkgResponse get requestNewDkg => $_getN(4);
  @$pb.TagNumber(13)
  set requestNewDkg(RequestNewDkgResponse value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRequestNewDkg() => $_has(4);
  @$pb.TagNumber(13)
  void clearRequestNewDkg() => $_clearField(13);
  @$pb.TagNumber(13)
  RequestNewDkgResponse ensureRequestNewDkg() => $_ensure(4);

  @$pb.TagNumber(14)
  RejectDkgResponse get rejectDkg => $_getN(5);
  @$pb.TagNumber(14)
  set rejectDkg(RejectDkgResponse value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasRejectDkg() => $_has(5);
  @$pb.TagNumber(14)
  void clearRejectDkg() => $_clearField(14);
  @$pb.TagNumber(14)
  RejectDkgResponse ensureRejectDkg() => $_ensure(5);

  @$pb.TagNumber(15)
  SubmitDkgCommitmentResponse get submitDkgCommitment => $_getN(6);
  @$pb.TagNumber(15)
  set submitDkgCommitment(SubmitDkgCommitmentResponse value) =>
      $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasSubmitDkgCommitment() => $_has(6);
  @$pb.TagNumber(15)
  void clearSubmitDkgCommitment() => $_clearField(15);
  @$pb.TagNumber(15)
  SubmitDkgCommitmentResponse ensureSubmitDkgCommitment() => $_ensure(6);

  @$pb.TagNumber(16)
  SubmitDkgRound2Response get submitDkgRound2 => $_getN(7);
  @$pb.TagNumber(16)
  set submitDkgRound2(SubmitDkgRound2Response value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasSubmitDkgRound2() => $_has(7);
  @$pb.TagNumber(16)
  void clearSubmitDkgRound2() => $_clearField(16);
  @$pb.TagNumber(16)
  SubmitDkgRound2Response ensureSubmitDkgRound2() => $_ensure(7);

  @$pb.TagNumber(17)
  SendDkgAcksResponse get sendDkgAcks => $_getN(8);
  @$pb.TagNumber(17)
  set sendDkgAcks(SendDkgAcksResponse value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasSendDkgAcks() => $_has(8);
  @$pb.TagNumber(17)
  void clearSendDkgAcks() => $_clearField(17);
  @$pb.TagNumber(17)
  SendDkgAcksResponse ensureSendDkgAcks() => $_ensure(8);

  @$pb.TagNumber(18)
  RequestDkgAcksResponse get requestDkgAcks => $_getN(9);
  @$pb.TagNumber(18)
  set requestDkgAcks(RequestDkgAcksResponse value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasRequestDkgAcks() => $_has(9);
  @$pb.TagNumber(18)
  void clearRequestDkgAcks() => $_clearField(18);
  @$pb.TagNumber(18)
  RequestDkgAcksResponse ensureRequestDkgAcks() => $_ensure(9);

  @$pb.TagNumber(19)
  RequestSignaturesResponse get requestSignatures => $_getN(10);
  @$pb.TagNumber(19)
  set requestSignatures(RequestSignaturesResponse value) =>
      $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasRequestSignatures() => $_has(10);
  @$pb.TagNumber(19)
  void clearRequestSignatures() => $_clearField(19);
  @$pb.TagNumber(19)
  RequestSignaturesResponse ensureRequestSignatures() => $_ensure(10);

  @$pb.TagNumber(20)
  RejectSignaturesRequestResponse get rejectSignaturesRequest => $_getN(11);
  @$pb.TagNumber(20)
  set rejectSignaturesRequest(RejectSignaturesRequestResponse value) =>
      $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasRejectSignaturesRequest() => $_has(11);
  @$pb.TagNumber(20)
  void clearRejectSignaturesRequest() => $_clearField(20);
  @$pb.TagNumber(20)
  RejectSignaturesRequestResponse ensureRejectSignaturesRequest() =>
      $_ensure(11);

  @$pb.TagNumber(21)
  SubmitSignatureRepliesResponse get submitSignatureReplies => $_getN(12);
  @$pb.TagNumber(21)
  set submitSignatureReplies(SubmitSignatureRepliesResponse value) =>
      $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasSubmitSignatureReplies() => $_has(12);
  @$pb.TagNumber(21)
  void clearSubmitSignatureReplies() => $_clearField(21);
  @$pb.TagNumber(21)
  SubmitSignatureRepliesResponse ensureSubmitSignatureReplies() => $_ensure(12);

  @$pb.TagNumber(22)
  ShareSecretShareResponse get shareSecretShare => $_getN(13);
  @$pb.TagNumber(22)
  set shareSecretShare(ShareSecretShareResponse value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasShareSecretShare() => $_has(13);
  @$pb.TagNumber(22)
  void clearShareSecretShare() => $_clearField(22);
  @$pb.TagNumber(22)
  ShareSecretShareResponse ensureShareSecretShare() => $_ensure(13);

  @$pb.TagNumber(23)
  AckKeyConstructedResponse get ackKeyConstructed => $_getN(14);
  @$pb.TagNumber(23)
  set ackKeyConstructed(AckKeyConstructedResponse value) =>
      $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasAckKeyConstructed() => $_has(14);
  @$pb.TagNumber(23)
  void clearAckKeyConstructed() => $_clearField(23);
  @$pb.TagNumber(23)
  AckKeyConstructedResponse ensureAckKeyConstructed() => $_ensure(14);

  @$pb.TagNumber(100)
  ProtocolError get error => $_getN(15);
  @$pb.TagNumber(100)
  set error(ProtocolError value) => $_setField(100, value);
  @$pb.TagNumber(100)
  $core.bool hasError() => $_has(15);
  @$pb.TagNumber(100)
  void clearError() => $_clearField(100);
  @$pb.TagNumber(100)
  ProtocolError ensureError() => $_ensure(15);
}

class StartSession extends $pb.GeneratedMessage {
  factory StartSession() => create();

  StartSession._();

  factory StartSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSession clone() => StartSession()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSession copyWith(void Function(StartSession) updates) =>
      super.copyWith((message) => updates(message as StartSession))
          as StartSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartSession create() => StartSession._();
  @$core.override
  StartSession createEmptyInstance() => create();
  static $pb.PbList<StartSession> createRepeated() =>
      $pb.PbList<StartSession>();
  @$core.pragma('dart2js:noInline')
  static StartSession getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartSession>(create);
  static StartSession? _defaultInstance;
}

class SessionStarted extends $pb.GeneratedMessage {
  factory SessionStarted({
    $core.List<$core.int>? sessionId,
    $core.List<$core.int>? snapshot,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (snapshot != null) result.snapshot = snapshot;
    return result;
  }

  SessionStarted._();

  factory SessionStarted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionStarted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionStarted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sessionId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'snapshot', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionStarted clone() => SessionStarted()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionStarted copyWith(void Function(SessionStarted) updates) =>
      super.copyWith((message) => updates(message as SessionStarted))
          as SessionStarted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionStarted create() => SessionStarted._();
  @$core.override
  SessionStarted createEmptyInstance() => create();
  static $pb.PbList<SessionStarted> createRepeated() =>
      $pb.PbList<SessionStarted>();
  @$core.pragma('dart2js:noInline')
  static SessionStarted getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionStarted>(create);
  static SessionStarted? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sessionId => $_getN(0);
  @$pb.TagNumber(1)
  set sessionId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  /// Serialized LoginCompleteResponse domain snapshot.
  @$pb.TagNumber(2)
  $core.List<$core.int> get snapshot => $_getN(1);
  @$pb.TagNumber(2)
  set snapshot($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSnapshot() => $_has(1);
  @$pb.TagNumber(2)
  void clearSnapshot() => $_clearField(2);
}

class Ready extends $pb.GeneratedMessage {
  factory Ready() => create();

  Ready._();

  factory Ready.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ready.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ready',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ready clone() => Ready()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ready copyWith(void Function(Ready) updates) =>
      super.copyWith((message) => updates(message as Ready)) as Ready;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ready create() => Ready._();
  @$core.override
  Ready createEmptyInstance() => create();
  static $pb.PbList<Ready> createRepeated() => $pb.PbList<Ready>();
  @$core.pragma('dart2js:noInline')
  static Ready getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ready>(create);
  static Ready? _defaultInstance;
}

class Logout extends $pb.GeneratedMessage {
  factory Logout({
    $core.List<$core.int>? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  Logout._();

  factory Logout.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Logout.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Logout',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'sessionId', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Logout clone() => Logout()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Logout copyWith(void Function(Logout) updates) =>
      super.copyWith((message) => updates(message as Logout)) as Logout;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Logout create() => Logout._();
  @$core.override
  Logout createEmptyInstance() => create();
  static $pb.PbList<Logout> createRepeated() => $pb.PbList<Logout>();
  @$core.pragma('dart2js:noInline')
  static Logout getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Logout>(create);
  static Logout? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get sessionId => $_getN(0);
  @$pb.TagNumber(1)
  set sessionId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

enum Envelope_Payload {
  rpcRequest,
  rpcResponse,
  startSession,
  sessionStarted,
  ready,
  logout,
  event,
  error,
  notSet
}

class Envelope extends $pb.GeneratedMessage {
  factory Envelope({
    $core.int? wireVersion,
    RpcRequest? rpcRequest,
    RpcResponse? rpcResponse,
    StartSession? startSession,
    SessionStarted? sessionStarted,
    Ready? ready,
    Logout? logout,
    Events? event,
    ProtocolError? error,
  }) {
    final result = create();
    if (wireVersion != null) result.wireVersion = wireVersion;
    if (rpcRequest != null) result.rpcRequest = rpcRequest;
    if (rpcResponse != null) result.rpcResponse = rpcResponse;
    if (startSession != null) result.startSession = startSession;
    if (sessionStarted != null) result.sessionStarted = sessionStarted;
    if (ready != null) result.ready = ready;
    if (logout != null) result.logout = logout;
    if (event != null) result.event = event;
    if (error != null) result.error = error;
    return result;
  }

  Envelope._();

  factory Envelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Envelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Envelope_Payload> _Envelope_PayloadByTag = {
    10: Envelope_Payload.rpcRequest,
    11: Envelope_Payload.rpcResponse,
    20: Envelope_Payload.startSession,
    21: Envelope_Payload.sessionStarted,
    25: Envelope_Payload.ready,
    27: Envelope_Payload.logout,
    28: Envelope_Payload.event,
    29: Envelope_Payload.error,
    0: Envelope_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Envelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 20, 21, 25, 27, 28, 29])
    ..a<$core.int>(1, _omitFieldNames ? '' : 'wireVersion', $pb.PbFieldType.OU3)
    ..aOM<RpcRequest>(10, _omitFieldNames ? '' : 'rpcRequest',
        subBuilder: RpcRequest.create)
    ..aOM<RpcResponse>(11, _omitFieldNames ? '' : 'rpcResponse',
        subBuilder: RpcResponse.create)
    ..aOM<StartSession>(20, _omitFieldNames ? '' : 'startSession',
        subBuilder: StartSession.create)
    ..aOM<SessionStarted>(21, _omitFieldNames ? '' : 'sessionStarted',
        subBuilder: SessionStarted.create)
    ..aOM<Ready>(25, _omitFieldNames ? '' : 'ready', subBuilder: Ready.create)
    ..aOM<Logout>(27, _omitFieldNames ? '' : 'logout',
        subBuilder: Logout.create)
    ..aOM<Events>(28, _omitFieldNames ? '' : 'event', subBuilder: Events.create)
    ..aOM<ProtocolError>(29, _omitFieldNames ? '' : 'error',
        subBuilder: ProtocolError.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Envelope clone() => Envelope()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Envelope copyWith(void Function(Envelope) updates) =>
      super.copyWith((message) => updates(message as Envelope)) as Envelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Envelope create() => Envelope._();
  @$core.override
  Envelope createEmptyInstance() => create();
  static $pb.PbList<Envelope> createRepeated() => $pb.PbList<Envelope>();
  @$core.pragma('dart2js:noInline')
  static Envelope getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Envelope>(create);
  static Envelope? _defaultInstance;

  Envelope_Payload whichPayload() => _Envelope_PayloadByTag[$_whichOneof(0)]!;
  void clearPayload() => $_clearField($_whichOneof(0));

  /// Envelope wire version. This is independent of LoginRequest.protocol_version.
  @$pb.TagNumber(1)
  $core.int get wireVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set wireVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWireVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearWireVersion() => $_clearField(1);

  @$pb.TagNumber(10)
  RpcRequest get rpcRequest => $_getN(1);
  @$pb.TagNumber(10)
  set rpcRequest(RpcRequest value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasRpcRequest() => $_has(1);
  @$pb.TagNumber(10)
  void clearRpcRequest() => $_clearField(10);
  @$pb.TagNumber(10)
  RpcRequest ensureRpcRequest() => $_ensure(1);

  @$pb.TagNumber(11)
  RpcResponse get rpcResponse => $_getN(2);
  @$pb.TagNumber(11)
  set rpcResponse(RpcResponse value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRpcResponse() => $_has(2);
  @$pb.TagNumber(11)
  void clearRpcResponse() => $_clearField(11);
  @$pb.TagNumber(11)
  RpcResponse ensureRpcResponse() => $_ensure(2);

  @$pb.TagNumber(20)
  StartSession get startSession => $_getN(3);
  @$pb.TagNumber(20)
  set startSession(StartSession value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasStartSession() => $_has(3);
  @$pb.TagNumber(20)
  void clearStartSession() => $_clearField(20);
  @$pb.TagNumber(20)
  StartSession ensureStartSession() => $_ensure(3);

  @$pb.TagNumber(21)
  SessionStarted get sessionStarted => $_getN(4);
  @$pb.TagNumber(21)
  set sessionStarted(SessionStarted value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasSessionStarted() => $_has(4);
  @$pb.TagNumber(21)
  void clearSessionStarted() => $_clearField(21);
  @$pb.TagNumber(21)
  SessionStarted ensureSessionStarted() => $_ensure(4);

  @$pb.TagNumber(25)
  Ready get ready => $_getN(5);
  @$pb.TagNumber(25)
  set ready(Ready value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasReady() => $_has(5);
  @$pb.TagNumber(25)
  void clearReady() => $_clearField(25);
  @$pb.TagNumber(25)
  Ready ensureReady() => $_ensure(5);

  @$pb.TagNumber(27)
  Logout get logout => $_getN(6);
  @$pb.TagNumber(27)
  set logout(Logout value) => $_setField(27, value);
  @$pb.TagNumber(27)
  $core.bool hasLogout() => $_has(6);
  @$pb.TagNumber(27)
  void clearLogout() => $_clearField(27);
  @$pb.TagNumber(27)
  Logout ensureLogout() => $_ensure(6);

  @$pb.TagNumber(28)
  Events get event => $_getN(7);
  @$pb.TagNumber(28)
  set event(Events value) => $_setField(28, value);
  @$pb.TagNumber(28)
  $core.bool hasEvent() => $_has(7);
  @$pb.TagNumber(28)
  void clearEvent() => $_clearField(28);
  @$pb.TagNumber(28)
  Events ensureEvent() => $_ensure(7);

  @$pb.TagNumber(29)
  ProtocolError get error => $_getN(8);
  @$pb.TagNumber(29)
  set error(ProtocolError value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasError() => $_has(8);
  @$pb.TagNumber(29)
  void clearError() => $_clearField(29);
  @$pb.TagNumber(29)
  ProtocolError ensureError() => $_ensure(8);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

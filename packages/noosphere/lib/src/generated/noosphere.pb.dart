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

class ParticipantStatusEvent extends $pb.GeneratedMessage {
  factory ParticipantStatusEvent({
    $core.List<$core.int>? participantId,
    $core.bool? loggedIn,
  }) {
    final result = create();
    if (participantId != null) result.participantId = participantId;
    if (loggedIn != null) result.loggedIn = loggedIn;
    return result;
  }

  ParticipantStatusEvent._();

  factory ParticipantStatusEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ParticipantStatusEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ParticipantStatusEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'participantId', $pb.PbFieldType.OY)
    ..aOB(2, _omitFieldNames ? '' : 'loggedIn')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParticipantStatusEvent clone() =>
      ParticipantStatusEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParticipantStatusEvent copyWith(
          void Function(ParticipantStatusEvent) updates) =>
      super.copyWith((message) => updates(message as ParticipantStatusEvent))
          as ParticipantStatusEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ParticipantStatusEvent create() => ParticipantStatusEvent._();
  @$core.override
  ParticipantStatusEvent createEmptyInstance() => create();
  static $pb.PbList<ParticipantStatusEvent> createRepeated() =>
      $pb.PbList<ParticipantStatusEvent>();
  @$core.pragma('dart2js:noInline')
  static ParticipantStatusEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ParticipantStatusEvent>(create);
  static ParticipantStatusEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get participantId => $_getN(0);
  @$pb.TagNumber(1)
  set participantId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParticipantId() => $_has(0);
  @$pb.TagNumber(1)
  void clearParticipantId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get loggedIn => $_getBF(1);
  @$pb.TagNumber(2)
  set loggedIn($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLoggedIn() => $_has(1);
  @$pb.TagNumber(2)
  void clearLoggedIn() => $_clearField(2);
}

class DkgEventCommitment extends $pb.GeneratedMessage {
  factory DkgEventCommitment({
    $core.List<$core.int>? participantId,
    $core.List<$core.int>? commitment,
  }) {
    final result = create();
    if (participantId != null) result.participantId = participantId;
    if (commitment != null) result.commitment = commitment;
    return result;
  }

  DkgEventCommitment._();

  factory DkgEventCommitment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgEventCommitment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgEventCommitment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'participantId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'commitment', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgEventCommitment clone() => DkgEventCommitment()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgEventCommitment copyWith(void Function(DkgEventCommitment) updates) =>
      super.copyWith((message) => updates(message as DkgEventCommitment))
          as DkgEventCommitment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgEventCommitment create() => DkgEventCommitment._();
  @$core.override
  DkgEventCommitment createEmptyInstance() => create();
  static $pb.PbList<DkgEventCommitment> createRepeated() =>
      $pb.PbList<DkgEventCommitment>();
  @$core.pragma('dart2js:noInline')
  static DkgEventCommitment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgEventCommitment>(create);
  static DkgEventCommitment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get participantId => $_getN(0);
  @$pb.TagNumber(1)
  set participantId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParticipantId() => $_has(0);
  @$pb.TagNumber(1)
  void clearParticipantId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get commitment => $_getN(1);
  @$pb.TagNumber(2)
  set commitment($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommitment() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommitment() => $_clearField(2);
}

class NewDkgEvent extends $pb.GeneratedMessage {
  factory NewDkgEvent({
    $core.List<$core.int>? signedDetails,
    $core.List<$core.int>? creatorId,
    $core.Iterable<DkgEventCommitment>? commitments,
  }) {
    final result = create();
    if (signedDetails != null) result.signedDetails = signedDetails;
    if (creatorId != null) result.creatorId = creatorId;
    if (commitments != null) result.commitments.addAll(commitments);
    return result;
  }

  NewDkgEvent._();

  factory NewDkgEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NewDkgEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NewDkgEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'signedDetails', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'creatorId', $pb.PbFieldType.OY)
    ..pc<DkgEventCommitment>(
        3, _omitFieldNames ? '' : 'commitments', $pb.PbFieldType.PM,
        subBuilder: DkgEventCommitment.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NewDkgEvent clone() => NewDkgEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NewDkgEvent copyWith(void Function(NewDkgEvent) updates) =>
      super.copyWith((message) => updates(message as NewDkgEvent))
          as NewDkgEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NewDkgEvent create() => NewDkgEvent._();
  @$core.override
  NewDkgEvent createEmptyInstance() => create();
  static $pb.PbList<NewDkgEvent> createRepeated() => $pb.PbList<NewDkgEvent>();
  @$core.pragma('dart2js:noInline')
  static NewDkgEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NewDkgEvent>(create);
  static NewDkgEvent? _defaultInstance;

  /// Canonically serialized Signed<NewDkgDetails>.
  @$pb.TagNumber(1)
  $core.List<$core.int> get signedDetails => $_getN(0);
  @$pb.TagNumber(1)
  set signedDetails($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignedDetails() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignedDetails() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get creatorId => $_getN(1);
  @$pb.TagNumber(2)
  set creatorId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCreatorId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCreatorId() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<DkgEventCommitment> get commitments => $_getList(2);
}

class DkgCommitmentEvent extends $pb.GeneratedMessage {
  factory DkgCommitmentEvent({
    $core.String? name,
    $core.List<$core.int>? participantId,
    $core.List<$core.int>? commitment,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (participantId != null) result.participantId = participantId;
    if (commitment != null) result.commitment = commitment;
    return result;
  }

  DkgCommitmentEvent._();

  factory DkgCommitmentEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgCommitmentEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgCommitmentEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'participantId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'commitment', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgCommitmentEvent clone() => DkgCommitmentEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgCommitmentEvent copyWith(void Function(DkgCommitmentEvent) updates) =>
      super.copyWith((message) => updates(message as DkgCommitmentEvent))
          as DkgCommitmentEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgCommitmentEvent create() => DkgCommitmentEvent._();
  @$core.override
  DkgCommitmentEvent createEmptyInstance() => create();
  static $pb.PbList<DkgCommitmentEvent> createRepeated() =>
      $pb.PbList<DkgCommitmentEvent>();
  @$core.pragma('dart2js:noInline')
  static DkgCommitmentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgCommitmentEvent>(create);
  static DkgCommitmentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get participantId => $_getN(1);
  @$pb.TagNumber(2)
  set participantId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParticipantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearParticipantId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get commitment => $_getN(2);
  @$pb.TagNumber(3)
  set commitment($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommitment() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommitment() => $_clearField(3);
}

class DkgRejectEvent extends $pb.GeneratedMessage {
  factory DkgRejectEvent({
    $core.String? name,
    $core.List<$core.int>? participantId,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (participantId != null) result.participantId = participantId;
    return result;
  }

  DkgRejectEvent._();

  factory DkgRejectEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgRejectEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgRejectEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'participantId', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgRejectEvent clone() => DkgRejectEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgRejectEvent copyWith(void Function(DkgRejectEvent) updates) =>
      super.copyWith((message) => updates(message as DkgRejectEvent))
          as DkgRejectEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgRejectEvent create() => DkgRejectEvent._();
  @$core.override
  DkgRejectEvent createEmptyInstance() => create();
  static $pb.PbList<DkgRejectEvent> createRepeated() =>
      $pb.PbList<DkgRejectEvent>();
  @$core.pragma('dart2js:noInline')
  static DkgRejectEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgRejectEvent>(create);
  static DkgRejectEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get participantId => $_getN(1);
  @$pb.TagNumber(2)
  set participantId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParticipantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearParticipantId() => $_clearField(2);
}

class DkgRound2ShareEvent extends $pb.GeneratedMessage {
  factory DkgRound2ShareEvent({
    $core.String? name,
    $core.List<$core.int>? commitmentSetSignature,
    $core.List<$core.int>? senderId,
    $core.List<$core.int>? encryptedSecret,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (commitmentSetSignature != null)
      result.commitmentSetSignature = commitmentSetSignature;
    if (senderId != null) result.senderId = senderId;
    if (encryptedSecret != null) result.encryptedSecret = encryptedSecret;
    return result;
  }

  DkgRound2ShareEvent._();

  factory DkgRound2ShareEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgRound2ShareEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgRound2ShareEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'commitmentSetSignature', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'senderId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'encryptedSecret', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgRound2ShareEvent clone() => DkgRound2ShareEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgRound2ShareEvent copyWith(void Function(DkgRound2ShareEvent) updates) =>
      super.copyWith((message) => updates(message as DkgRound2ShareEvent))
          as DkgRound2ShareEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgRound2ShareEvent create() => DkgRound2ShareEvent._();
  @$core.override
  DkgRound2ShareEvent createEmptyInstance() => create();
  static $pb.PbList<DkgRound2ShareEvent> createRepeated() =>
      $pb.PbList<DkgRound2ShareEvent>();
  @$core.pragma('dart2js:noInline')
  static DkgRound2ShareEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgRound2ShareEvent>(create);
  static DkgRound2ShareEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get commitmentSetSignature => $_getN(1);
  @$pb.TagNumber(2)
  set commitmentSetSignature($core.List<$core.int> value) =>
      $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommitmentSetSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommitmentSetSignature() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get senderId => $_getN(2);
  @$pb.TagNumber(3)
  set senderId($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get encryptedSecret => $_getN(3);
  @$pb.TagNumber(4)
  set encryptedSecret($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEncryptedSecret() => $_has(3);
  @$pb.TagNumber(4)
  void clearEncryptedSecret() => $_clearField(4);
}

class DkgAckEvent extends $pb.GeneratedMessage {
  factory DkgAckEvent({
    $core.Iterable<$core.List<$core.int>>? acks,
  }) {
    final result = create();
    if (acks != null) result.acks.addAll(acks);
    return result;
  }

  DkgAckEvent._();

  factory DkgAckEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgAckEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgAckEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..p<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'acks', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgAckEvent clone() => DkgAckEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgAckEvent copyWith(void Function(DkgAckEvent) updates) =>
      super.copyWith((message) => updates(message as DkgAckEvent))
          as DkgAckEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgAckEvent create() => DkgAckEvent._();
  @$core.override
  DkgAckEvent createEmptyInstance() => create();
  static $pb.PbList<DkgAckEvent> createRepeated() => $pb.PbList<DkgAckEvent>();
  @$core.pragma('dart2js:noInline')
  static DkgAckEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgAckEvent>(create);
  static DkgAckEvent? _defaultInstance;

  /// Canonically serialized SignedDkgAck values.
  @$pb.TagNumber(1)
  $pb.PbList<$core.List<$core.int>> get acks => $_getList(0);
}

class DkgAckRequestEvent extends $pb.GeneratedMessage {
  factory DkgAckRequestEvent({
    $core.Iterable<$core.List<$core.int>>? requests,
  }) {
    final result = create();
    if (requests != null) result.requests.addAll(requests);
    return result;
  }

  DkgAckRequestEvent._();

  factory DkgAckRequestEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DkgAckRequestEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DkgAckRequestEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..p<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'requests', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgAckRequestEvent clone() => DkgAckRequestEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DkgAckRequestEvent copyWith(void Function(DkgAckRequestEvent) updates) =>
      super.copyWith((message) => updates(message as DkgAckRequestEvent))
          as DkgAckRequestEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DkgAckRequestEvent create() => DkgAckRequestEvent._();
  @$core.override
  DkgAckRequestEvent createEmptyInstance() => create();
  static $pb.PbList<DkgAckRequestEvent> createRepeated() =>
      $pb.PbList<DkgAckRequestEvent>();
  @$core.pragma('dart2js:noInline')
  static DkgAckRequestEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DkgAckRequestEvent>(create);
  static DkgAckRequestEvent? _defaultInstance;

  /// Canonically serialized DkgAckRequest values.
  @$pb.TagNumber(1)
  $pb.PbList<$core.List<$core.int>> get requests => $_getList(0);
}

class SignaturesProgress extends $pb.GeneratedMessage {
  factory SignaturesProgress({
    $core.int? threshold,
    $core.Iterable<$core.List<$core.int>>? contributingParticipantIds,
    SignaturesProgressStage? stage,
  }) {
    final result = create();
    if (threshold != null) result.threshold = threshold;
    if (contributingParticipantIds != null)
      result.contributingParticipantIds.addAll(contributingParticipantIds);
    if (stage != null) result.stage = stage;
    return result;
  }

  SignaturesProgress._();

  factory SignaturesProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesProgress',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'threshold', $pb.PbFieldType.OU3)
    ..p<$core.List<$core.int>>(2,
        _omitFieldNames ? '' : 'contributingParticipantIds', $pb.PbFieldType.PY)
    ..e<SignaturesProgressStage>(
        3, _omitFieldNames ? '' : 'stage', $pb.PbFieldType.OE,
        defaultOrMaker: SignaturesProgressStage.SIGNATURES_PROGRESS_COLLECTING,
        valueOf: SignaturesProgressStage.valueOf,
        enumValues: SignaturesProgressStage.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesProgress clone() => SignaturesProgress()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesProgress copyWith(void Function(SignaturesProgress) updates) =>
      super.copyWith((message) => updates(message as SignaturesProgress))
          as SignaturesProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesProgress create() => SignaturesProgress._();
  @$core.override
  SignaturesProgress createEmptyInstance() => create();
  static $pb.PbList<SignaturesProgress> createRepeated() =>
      $pb.PbList<SignaturesProgress>();
  @$core.pragma('dart2js:noInline')
  static SignaturesProgress getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesProgress>(create);
  static SignaturesProgress? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get threshold => $_getIZ(0);
  @$pb.TagNumber(1)
  set threshold($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasThreshold() => $_has(0);
  @$pb.TagNumber(1)
  void clearThreshold() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get contributingParticipantIds =>
      $_getList(1);

  @$pb.TagNumber(3)
  SignaturesProgressStage get stage => $_getN(2);
  @$pb.TagNumber(3)
  set stage(SignaturesProgressStage value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStage() => $_has(2);
  @$pb.TagNumber(3)
  void clearStage() => $_clearField(3);
}

class SignaturesRequestEvent extends $pb.GeneratedMessage {
  factory SignaturesRequestEvent({
    $core.List<$core.int>? signedDetails,
    $core.List<$core.int>? creatorId,
    SignaturesProgress? progress,
  }) {
    final result = create();
    if (signedDetails != null) result.signedDetails = signedDetails;
    if (creatorId != null) result.creatorId = creatorId;
    if (progress != null) result.progress = progress;
    return result;
  }

  SignaturesRequestEvent._();

  factory SignaturesRequestEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesRequestEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesRequestEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'signedDetails', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'creatorId', $pb.PbFieldType.OY)
    ..aOM<SignaturesProgress>(3, _omitFieldNames ? '' : 'progress',
        subBuilder: SignaturesProgress.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesRequestEvent clone() =>
      SignaturesRequestEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesRequestEvent copyWith(
          void Function(SignaturesRequestEvent) updates) =>
      super.copyWith((message) => updates(message as SignaturesRequestEvent))
          as SignaturesRequestEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesRequestEvent create() => SignaturesRequestEvent._();
  @$core.override
  SignaturesRequestEvent createEmptyInstance() => create();
  static $pb.PbList<SignaturesRequestEvent> createRepeated() =>
      $pb.PbList<SignaturesRequestEvent>();
  @$core.pragma('dart2js:noInline')
  static SignaturesRequestEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesRequestEvent>(create);
  static SignaturesRequestEvent? _defaultInstance;

  /// Canonically serialized Signed<SignaturesRequestDetails>.
  @$pb.TagNumber(1)
  $core.List<$core.int> get signedDetails => $_getN(0);
  @$pb.TagNumber(1)
  set signedDetails($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignedDetails() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignedDetails() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get creatorId => $_getN(1);
  @$pb.TagNumber(2)
  set creatorId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCreatorId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCreatorId() => $_clearField(2);

  @$pb.TagNumber(3)
  SignaturesProgress get progress => $_getN(2);
  @$pb.TagNumber(3)
  set progress(SignaturesProgress value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasProgress() => $_has(2);
  @$pb.TagNumber(3)
  void clearProgress() => $_clearField(3);
  @$pb.TagNumber(3)
  SignaturesProgress ensureProgress() => $_ensure(2);
}

class SignatureRoundStart extends $pb.GeneratedMessage {
  factory SignatureRoundStart({
    $core.int? signatureIndex,
    $core.List<$core.int>? commitmentSet,
  }) {
    final result = create();
    if (signatureIndex != null) result.signatureIndex = signatureIndex;
    if (commitmentSet != null) result.commitmentSet = commitmentSet;
    return result;
  }

  SignatureRoundStart._();

  factory SignatureRoundStart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignatureRoundStart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignatureRoundStart',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.int>(
        1, _omitFieldNames ? '' : 'signatureIndex', $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'commitmentSet', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignatureRoundStart clone() => SignatureRoundStart()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignatureRoundStart copyWith(void Function(SignatureRoundStart) updates) =>
      super.copyWith((message) => updates(message as SignatureRoundStart))
          as SignatureRoundStart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignatureRoundStart create() => SignatureRoundStart._();
  @$core.override
  SignatureRoundStart createEmptyInstance() => create();
  static $pb.PbList<SignatureRoundStart> createRepeated() =>
      $pb.PbList<SignatureRoundStart>();
  @$core.pragma('dart2js:noInline')
  static SignatureRoundStart getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignatureRoundStart>(create);
  static SignatureRoundStart? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get signatureIndex => $_getIZ(0);
  @$pb.TagNumber(1)
  set signatureIndex($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSignatureIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearSignatureIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get commitmentSet => $_getN(1);
  @$pb.TagNumber(2)
  set commitmentSet($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommitmentSet() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommitmentSet() => $_clearField(2);
}

class SignatureNewRoundsEvent extends $pb.GeneratedMessage {
  factory SignatureNewRoundsEvent({
    $core.List<$core.int>? requestId,
    $core.Iterable<SignatureRoundStart>? rounds,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (rounds != null) result.rounds.addAll(rounds);
    return result;
  }

  SignatureNewRoundsEvent._();

  factory SignatureNewRoundsEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignatureNewRoundsEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignatureNewRoundsEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.OY)
    ..pc<SignatureRoundStart>(
        2, _omitFieldNames ? '' : 'rounds', $pb.PbFieldType.PM,
        subBuilder: SignatureRoundStart.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignatureNewRoundsEvent clone() =>
      SignatureNewRoundsEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignatureNewRoundsEvent copyWith(
          void Function(SignatureNewRoundsEvent) updates) =>
      super.copyWith((message) => updates(message as SignatureNewRoundsEvent))
          as SignatureNewRoundsEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignatureNewRoundsEvent create() => SignatureNewRoundsEvent._();
  @$core.override
  SignatureNewRoundsEvent createEmptyInstance() => create();
  static $pb.PbList<SignatureNewRoundsEvent> createRepeated() =>
      $pb.PbList<SignatureNewRoundsEvent>();
  @$core.pragma('dart2js:noInline')
  static SignatureNewRoundsEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignatureNewRoundsEvent>(create);
  static SignatureNewRoundsEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get requestId => $_getN(0);
  @$pb.TagNumber(1)
  set requestId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<SignatureRoundStart> get rounds => $_getList(1);
}

class SignaturesCompleteEvent extends $pb.GeneratedMessage {
  factory SignaturesCompleteEvent({
    $core.List<$core.int>? requestId,
    $core.Iterable<$core.List<$core.int>>? signatures,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (signatures != null) result.signatures.addAll(signatures);
    return result;
  }

  SignaturesCompleteEvent._();

  factory SignaturesCompleteEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesCompleteEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesCompleteEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.OY)
    ..p<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signatures', $pb.PbFieldType.PY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesCompleteEvent clone() =>
      SignaturesCompleteEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesCompleteEvent copyWith(
          void Function(SignaturesCompleteEvent) updates) =>
      super.copyWith((message) => updates(message as SignaturesCompleteEvent))
          as SignaturesCompleteEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesCompleteEvent create() => SignaturesCompleteEvent._();
  @$core.override
  SignaturesCompleteEvent createEmptyInstance() => create();
  static $pb.PbList<SignaturesCompleteEvent> createRepeated() =>
      $pb.PbList<SignaturesCompleteEvent>();
  @$core.pragma('dart2js:noInline')
  static SignaturesCompleteEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesCompleteEvent>(create);
  static SignaturesCompleteEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get requestId => $_getN(0);
  @$pb.TagNumber(1)
  set requestId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.List<$core.int>> get signatures => $_getList(1);
}

class SignaturesFailureEvent extends $pb.GeneratedMessage {
  factory SignaturesFailureEvent({
    $core.List<$core.int>? requestId,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    return result;
  }

  SignaturesFailureEvent._();

  factory SignaturesFailureEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesFailureEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesFailureEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesFailureEvent clone() =>
      SignaturesFailureEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesFailureEvent copyWith(
          void Function(SignaturesFailureEvent) updates) =>
      super.copyWith((message) => updates(message as SignaturesFailureEvent))
          as SignaturesFailureEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesFailureEvent create() => SignaturesFailureEvent._();
  @$core.override
  SignaturesFailureEvent createEmptyInstance() => create();
  static $pb.PbList<SignaturesFailureEvent> createRepeated() =>
      $pb.PbList<SignaturesFailureEvent>();
  @$core.pragma('dart2js:noInline')
  static SignaturesFailureEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesFailureEvent>(create);
  static SignaturesFailureEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get requestId => $_getN(0);
  @$pb.TagNumber(1)
  set requestId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);
}

class KeepaliveEvent extends $pb.GeneratedMessage {
  factory KeepaliveEvent() => create();

  KeepaliveEvent._();

  factory KeepaliveEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeepaliveEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeepaliveEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeepaliveEvent clone() => KeepaliveEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeepaliveEvent copyWith(void Function(KeepaliveEvent) updates) =>
      super.copyWith((message) => updates(message as KeepaliveEvent))
          as KeepaliveEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeepaliveEvent create() => KeepaliveEvent._();
  @$core.override
  KeepaliveEvent createEmptyInstance() => create();
  static $pb.PbList<KeepaliveEvent> createRepeated() =>
      $pb.PbList<KeepaliveEvent>();
  @$core.pragma('dart2js:noInline')
  static KeepaliveEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeepaliveEvent>(create);
  static KeepaliveEvent? _defaultInstance;
}

class SecretShareEvent extends $pb.GeneratedMessage {
  factory SecretShareEvent({
    $core.List<$core.int>? senderId,
    $core.List<$core.int>? groupKey,
    $core.List<$core.int>? encryptedKeyShare,
  }) {
    final result = create();
    if (senderId != null) result.senderId = senderId;
    if (groupKey != null) result.groupKey = groupKey;
    if (encryptedKeyShare != null) result.encryptedKeyShare = encryptedKeyShare;
    return result;
  }

  SecretShareEvent._();

  factory SecretShareEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SecretShareEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SecretShareEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'senderId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'groupKey', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'encryptedKeyShare', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecretShareEvent clone() => SecretShareEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecretShareEvent copyWith(void Function(SecretShareEvent) updates) =>
      super.copyWith((message) => updates(message as SecretShareEvent))
          as SecretShareEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SecretShareEvent create() => SecretShareEvent._();
  @$core.override
  SecretShareEvent createEmptyInstance() => create();
  static $pb.PbList<SecretShareEvent> createRepeated() =>
      $pb.PbList<SecretShareEvent>();
  @$core.pragma('dart2js:noInline')
  static SecretShareEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SecretShareEvent>(create);
  static SecretShareEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get senderId => $_getN(0);
  @$pb.TagNumber(1)
  set senderId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSenderId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSenderId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get groupKey => $_getN(1);
  @$pb.TagNumber(2)
  set groupKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGroupKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroupKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get encryptedKeyShare => $_getN(2);
  @$pb.TagNumber(3)
  set encryptedKeyShare($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEncryptedKeyShare() => $_has(2);
  @$pb.TagNumber(3)
  void clearEncryptedKeyShare() => $_clearField(3);
}

class ConstructedKeyEvent extends $pb.GeneratedMessage {
  factory ConstructedKeyEvent({
    $core.List<$core.int>? participantId,
    $core.List<$core.int>? signedConstructedKey,
  }) {
    final result = create();
    if (participantId != null) result.participantId = participantId;
    if (signedConstructedKey != null)
      result.signedConstructedKey = signedConstructedKey;
    return result;
  }

  ConstructedKeyEvent._();

  factory ConstructedKeyEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConstructedKeyEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConstructedKeyEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'participantId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signedConstructedKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConstructedKeyEvent clone() => ConstructedKeyEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConstructedKeyEvent copyWith(void Function(ConstructedKeyEvent) updates) =>
      super.copyWith((message) => updates(message as ConstructedKeyEvent))
          as ConstructedKeyEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConstructedKeyEvent create() => ConstructedKeyEvent._();
  @$core.override
  ConstructedKeyEvent createEmptyInstance() => create();
  static $pb.PbList<ConstructedKeyEvent> createRepeated() =>
      $pb.PbList<ConstructedKeyEvent>();
  @$core.pragma('dart2js:noInline')
  static ConstructedKeyEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConstructedKeyEvent>(create);
  static ConstructedKeyEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get participantId => $_getN(0);
  @$pb.TagNumber(1)
  set participantId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParticipantId() => $_has(0);
  @$pb.TagNumber(1)
  void clearParticipantId() => $_clearField(1);

  /// Canonically serialized Signed<KeyWasConstructed>.
  @$pb.TagNumber(2)
  $core.List<$core.int> get signedConstructedKey => $_getN(1);
  @$pb.TagNumber(2)
  set signedConstructedKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignedConstructedKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignedConstructedKey() => $_clearField(2);
}

class SignaturesProgressEvent extends $pb.GeneratedMessage {
  factory SignaturesProgressEvent({
    $core.List<$core.int>? requestId,
    SignaturesProgress? progress,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (progress != null) result.progress = progress;
    return result;
  }

  SignaturesProgressEvent._();

  factory SignaturesProgressEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SignaturesProgressEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SignaturesProgressEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'requestId', $pb.PbFieldType.OY)
    ..aOM<SignaturesProgress>(2, _omitFieldNames ? '' : 'progress',
        subBuilder: SignaturesProgress.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesProgressEvent clone() =>
      SignaturesProgressEvent()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SignaturesProgressEvent copyWith(
          void Function(SignaturesProgressEvent) updates) =>
      super.copyWith((message) => updates(message as SignaturesProgressEvent))
          as SignaturesProgressEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SignaturesProgressEvent create() => SignaturesProgressEvent._();
  @$core.override
  SignaturesProgressEvent createEmptyInstance() => create();
  static $pb.PbList<SignaturesProgressEvent> createRepeated() =>
      $pb.PbList<SignaturesProgressEvent>();
  @$core.pragma('dart2js:noInline')
  static SignaturesProgressEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SignaturesProgressEvent>(create);
  static SignaturesProgressEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get requestId => $_getN(0);
  @$pb.TagNumber(1)
  set requestId($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  SignaturesProgress get progress => $_getN(1);
  @$pb.TagNumber(2)
  set progress(SignaturesProgress value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgress() => $_clearField(2);
  @$pb.TagNumber(2)
  SignaturesProgress ensureProgress() => $_ensure(1);
}

enum EventMessage_Event {
  participantStatus,
  newDkg,
  dkgCommitment,
  dkgReject,
  dkgRound2Share,
  dkgAck,
  dkgAckRequest,
  signaturesRequest,
  signatureNewRounds,
  signaturesComplete,
  signaturesFailure,
  keepalive,
  secretShare,
  constructedKey,
  signaturesProgress,
  notSet
}

class EventMessage extends $pb.GeneratedMessage {
  factory EventMessage({
    ParticipantStatusEvent? participantStatus,
    NewDkgEvent? newDkg,
    DkgCommitmentEvent? dkgCommitment,
    DkgRejectEvent? dkgReject,
    DkgRound2ShareEvent? dkgRound2Share,
    DkgAckEvent? dkgAck,
    DkgAckRequestEvent? dkgAckRequest,
    SignaturesRequestEvent? signaturesRequest,
    SignatureNewRoundsEvent? signatureNewRounds,
    SignaturesCompleteEvent? signaturesComplete,
    SignaturesFailureEvent? signaturesFailure,
    KeepaliveEvent? keepalive,
    SecretShareEvent? secretShare,
    ConstructedKeyEvent? constructedKey,
    SignaturesProgressEvent? signaturesProgress,
  }) {
    final result = create();
    if (participantStatus != null) result.participantStatus = participantStatus;
    if (newDkg != null) result.newDkg = newDkg;
    if (dkgCommitment != null) result.dkgCommitment = dkgCommitment;
    if (dkgReject != null) result.dkgReject = dkgReject;
    if (dkgRound2Share != null) result.dkgRound2Share = dkgRound2Share;
    if (dkgAck != null) result.dkgAck = dkgAck;
    if (dkgAckRequest != null) result.dkgAckRequest = dkgAckRequest;
    if (signaturesRequest != null) result.signaturesRequest = signaturesRequest;
    if (signatureNewRounds != null)
      result.signatureNewRounds = signatureNewRounds;
    if (signaturesComplete != null)
      result.signaturesComplete = signaturesComplete;
    if (signaturesFailure != null) result.signaturesFailure = signaturesFailure;
    if (keepalive != null) result.keepalive = keepalive;
    if (secretShare != null) result.secretShare = secretShare;
    if (constructedKey != null) result.constructedKey = constructedKey;
    if (signaturesProgress != null)
      result.signaturesProgress = signaturesProgress;
    return result;
  }

  EventMessage._();

  factory EventMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EventMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, EventMessage_Event>
      _EventMessage_EventByTag = {
    1: EventMessage_Event.participantStatus,
    2: EventMessage_Event.newDkg,
    3: EventMessage_Event.dkgCommitment,
    4: EventMessage_Event.dkgReject,
    5: EventMessage_Event.dkgRound2Share,
    6: EventMessage_Event.dkgAck,
    7: EventMessage_Event.dkgAckRequest,
    8: EventMessage_Event.signaturesRequest,
    9: EventMessage_Event.signatureNewRounds,
    10: EventMessage_Event.signaturesComplete,
    11: EventMessage_Event.signaturesFailure,
    12: EventMessage_Event.keepalive,
    13: EventMessage_Event.secretShare,
    14: EventMessage_Event.constructedKey,
    15: EventMessage_Event.signaturesProgress,
    0: EventMessage_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
    ..aOM<ParticipantStatusEvent>(1, _omitFieldNames ? '' : 'participantStatus',
        subBuilder: ParticipantStatusEvent.create)
    ..aOM<NewDkgEvent>(2, _omitFieldNames ? '' : 'newDkg',
        subBuilder: NewDkgEvent.create)
    ..aOM<DkgCommitmentEvent>(3, _omitFieldNames ? '' : 'dkgCommitment',
        subBuilder: DkgCommitmentEvent.create)
    ..aOM<DkgRejectEvent>(4, _omitFieldNames ? '' : 'dkgReject',
        subBuilder: DkgRejectEvent.create)
    ..aOM<DkgRound2ShareEvent>(5, _omitFieldNames ? '' : 'dkgRound2Share',
        subBuilder: DkgRound2ShareEvent.create)
    ..aOM<DkgAckEvent>(6, _omitFieldNames ? '' : 'dkgAck',
        subBuilder: DkgAckEvent.create)
    ..aOM<DkgAckRequestEvent>(7, _omitFieldNames ? '' : 'dkgAckRequest',
        subBuilder: DkgAckRequestEvent.create)
    ..aOM<SignaturesRequestEvent>(8, _omitFieldNames ? '' : 'signaturesRequest',
        subBuilder: SignaturesRequestEvent.create)
    ..aOM<SignatureNewRoundsEvent>(
        9, _omitFieldNames ? '' : 'signatureNewRounds',
        subBuilder: SignatureNewRoundsEvent.create)
    ..aOM<SignaturesCompleteEvent>(
        10, _omitFieldNames ? '' : 'signaturesComplete',
        subBuilder: SignaturesCompleteEvent.create)
    ..aOM<SignaturesFailureEvent>(
        11, _omitFieldNames ? '' : 'signaturesFailure',
        subBuilder: SignaturesFailureEvent.create)
    ..aOM<KeepaliveEvent>(12, _omitFieldNames ? '' : 'keepalive',
        subBuilder: KeepaliveEvent.create)
    ..aOM<SecretShareEvent>(13, _omitFieldNames ? '' : 'secretShare',
        subBuilder: SecretShareEvent.create)
    ..aOM<ConstructedKeyEvent>(14, _omitFieldNames ? '' : 'constructedKey',
        subBuilder: ConstructedKeyEvent.create)
    ..aOM<SignaturesProgressEvent>(
        15, _omitFieldNames ? '' : 'signaturesProgress',
        subBuilder: SignaturesProgressEvent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventMessage clone() => EventMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventMessage copyWith(void Function(EventMessage) updates) =>
      super.copyWith((message) => updates(message as EventMessage))
          as EventMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EventMessage create() => EventMessage._();
  @$core.override
  EventMessage createEmptyInstance() => create();
  static $pb.PbList<EventMessage> createRepeated() =>
      $pb.PbList<EventMessage>();
  @$core.pragma('dart2js:noInline')
  static EventMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EventMessage>(create);
  static EventMessage? _defaultInstance;

  EventMessage_Event whichEvent() => _EventMessage_EventByTag[$_whichOneof(0)]!;
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ParticipantStatusEvent get participantStatus => $_getN(0);
  @$pb.TagNumber(1)
  set participantStatus(ParticipantStatusEvent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasParticipantStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearParticipantStatus() => $_clearField(1);
  @$pb.TagNumber(1)
  ParticipantStatusEvent ensureParticipantStatus() => $_ensure(0);

  @$pb.TagNumber(2)
  NewDkgEvent get newDkg => $_getN(1);
  @$pb.TagNumber(2)
  set newDkg(NewDkgEvent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNewDkg() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewDkg() => $_clearField(2);
  @$pb.TagNumber(2)
  NewDkgEvent ensureNewDkg() => $_ensure(1);

  @$pb.TagNumber(3)
  DkgCommitmentEvent get dkgCommitment => $_getN(2);
  @$pb.TagNumber(3)
  set dkgCommitment(DkgCommitmentEvent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDkgCommitment() => $_has(2);
  @$pb.TagNumber(3)
  void clearDkgCommitment() => $_clearField(3);
  @$pb.TagNumber(3)
  DkgCommitmentEvent ensureDkgCommitment() => $_ensure(2);

  @$pb.TagNumber(4)
  DkgRejectEvent get dkgReject => $_getN(3);
  @$pb.TagNumber(4)
  set dkgReject(DkgRejectEvent value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDkgReject() => $_has(3);
  @$pb.TagNumber(4)
  void clearDkgReject() => $_clearField(4);
  @$pb.TagNumber(4)
  DkgRejectEvent ensureDkgReject() => $_ensure(3);

  @$pb.TagNumber(5)
  DkgRound2ShareEvent get dkgRound2Share => $_getN(4);
  @$pb.TagNumber(5)
  set dkgRound2Share(DkgRound2ShareEvent value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDkgRound2Share() => $_has(4);
  @$pb.TagNumber(5)
  void clearDkgRound2Share() => $_clearField(5);
  @$pb.TagNumber(5)
  DkgRound2ShareEvent ensureDkgRound2Share() => $_ensure(4);

  @$pb.TagNumber(6)
  DkgAckEvent get dkgAck => $_getN(5);
  @$pb.TagNumber(6)
  set dkgAck(DkgAckEvent value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDkgAck() => $_has(5);
  @$pb.TagNumber(6)
  void clearDkgAck() => $_clearField(6);
  @$pb.TagNumber(6)
  DkgAckEvent ensureDkgAck() => $_ensure(5);

  @$pb.TagNumber(7)
  DkgAckRequestEvent get dkgAckRequest => $_getN(6);
  @$pb.TagNumber(7)
  set dkgAckRequest(DkgAckRequestEvent value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDkgAckRequest() => $_has(6);
  @$pb.TagNumber(7)
  void clearDkgAckRequest() => $_clearField(7);
  @$pb.TagNumber(7)
  DkgAckRequestEvent ensureDkgAckRequest() => $_ensure(6);

  @$pb.TagNumber(8)
  SignaturesRequestEvent get signaturesRequest => $_getN(7);
  @$pb.TagNumber(8)
  set signaturesRequest(SignaturesRequestEvent value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasSignaturesRequest() => $_has(7);
  @$pb.TagNumber(8)
  void clearSignaturesRequest() => $_clearField(8);
  @$pb.TagNumber(8)
  SignaturesRequestEvent ensureSignaturesRequest() => $_ensure(7);

  @$pb.TagNumber(9)
  SignatureNewRoundsEvent get signatureNewRounds => $_getN(8);
  @$pb.TagNumber(9)
  set signatureNewRounds(SignatureNewRoundsEvent value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSignatureNewRounds() => $_has(8);
  @$pb.TagNumber(9)
  void clearSignatureNewRounds() => $_clearField(9);
  @$pb.TagNumber(9)
  SignatureNewRoundsEvent ensureSignatureNewRounds() => $_ensure(8);

  @$pb.TagNumber(10)
  SignaturesCompleteEvent get signaturesComplete => $_getN(9);
  @$pb.TagNumber(10)
  set signaturesComplete(SignaturesCompleteEvent value) =>
      $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasSignaturesComplete() => $_has(9);
  @$pb.TagNumber(10)
  void clearSignaturesComplete() => $_clearField(10);
  @$pb.TagNumber(10)
  SignaturesCompleteEvent ensureSignaturesComplete() => $_ensure(9);

  @$pb.TagNumber(11)
  SignaturesFailureEvent get signaturesFailure => $_getN(10);
  @$pb.TagNumber(11)
  set signaturesFailure(SignaturesFailureEvent value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSignaturesFailure() => $_has(10);
  @$pb.TagNumber(11)
  void clearSignaturesFailure() => $_clearField(11);
  @$pb.TagNumber(11)
  SignaturesFailureEvent ensureSignaturesFailure() => $_ensure(10);

  @$pb.TagNumber(12)
  KeepaliveEvent get keepalive => $_getN(11);
  @$pb.TagNumber(12)
  set keepalive(KeepaliveEvent value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasKeepalive() => $_has(11);
  @$pb.TagNumber(12)
  void clearKeepalive() => $_clearField(12);
  @$pb.TagNumber(12)
  KeepaliveEvent ensureKeepalive() => $_ensure(11);

  @$pb.TagNumber(13)
  SecretShareEvent get secretShare => $_getN(12);
  @$pb.TagNumber(13)
  set secretShare(SecretShareEvent value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasSecretShare() => $_has(12);
  @$pb.TagNumber(13)
  void clearSecretShare() => $_clearField(13);
  @$pb.TagNumber(13)
  SecretShareEvent ensureSecretShare() => $_ensure(12);

  @$pb.TagNumber(14)
  ConstructedKeyEvent get constructedKey => $_getN(13);
  @$pb.TagNumber(14)
  set constructedKey(ConstructedKeyEvent value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasConstructedKey() => $_has(13);
  @$pb.TagNumber(14)
  void clearConstructedKey() => $_clearField(14);
  @$pb.TagNumber(14)
  ConstructedKeyEvent ensureConstructedKey() => $_ensure(13);

  @$pb.TagNumber(15)
  SignaturesProgressEvent get signaturesProgress => $_getN(14);
  @$pb.TagNumber(15)
  set signaturesProgress(SignaturesProgressEvent value) =>
      $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasSignaturesProgress() => $_has(14);
  @$pb.TagNumber(15)
  void clearSignaturesProgress() => $_clearField(15);
  @$pb.TagNumber(15)
  SignaturesProgressEvent ensureSignaturesProgress() => $_ensure(14);
}

class ProtocolError extends $pb.GeneratedMessage {
  factory ProtocolError({
    ProtocolErrorCode? code,
    $core.String? message,
    $core.bool? retryable,
    $core.int? roomFailureCode,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    if (retryable != null) result.retryable = retryable;
    if (roomFailureCode != null) result.roomFailureCode = roomFailureCode;
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
    ..a<$core.int>(
        4, _omitFieldNames ? '' : 'roomFailureCode', $pb.PbFieldType.OU3)
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

  /// RoomFailureCode index when enrollment fails with a room-domain error.
  /// Presence matters: unknownRoom has index zero.
  @$pb.TagNumber(4)
  $core.int get roomFailureCode => $_getIZ(3);
  @$pb.TagNumber(4)
  set roomFailureCode($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRoomFailureCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearRoomFailureCode() => $_clearField(4);
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
    $core.Iterable<ConstructedKeyEvent>? constructedKeyEvents,
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
    ..pc<ConstructedKeyEvent>(
        1, _omitFieldNames ? '' : 'constructedKeyEvents', $pb.PbFieldType.PM,
        subBuilder: ConstructedKeyEvent.create)
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

  @$pb.TagNumber(1)
  $pb.PbList<ConstructedKeyEvent> get constructedKeyEvents => $_getList(0);
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

class BeginEnrollmentRequest extends $pb.GeneratedMessage {
  factory BeginEnrollmentRequest({
    $core.List<$core.int>? invite,
    $core.List<$core.int>? participantPublicKey,
  }) {
    final result = create();
    if (invite != null) result.invite = invite;
    if (participantPublicKey != null)
      result.participantPublicKey = participantPublicKey;
    return result;
  }

  BeginEnrollmentRequest._();

  factory BeginEnrollmentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeginEnrollmentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginEnrollmentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'invite', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'participantPublicKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginEnrollmentRequest clone() =>
      BeginEnrollmentRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginEnrollmentRequest copyWith(
          void Function(BeginEnrollmentRequest) updates) =>
      super.copyWith((message) => updates(message as BeginEnrollmentRequest))
          as BeginEnrollmentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeginEnrollmentRequest create() => BeginEnrollmentRequest._();
  @$core.override
  BeginEnrollmentRequest createEmptyInstance() => create();
  static $pb.PbList<BeginEnrollmentRequest> createRepeated() =>
      $pb.PbList<BeginEnrollmentRequest>();
  @$core.pragma('dart2js:noInline')
  static BeginEnrollmentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginEnrollmentRequest>(create);
  static BeginEnrollmentRequest? _defaultInstance;

  /// Canonically serialized RoomInvite, including its enrollment version.
  @$pb.TagNumber(1)
  $core.List<$core.int> get invite => $_getN(0);
  @$pb.TagNumber(1)
  set invite($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInvite() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvite() => $_clearField(1);

  /// Compressed secp256k1 public key (33 bytes).
  @$pb.TagNumber(2)
  $core.List<$core.int> get participantPublicKey => $_getN(1);
  @$pb.TagNumber(2)
  set participantPublicKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParticipantPublicKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearParticipantPublicKey() => $_clearField(2);
}

class BeginEnrollmentResponse extends $pb.GeneratedMessage {
  factory BeginEnrollmentResponse({
    $core.List<$core.int>? challenge,
  }) {
    final result = create();
    if (challenge != null) result.challenge = challenge;
    return result;
  }

  BeginEnrollmentResponse._();

  factory BeginEnrollmentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeginEnrollmentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginEnrollmentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'challenge', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginEnrollmentResponse clone() =>
      BeginEnrollmentResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginEnrollmentResponse copyWith(
          void Function(BeginEnrollmentResponse) updates) =>
      super.copyWith((message) => updates(message as BeginEnrollmentResponse))
          as BeginEnrollmentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeginEnrollmentResponse create() => BeginEnrollmentResponse._();
  @$core.override
  BeginEnrollmentResponse createEmptyInstance() => create();
  static $pb.PbList<BeginEnrollmentResponse> createRepeated() =>
      $pb.PbList<BeginEnrollmentResponse>();
  @$core.pragma('dart2js:noInline')
  static BeginEnrollmentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginEnrollmentResponse>(create);
  static BeginEnrollmentResponse? _defaultInstance;

  /// Canonically serialized EnrollmentChallenge.
  @$pb.TagNumber(1)
  $core.List<$core.int> get challenge => $_getN(0);
  @$pb.TagNumber(1)
  set challenge($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChallenge() => $_has(0);
  @$pb.TagNumber(1)
  void clearChallenge() => $_clearField(1);
}

class RedeemRoomInviteRequest extends $pb.GeneratedMessage {
  factory RedeemRoomInviteRequest({
    $core.List<$core.int>? transcript,
    $core.List<$core.int>? signature,
  }) {
    final result = create();
    if (transcript != null) result.transcript = transcript;
    if (signature != null) result.signature = signature;
    return result;
  }

  RedeemRoomInviteRequest._();

  factory RedeemRoomInviteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RedeemRoomInviteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RedeemRoomInviteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'transcript', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedeemRoomInviteRequest clone() =>
      RedeemRoomInviteRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedeemRoomInviteRequest copyWith(
          void Function(RedeemRoomInviteRequest) updates) =>
      super.copyWith((message) => updates(message as RedeemRoomInviteRequest))
          as RedeemRoomInviteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RedeemRoomInviteRequest create() => RedeemRoomInviteRequest._();
  @$core.override
  RedeemRoomInviteRequest createEmptyInstance() => create();
  static $pb.PbList<RedeemRoomInviteRequest> createRepeated() =>
      $pb.PbList<RedeemRoomInviteRequest>();
  @$core.pragma('dart2js:noInline')
  static RedeemRoomInviteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RedeemRoomInviteRequest>(create);
  static RedeemRoomInviteRequest? _defaultInstance;

  /// Canonically serialized EnrollmentTranscript; these exact bytes are signed.
  @$pb.TagNumber(1)
  $core.List<$core.int> get transcript => $_getN(0);
  @$pb.TagNumber(1)
  set transcript($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTranscript() => $_has(0);
  @$pb.TagNumber(1)
  void clearTranscript() => $_clearField(1);

  /// Schnorr signature (64 bytes).
  @$pb.TagNumber(2)
  $core.List<$core.int> get signature => $_getN(1);
  @$pb.TagNumber(2)
  set signature($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignature() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignature() => $_clearField(2);
}

class RedeemRoomInviteResponse extends $pb.GeneratedMessage {
  factory RedeemRoomInviteResponse({
    $core.List<$core.int>? snapshot,
  }) {
    final result = create();
    if (snapshot != null) result.snapshot = snapshot;
    return result;
  }

  RedeemRoomInviteResponse._();

  factory RedeemRoomInviteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RedeemRoomInviteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RedeemRoomInviteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'noosphere'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'snapshot', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedeemRoomInviteResponse clone() =>
      RedeemRoomInviteResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RedeemRoomInviteResponse copyWith(
          void Function(RedeemRoomInviteResponse) updates) =>
      super.copyWith((message) => updates(message as RedeemRoomInviteResponse))
          as RedeemRoomInviteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RedeemRoomInviteResponse create() => RedeemRoomInviteResponse._();
  @$core.override
  RedeemRoomInviteResponse createEmptyInstance() => create();
  static $pb.PbList<RedeemRoomInviteResponse> createRepeated() =>
      $pb.PbList<RedeemRoomInviteResponse>();
  @$core.pragma('dart2js:noInline')
  static RedeemRoomInviteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RedeemRoomInviteResponse>(create);
  static RedeemRoomInviteResponse? _defaultInstance;

  /// Canonically serialized RoomSnapshot.
  @$pb.TagNumber(1)
  $core.List<$core.int> get snapshot => $_getN(0);
  @$pb.TagNumber(1)
  set snapshot($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSnapshot() => $_has(0);
  @$pb.TagNumber(1)
  void clearSnapshot() => $_clearField(1);
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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

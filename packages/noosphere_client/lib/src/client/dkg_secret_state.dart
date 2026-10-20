import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:noosphere_protocol/common.dart';
import 'package:noosphere_protocol/domain.dart';

enum DkgSecretStage { round1, round2 }

/// Opaque private state exported to resume a published DKG contribution.
final class DkgSecretState({
  required final String name,
  required final Uint8List ceremonyId,
  required final DkgSecretStage stage,
  required final Uint8List secret,
  final DkgPublicCommitment? outgoingCommitment,
  final DkgCommitmentSet? commitmentSet,
  final cl.SchnorrSignature? outgoingSignature,
  final Map<Identifier, DkgEncryptedSecret> outgoingSecrets = const {},
}) with cl.Writable, NoosphereWritable {
  factory DkgSecretState.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, (reader) {
        final name = reader.readString();
        final ceremonyId = reader.readSlice(32);
        final stage = switch (reader.readUInt8()) {
          0 => DkgSecretStage.round1,
          1 => DkgSecretStage.round2,
          _ => throw const FormatException('unknown DKG secret stage'),
        };
        final secret = reader.readVarSlice();
        if (secret.isEmpty) throw const FormatException('empty DKG secret');
        if (stage == DkgSecretStage.round1) {
          return DkgSecretState(
            name: name,
            ceremonyId: ceremonyId,
            stage: stage,
            secret: secret,
            outgoingCommitment: DkgPublicCommitment.fromBytes(
              reader.readVarSlice(),
            ),
          );
        }

        final commitmentSet = readNoosphere(
          reader.readVarSlice(),
          DkgCommitmentSet.fromReader,
        );
        final signature = cl.SchnorrSignature(reader.readSlice(64));
        final outgoing = <Identifier, DkgEncryptedSecret>{};
        Identifier? previous;
        for (var i = reader.readUInt16(); i > 0; i--) {
          final id = Identifier.fromBytes(reader.readSlice(32));
          if (previous != null && previous.compareTo(id) >= 0) {
            throw const FormatException('non-canonical DKG secret recipients');
          }
          previous = id;
          outgoing[id] = DkgEncryptedSecret.fromBytes(reader.readVarSlice());
        }
        return DkgSecretState(
          name: name,
          ceremonyId: ceremonyId,
          stage: stage,
          secret: secret,
          commitmentSet: commitmentSet,
          outgoingSignature: signature,
          outgoingSecrets: outgoing,
        );
      });

  @override
  void write(cl.Writer writer) {
    writer
      ..writeString(name)
      ..writeSlice(ceremonyId)
      ..writeUInt8(stage.index)
      ..writeVarSlice(secret);
    if (stage == DkgSecretStage.round1) {
      writer.writeVarSlice(outgoingCommitment!.toBytes());
      return;
    }

    writer
      ..writeVarSlice(commitmentSet!.toBytes())
      ..writeSlice(outgoingSignature!.data);
    final entries = outgoingSecrets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    writer.writeUInt16(entries.length);
    for (final MapEntry(:key, :value) in entries) {
      writer
        ..writeSlice(key.toBytes())
        ..writeVarSlice(value.toBytes());
    }
  }
}

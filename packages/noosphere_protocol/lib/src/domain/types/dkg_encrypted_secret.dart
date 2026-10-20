import 'dart:typed_data';

import 'package:coinlib/coinlib.dart' as cl;
import 'package:frosty/frosty.dart';
import 'package:noosphere_protocol/src/common/serial.dart';

/// A recipient-specific DKG share signed together with its protocol context.
final class DkgEncryptedSecret({
  required this.ciphertext,
  required this.envelopeSignature,
}) with cl.Writable, NoosphereWritable {
  static final _hasher = cl.getTaggedHasher('NoosphereDkgShareEnvelopeV4');

  final ECCiphertext ciphertext;
  final cl.SchnorrSignature envelopeSignature;

  DkgEncryptedSecret.fromReader(cl.BytesReader reader)
    : this(
        ciphertext: ECCiphertext.fromBytes(reader.readVarSlice()),
        envelopeSignature: reader.readSignature(),
      );

  factory DkgEncryptedSecret.fromBytes(Uint8List bytes) =>
      readNoosphere(bytes, DkgEncryptedSecret.fromReader);

  factory DkgEncryptedSecret.encrypt({
    required DkgShareToGive secretShare,
    required int protocolVersion,
    required Uint8List ceremonyId,
    required Uint8List transcriptHash,
    required Identifier sender,
    required Identifier recipient,
    required cl.ECPublicKey recipientKey,
    required cl.ECPrivateKey senderKey,
  }) {
    final ciphertext = ECCiphertext.encrypt(
      plaintext: secretShare.toBytes(),
      recipientKey: recipientKey,
      senderKey: senderKey,
    );
    return DkgEncryptedSecret(
      ciphertext: ciphertext,
      envelopeSignature: cl.SchnorrSignature.sign(
        senderKey,
        _hash(
          protocolVersion,
          ceremonyId,
          transcriptHash,
          sender,
          recipient,
          ciphertext,
        ),
      ),
    );
  }

  bool verify({
    required int protocolVersion,
    required Uint8List ceremonyId,
    required Uint8List transcriptHash,
    required Identifier sender,
    required Identifier recipient,
    required cl.ECPublicKey senderKey,
  }) => envelopeSignature.verify(
    senderKey,
    _hash(
      protocolVersion,
      ceremonyId,
      transcriptHash,
      sender,
      recipient,
      ciphertext,
    ),
  );

  DkgShareToGive? decrypt({
    required int protocolVersion,
    required Uint8List ceremonyId,
    required Uint8List transcriptHash,
    required Identifier sender,
    required Identifier recipient,
    required cl.ECPrivateKey recipientKey,
    required cl.ECPublicKey senderKey,
  }) {
    if (!verify(
      protocolVersion: protocolVersion,
      ceremonyId: ceremonyId,
      transcriptHash: transcriptHash,
      sender: sender,
      recipient: recipient,
      senderKey: senderKey,
    )) {
      return null;
    }
    final plaintext = ciphertext.decrypt(
      recipientKey: recipientKey,
      senderKey: senderKey,
    );
    try {
      return plaintext == null ? null : DkgShareToGive.fromBytes(plaintext);
    } on InvalidShareToGive {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  void write(cl.Writer writer) => writer
    ..writeVarSlice(ciphertext.toBytes())
    ..writeSignature(envelopeSignature);

  static Uint8List _hash(
    int protocolVersion,
    Uint8List ceremonyId,
    Uint8List transcriptHash,
    Identifier sender,
    Identifier recipient,
    ECCiphertext ciphertext,
  ) {
    RangeError.checkValueInInterval(protocolVersion, 0, 0xffff);
    if (ceremonyId.length != 32 || transcriptHash.length != 32) {
      throw const FormatException('Invalid DKG share context');
    }
    return _hasher(
      Uint8List.fromList([
        protocolVersion & 0xff,
        protocolVersion >> 8,
        ...ceremonyId,
        ...transcriptHash,
        ...sender.toBytes(),
        ...recipient.toBytes(),
        ...ciphertext.toBytes(),
      ]),
    );
  }
}

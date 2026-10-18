import 'package:noosphere_client/noosphere_client.dart';

import 'config_codec.dart';

Map<String, Object?> encodeSignaturesNonces(SignaturesNonces nonces) => {
  'expiryMicros': nonces.expiry.time.microsecondsSinceEpoch,
  'values': [
    for (final entry in nonces.map.entries)
      {'index': entry.key, 'nonce': entry.value.toBytes()},
  ],
};

SignaturesNonces decodeSignaturesNonces(Map<Object?, Object?> value) =>
    SignaturesNonces(
      {
        for (final item in value['values']! as List)
          (item as Map<Object?, Object?>)['index']! as int:
              SigningNonces.fromBytes(asBytes(item['nonce'])),
      },
      Expiry.fromTime(
        DateTime.fromMicrosecondsSinceEpoch(value['expiryMicros']! as int),
      ),
    );

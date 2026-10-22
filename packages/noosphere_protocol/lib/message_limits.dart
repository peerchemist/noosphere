/// Size limits for messages crossing Noosphere API, transport, or isolate
/// boundaries. All limits are expressed in bytes.
library;

/// Maximum UTF-8 byte length of a signature request explanation. This allows
/// up to 1024 characters when each encodes to one byte, or fewer multibyte
/// characters.
const int signatureRequestMessageMaxBytes = 1024;

/// Maximum UTF-8 byte length of a signed text payload. This allows up to 1024
/// characters when each encodes to one byte, or fewer multibyte characters.
const int signedMessageTextMaxBytes = 1024;

/// Default maximum byte length of a QUIC message body.
const int defaultMaxMessageLength = 1024 * 1024;

/// Maximum byte length of a public-feed request body.
const int publicFeedMaxRequestBytes = 256;

/// Maximum byte length of a signed public-feed response.
const int publicFeedMaxResponseBytes = 64 * 1024;

/// Maximum byte length of an encrypted DKG share sent to the coordinator.
const int encryptedDkgShareMaxBytes = 4 * 1024;

/// Default maximum approximate size of a Flutter isolate message.
const int defaultWorkerMaxMessageBytes = 8 * 1024 * 1024;

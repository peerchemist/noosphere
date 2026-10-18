// Internal host/worker protocol. Both ends ship in the same package.
export 'worker/config_codec.dart';
export 'worker/message_size.dart';
export 'worker/messages.dart';
export 'worker/serial_executor.dart';
export 'worker/storage_codec.dart';

const int defaultWorkerMaxMessageBytes = 8 * 1024 * 1024;

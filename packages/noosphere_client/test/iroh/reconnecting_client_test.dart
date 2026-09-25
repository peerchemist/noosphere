import 'package:noosphere_client/iroh_transport.dart';
import 'package:test/test.dart';

void main() {
  test('reconnect backoff applies jitter and caps the delay', () {
    const config = IrohReconnectConfig(
      initialDelay: Duration(milliseconds: 100),
      maxDelay: Duration(milliseconds: 250),
      multiplier: 2,
      jitter: 0.1,
    );

    expect(config.delayForAttempt(0, 0), const Duration(milliseconds: 90));
    expect(config.delayForAttempt(1, 0.5), const Duration(milliseconds: 200));
    expect(config.delayForAttempt(2, 1), const Duration(milliseconds: 250));
  });

  test('reconnect backoff rejects invalid inputs', () {
    const invalidConfig = IrohReconnectConfig(
      initialDelay: Duration(seconds: 2),
      maxDelay: Duration(seconds: 1),
    );
    const validConfig = IrohReconnectConfig();

    expect(() => invalidConfig.delayForAttempt(0, 0.5), throwsArgumentError);
    expect(() => validConfig.delayForAttempt(-1, 0.5), throwsRangeError);
    expect(() => validConfig.delayForAttempt(0, 1.1), throwsRangeError);
  });
}

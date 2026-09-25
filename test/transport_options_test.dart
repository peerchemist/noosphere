import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

void main() {
  test('uses bounded Flutter transport stream defaults', () {
    expect(defaultClientMaxConcurrentStreams, 2);
    expect(defaultServerMaxStreamsPerConnection, 4);
  });
}

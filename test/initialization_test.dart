import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

void main() {
  tearDown(NoosphereFlutter.debugResetInitialization);

  test('concurrent initialization shares one in-flight future', () async {
    final completion = Completer<void>();
    var calls = 0;
    NoosphereFlutter.debugResetInitialization(
      initializer: () {
        calls++;
        return completion.future;
      },
    );

    final first = NoosphereFlutter.initialize();
    final second = NoosphereFlutter.initialize();

    expect(identical(first, second), isTrue);
    expect(calls, 1);

    completion.complete();
    await Future.wait([first, second]);
    expect(identical(first, NoosphereFlutter.initialize()), isTrue);
    expect(calls, 1);
  });

  test('initialization retains the original failure', () async {
    final failure = StateError('native load failed');
    NoosphereFlutter.debugResetInitialization(
      initializer: () => Future<void>.error(failure, StackTrace.current),
    );

    final first = NoosphereFlutter.initialize();
    final second = NoosphereFlutter.initialize();

    expect(identical(first, second), isTrue);
    await expectLater(first, throwsA(same(failure)));
    await expectLater(second, throwsA(same(failure)));
  });
}

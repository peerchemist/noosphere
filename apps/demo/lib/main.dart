import 'package:flutter/material.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'node_screen.dart';

Future<void> main() async {
  await NoosphereFlutter.initialize();
  runApp(const NoosphereExampleApp());
}

final class NoosphereExampleApp extends StatelessWidget {
  const NoosphereExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Noosphere 2-of-2 test',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: const NodeScreen(),
  );
}

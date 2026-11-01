import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const WavemindApp());
}

class WavemindApp extends StatelessWidget {
  const WavemindApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wavemind uses light content on a dark, deep-sea backdrop.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'Wavemind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // The auth gate validates any stored session token on launch and routes
      // to the Helm dashboard (valid) or the Welcome screen (missing/invalid).
      home: const AuthGate(),
    );
  }
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Environment / runtime configuration for the tiny remote profile backend
/// (see `backend/` — it stores only name / email / phone).
///
/// `baseUrl` defaults per platform because `localhost` resolves differently
/// depending on where the app runs:
///   - Android emulator: the host machine is reachable at `10.0.2.2`.
///   - iOS simulator / desktop: `localhost` maps to the host directly.
///
/// Override for a physical device (or staging/prod) with:
///   `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8010`
abstract final class AppConfig {
  /// Port the FastAPI profile service listens on (see backend/README.md).
  static const int apiPort = 8010;

  static const String _override = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // Web and desktop use localhost; the Android emulator needs the 10.0.2.2
    // alias to reach the host machine.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$apiPort';
    }
    return 'http://localhost:$apiPort';
  }

  /// Kept short so a missing / unreachable backend fails fast and the profile
  /// screen can surface a clear error rather than hanging the UI. The rest of
  /// the app never blocks on this service.
  static const Duration requestTimeout = Duration(seconds: 8);
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Environment / runtime configuration for the TideWell backend (see
/// `backend/` — accounts, content catalog, leaderboard).
///
/// `baseUrl` is always `https://` — the dev backend serves real TLS via a
/// locally-trusted mkcert certificate (see `tool/gen_dev_cert.sh`), not
/// plaintext HTTP, so login/session traffic is never sent in the clear, even
/// on a local network. The default per-platform host differs because
/// `localhost` resolves differently depending on where the app runs:
///   - Android emulator: the host machine is reachable at `10.0.2.2`.
///   - iOS simulator / desktop: `localhost` maps to the host directly.
///
/// Override for a physical device (or staging/prod) with:
///   `flutter run --dart-define=API_BASE_URL=https://192.168.x.x:8010`
/// A real device additionally needs the mkcert root CA installed and
/// trusted (see `tool/gen_dev_cert.sh`'s printed instructions) — without
/// that, HTTPS requests to the dev cert fail cert validation, by design.
abstract final class AppConfig {
  /// Port the FastAPI backend listens on (see backend/README.md).
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
      return 'https://10.0.2.2:$apiPort';
    }
    return 'https://localhost:$apiPort';
  }

  /// Kept short so a missing / unreachable backend fails fast and the profile
  /// screen can surface a clear error rather than hanging the UI. The rest of
  /// the app never blocks on this service.
  static const Duration requestTimeout = Duration(seconds: 8);

  /// Media files can be a few MB each, so allow a more generous window than the
  /// metadata calls. Downloads are lazy and off the UI thread; a timeout here
  /// just means "fall back to the bundled asset for now".
  static const Duration mediaDownloadTimeout = Duration(seconds: 30);
}

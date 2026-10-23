import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure, platform-backed store for the single auth session token.
///
/// Uses the iOS Keychain and encrypted Android storage via
/// [FlutterSecureStorage] — a credential must never sit in plain
/// sqflite/shared_preferences (unlike the content-catalog cache). This wrapper
/// keeps the single key name in one place and hides the package behind a tiny
/// interface so screens depend on an intent ("read/save/clear the token"), not
/// on the storage package directly.
///
/// On Android, flutter_secure_storage v11 encrypts values with AES-GCM by
/// default, so no extra [AndroidOptions] flag is needed.
class AuthTokenStorage {
  AuthTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'tidewell.auth.session_token';

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> save(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}

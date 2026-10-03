import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'models/user_profile.dart';

/// Thrown for any failure talking to the profile backend, carrying a short,
/// user-facing [message] the profile screen can surface directly.
class ProfileApiException implements Exception {
  const ProfileApiException(this.message);
  final String message;

  @override
  String toString() => 'ProfileApiException: $message';
}

/// Thin HTTP client for the tiny remote profile service (name/email/phone).
///
/// This is the only network dependency in the app, and it is deliberately
/// non-blocking for the rest of the experience: callers are expected to catch
/// [ProfileApiException] and show a message rather than letting a missing
/// backend break anything.
class ProfileApi {
  ProfileApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _endpoint => Uri.parse('${AppConfig.baseUrl}/profile');

  /// Fetch the stored profile, or `null` if none has been saved yet.
  Future<UserProfile?> fetch() async {
    final http.Response res;
    try {
      res = await _client
          .get(_endpoint, headers: const {'Accept': 'application/json'})
          .timeout(AppConfig.requestTimeout);
    } catch (_) {
      throw const ProfileApiException(
        'Could not reach the crew registry. Check that the backend is running.',
      );
    }
    if (res.statusCode != 200) {
      throw ProfileApiException('Server error (${res.statusCode}).');
    }
    final body = res.body.trim();
    if (body.isEmpty || body == 'null') return null;
    try {
      return UserProfile.fromJson(jsonDecode(body) as Map<String, Object?>);
    } catch (_) {
      throw const ProfileApiException('Received an unexpected response.');
    }
  }

  /// Upsert the profile. Returns the stored record echoed back by the server.
  Future<UserProfile> save(UserProfile profile) async {
    final http.Response res;
    try {
      res = await _client
          .put(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(profile.toJson()),
          )
          .timeout(AppConfig.requestTimeout);
    } catch (_) {
      throw const ProfileApiException(
        'Could not reach the crew registry. Check that the backend is running.',
      );
    }
    if (res.statusCode == 422) {
      throw const ProfileApiException(
        'Please check the details entered and try again.',
      );
    }
    if (res.statusCode != 200) {
      throw ProfileApiException('Server error (${res.statusCode}).');
    }
    try {
      return UserProfile.fromJson(
        jsonDecode(res.body) as Map<String, Object?>,
      );
    } catch (_) {
      throw const ProfileApiException('Received an unexpected response.');
    }
  }

  void dispose() => _client.close();
}

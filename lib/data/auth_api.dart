import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'models/account.dart';
import 'models/leaderboard_entry.dart';

/// Thrown for any failure talking to the accounts backend, carrying a short,
/// user-facing [message] the auth screens can surface directly.
///
/// [isAuthFailure] distinguishes a server-rejected credential (bad login,
/// duplicate email, invalid token) from a transport/server problem, so callers
/// can tell "your details were wrong" apart from "we couldn't reach the server"
/// without string-matching the message.
class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.isAuthFailure = false});

  final String message;
  final bool isAuthFailure;

  @override
  String toString() => 'AuthApiException: $message';
}

/// Thin HTTP client for the TideWell accounts service (`/auth/*`, plus the
/// account-scoped `/me/points` and `/leaderboard` endpoints).
///
/// Follows the app's HTTP-client pattern: typed exceptions, [AppConfig] base URL, a
/// sane request timeout, and clear messages that separate network failures from
/// server-rejected credentials. Callers catch [AuthApiException] and surface
/// the message rather than letting a failed call crash or hang the screen.
class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Create a new account. Throws [AuthApiException] with [isAuthFailure] set
  /// for a duplicate email (409) or invalid input (422).
  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
    required int age,
    required String sex,
    String? fleetName,
  }) async {
    final body = <String, Object?>{
      'name': name,
      'email': email,
      'password': password,
      'age': age,
      'sex': sex,
      if (fleetName != null && fleetName.isNotEmpty) 'fleet_name': fleetName,
    };
    final res = await _send('POST', '/auth/signup', body: body);
    if (res.statusCode == 409) {
      throw AuthApiException(
        _detailOr(res, 'An account with that email already exists.'),
        isAuthFailure: true,
      );
    }
    if (res.statusCode == 422) {
      throw const AuthApiException(
        'Please check the details entered and try again.',
        isAuthFailure: true,
      );
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw AuthApiException('Server error (${res.statusCode}).');
    }
    return _parseAuth(res);
  }

  /// Verify credentials and open a session. Throws with [isAuthFailure] set on
  /// a 401 (generic "invalid email or password").
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    if (res.statusCode == 401) {
      throw AuthApiException(
        _detailOr(res, 'Invalid email or password.'),
        isAuthFailure: true,
      );
    }
    if (res.statusCode != 200) {
      throw AuthApiException('Server error (${res.statusCode}).');
    }
    return _parseAuth(res);
  }

  /// Validate a stored token and return the current user. Throws with
  /// [isAuthFailure] set on a 401 so callers know to clear the stale token.
  Future<Account> me(String token) async {
    final res = await _send('GET', '/auth/me', token: token);
    if (res.statusCode == 401) {
      throw const AuthApiException('Session expired.', isAuthFailure: true);
    }
    if (res.statusCode != 200) {
      throw AuthApiException('Server error (${res.statusCode}).');
    }
    return _parseAccount(res);
  }

  /// Partial update of the caller's own profile fields (name/age/sex/fleet).
  Future<Account> updateProfile(
    String token, {
    String? name,
    int? age,
    String? sex,
    String? fleetName,
  }) async {
    final body = <String, Object?>{
      'name': ?name,
      'age': ?age,
      'sex': ?sex,
      // fleet_name is explicitly nullable server-side; send it through even
      // when cleared so the user can remove it.
      if (fleetName != null) 'fleet_name': fleetName.isEmpty ? null : fleetName,
    };
    final res = await _send('PATCH', '/auth/me', body: body, token: token);
    if (res.statusCode == 401) {
      throw const AuthApiException('Session expired.', isAuthFailure: true);
    }
    if (res.statusCode == 422) {
      throw const AuthApiException(
        'Please check the details entered and try again.',
        isAuthFailure: true,
      );
    }
    if (res.statusCode != 200) {
      throw AuthApiException('Server error (${res.statusCode}).');
    }
    return _parseAccount(res);
  }

  /// Delete the server-side session. Best-effort: a failure here is swallowed
  /// by callers (the local token is cleared regardless).
  Future<void> logout(String token) async {
    await _send('POST', '/auth/logout', token: token);
  }

  /// Overwrites the caller's Fleet Knots total on the backend. Always the
  /// whole current total (never a delta) — the on-device ledger stays the
  /// source of truth for *how* it was earned.
  Future<void> updatePoints(String token, int totalPoints) async {
    final res = await _send(
      'PUT',
      '/me/points',
      body: {'total_points': totalPoints},
      token: token,
    );
    if (res.statusCode == 401) {
      throw const AuthApiException('Session expired.', isAuthFailure: true);
    }
    if (res.statusCode != 200) {
      throw AuthApiException('Server error (${res.statusCode}).');
    }
  }

  /// The real, multi-user leaderboard: the top [limit] accounts by points,
  /// plus the caller's own row (with their true rank) if they aren't already
  /// in that top slice.
  Future<List<LeaderboardEntry>> leaderboard(
    String token, {
    int limit = 4,
  }) async {
    final res = await _send(
      'GET',
      '/leaderboard?limit=$limit',
      token: token,
    );
    if (res.statusCode == 401) {
      throw const AuthApiException('Session expired.', isAuthFailure: true);
    }
    if (res.statusCode != 200) {
      throw AuthApiException('Server error (${res.statusCode}).');
    }
    try {
      final decoded = jsonDecode(res.body) as Map<String, Object?>;
      final rows = (decoded['entries'] as List).cast<Map<String, Object?>>();
      return rows.map(LeaderboardEntry.fromJson).toList();
    } catch (_) {
      throw const AuthApiException('Received an unexpected response.');
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final headers = {
      ..._jsonHeaders,
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = _uri(path);
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client
          .send(request)
          .timeout(AppConfig.requestTimeout);
      return http.Response.fromStream(streamed)
          .timeout(AppConfig.requestTimeout);
    } catch (_) {
      throw const AuthApiException(
        'Could not reach the crew registry. Check that the backend is '
        'running and try again.',
      );
    }
  }

  AuthResult _parseAuth(http.Response res) {
    try {
      return AuthResult.fromJson(jsonDecode(res.body) as Map<String, Object?>);
    } catch (_) {
      throw const AuthApiException('Received an unexpected response.');
    }
  }

  Account _parseAccount(http.Response res) {
    try {
      return Account.fromJson(jsonDecode(res.body) as Map<String, Object?>);
    } catch (_) {
      throw const AuthApiException('Received an unexpected response.');
    }
  }

  /// Pull FastAPI's `{"detail": "..."}` message out of an error body, falling
  /// back to [fallback] when it isn't a plain string (e.g. 422 validation
  /// lists).
  String _detailOr(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // fall through
    }
    return fallback;
  }

  void dispose() => _client.close();
}

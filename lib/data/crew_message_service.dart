import 'auth_api.dart';
import 'auth_token_storage.dart';
import 'models/crew_message.dart';

/// The shared "cast a float bottle" crew messages — the latest 3, newest
/// first, fetched for everyone to see under the Gratitude Wall. Casting a
/// new one bumps every older one down a slot; the oldest falls off past 3.
class CrewMessageService {
  CrewMessageService({AuthApi? api, AuthTokenStorage? tokenStorage})
    : _api = api ?? AuthApi(),
      _tokenStorage = tokenStorage ?? AuthTokenStorage();

  final AuthApi _api;
  final AuthTokenStorage _tokenStorage;

  /// Null when there's no signed-in session or the fetch failed — callers
  /// degrade gracefully rather than showing fake notes. An empty (non-null)
  /// message list means the session is fine but no one has cast one yet.
  Future<CrewMessagesPage?> fetchLatest() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return null;
    return _api.crewMessages(token);
  }

  /// Throws [AuthApiException] on failure (no session, network, server
  /// error, or — with [AuthApiException.isAuthFailure] set — the account
  /// is currently suspended from casting).
  Future<CrewMessage> cast(String body) async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      throw const AuthApiException('Session expired.', isAuthFailure: true);
    }
    return _api.postCrewMessage(token, body);
  }

  /// Flags [messageId]. Throws [AuthApiException] on failure (no session,
  /// network/server error, or the message no longer exists).
  Future<void> flag(int messageId) async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      throw const AuthApiException('Session expired.', isAuthFailure: true);
    }
    await _api.flagCrewMessage(token, messageId);
  }
}

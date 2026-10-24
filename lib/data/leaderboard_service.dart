import 'auth_api.dart';
import 'auth_token_storage.dart';
import 'models/leaderboard_entry.dart';

/// Pushes the sailor's current Fleet Knots total to the backend and pulls
/// the real, multi-user leaderboard back — Helm's rank badge and Crew's
/// Leadership Board both call this instead of ranking against fake data.
///
/// Returns `null` when there's no signed-in session to sync with (there is
/// no legitimate "logged out but viewing the leaderboard" state in this
/// app — behind the auth gate a token should always be present). Any
/// [AuthApiException] (network/server failure) propagates to the caller,
/// which should degrade gracefully — hide the rank/leaderboard — rather
/// than ever falling back to fake numbers.
class LeaderboardService {
  LeaderboardService({AuthApi? api, AuthTokenStorage? tokenStorage})
    : _api = api ?? AuthApi(),
      _tokenStorage = tokenStorage ?? AuthTokenStorage();

  final AuthApi _api;
  final AuthTokenStorage _tokenStorage;

  Future<List<LeaderboardEntry>?> sync(int totalKnots, {int limit = 4}) async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return null;
    await _api.updatePoints(token, totalKnots);
    return _api.leaderboard(token, limit: limit);
  }
}

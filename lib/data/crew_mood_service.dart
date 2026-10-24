import 'auth_api.dart';
import 'auth_token_storage.dart';
import 'models/crew_mood_summary.dart';
import 'models/mood_state.dart';

/// Pushes the sailor's latest local mood check-in to the backend (if they've
/// ever logged one) and pulls back the real, anonymous crew-wide "% calm"
/// summary the Anchor Pool's "Anonymized Crew Swell" card shows.
///
/// Returns `null` when there's no signed-in session, or when
/// [AuthApiException] is thrown by the network call — the caller degrades
/// gracefully (hides the summary) rather than ever showing a fabricated
/// percentage.
class CrewMoodService {
  CrewMoodService({AuthApi? api, AuthTokenStorage? tokenStorage})
    : _api = api ?? AuthApi(),
      _tokenStorage = tokenStorage ?? AuthTokenStorage();

  final AuthApi _api;
  final AuthTokenStorage _tokenStorage;

  Future<CrewMoodSummary?> sync(MoodState? latestLocalState) async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return null;
    if (latestLocalState != null) {
      await _api.updateMood(token, latestLocalState);
    }
    return _api.crewMoodSummary(token);
  }
}

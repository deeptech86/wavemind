/// The five "inner water state" options a sailor can log on the mood check-in
/// screen. The [label] text must match the on-screen copy exactly; [key] is the
/// stable value persisted to the local database (so labels can be reworded
/// without migrating stored rows).
///
/// [waveScore] maps each state onto a 1–5 calm scale (higher == calmer) so the
/// Weekly Emotional Wave chart can plot logged moods as a line.
enum MoodState {
  calmSea(key: 'calm_sea', label: 'Calm Sea', waveScore: 5),
  gentleSwell(key: 'gentle_swell', label: 'Gentle Swell', waveScore: 4),
  choppyWater(key: 'choppy_water', label: 'Choppy Water', waveScore: 3),
  drifting(key: 'drifting', label: 'Drifting', waveScore: 2),
  highStorm(key: 'high_storm', label: 'High Storm', waveScore: 1);

  const MoodState({
    required this.key,
    required this.label,
    required this.waveScore,
  });

  final String key;
  final String label;
  final int waveScore;

  static MoodState fromKey(String key) {
    return MoodState.values.firstWhere(
      (m) => m.key == key,
      orElse: () => MoodState.gentleSwell,
    );
  }
}

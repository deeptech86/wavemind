import 'mood_state.dart';

/// A logged "Emotional Swell" mood check-in stored on-device.
///
/// The three influence-factor ratings mirror the on-screen fields: Voyage Sleep
/// Quality, Outside Sea Weather and Shore Homesickness (each 1–5 stars).
class MoodCheckIn {
  const MoodCheckIn({
    this.id,
    required this.state,
    required this.sleepQuality,
    required this.seaWeather,
    required this.homesickness,
    required this.createdAt,
  });

  final int? id;
  final MoodState state;
  final int sleepQuality;
  final int seaWeather;
  final int homesickness;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'state': state.key,
    'sleep_quality': sleepQuality,
    'sea_weather': seaWeather,
    'homesickness': homesickness,
    'created_at': createdAt.toIso8601String(),
  };

  factory MoodCheckIn.fromMap(Map<String, Object?> map) => MoodCheckIn(
    id: map['id'] as int?,
    state: MoodState.fromKey(map['state'] as String? ?? ''),
    sleepQuality: (map['sleep_quality'] as int?) ?? 0,
    seaWeather: (map['sea_weather'] as int?) ?? 0,
    homesickness: (map['homesickness'] as int?) ?? 0,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

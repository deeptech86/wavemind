/// A completed (or meaningfully progressed) Tidal Breath session stored
/// on-device. Streaks and session counts are computed from these rows.
class BreathingSession {
  const BreathingSession({
    this.id,
    required this.durationSeconds,
    required this.createdAt,
  });

  final int? id;

  /// How long the session ran before it was recorded, in seconds.
  final int durationSeconds;

  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'duration_seconds': durationSeconds,
    'created_at': createdAt.toIso8601String(),
  };

  factory BreathingSession.fromMap(Map<String, Object?> map) =>
      BreathingSession(
        id: map['id'] as int?,
        durationSeconds: (map['duration_seconds'] as int?) ?? 0,
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

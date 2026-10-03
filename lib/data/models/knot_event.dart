/// The point-earning activities that award Fleet Knots.
///
/// Point values are sourced verbatim from the Crew screen's own
/// "How Fleet Knots are Earned" copy (see `community_connect_screen.dart`):
///   "Gain knots by checking your daily swell (+30), casting float bottles
///    (+40), and completing shift-change breath routines (+50)."
///
/// Mapping the three in-app actions we persist onto those tiers:
///   - mood check-in  -> daily swell          (+30, a direct match)
///   - journal entry  -> reflective writing   (+40, the "float bottle" tier —
///                       the closest written/reflective action to composing a
///                       float-bottle message; +30/+50 are literally mood/breath)
///   - breathing session -> breath routine    (+50, a direct match)
enum KnotEventType {
  moodCheckIn(key: 'mood_check_in', knots: 30),
  journalEntry(key: 'journal_entry', knots: 40),
  breathingSession(key: 'breathing_session', knots: 50);

  const KnotEventType({required this.key, required this.knots});

  final String key;
  final int knots;

  static KnotEventType fromKey(String key) {
    return KnotEventType.values.firstWhere(
      (t) => t.key == key,
      orElse: () => KnotEventType.moodCheckIn,
    );
  }
}

/// A single auditable entry in the Fleet Knots ledger. The running total is
/// always the sum of these rows — there is no mutable counter.
class KnotEvent {
  const KnotEvent({
    this.id,
    required this.type,
    required this.knots,
    required this.createdAt,
  });

  final int? id;
  final KnotEventType type;
  final int knots;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'type': type.key,
    'knots': knots,
    'created_at': createdAt.toIso8601String(),
  };

  factory KnotEvent.fromMap(Map<String, Object?> map) => KnotEvent(
    id: map['id'] as int?,
    type: KnotEventType.fromKey(map['type'] as String? ?? ''),
    knots: (map['knots'] as int?) ?? 0,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

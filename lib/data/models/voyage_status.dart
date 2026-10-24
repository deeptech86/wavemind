/// Whether the sailor is currently docked or mid-voyage, set by hand on the
/// Helm screen. There is no backend concept of this — it is a purely
/// on-device, user-declared status.
enum VoyageState { docked, voyage }

/// The sailor's self-declared voyage status, persisted on-device.
///
/// A voyage's day count only ever goes in one direction: the sailor enters
/// how many days are left when they save, and [daysRemaining] counts that
/// down from [anchoredAt] rather than counting up from a start date.
class VoyageStatus {
  const VoyageStatus({
    required this.state,
    this.origin,
    this.destination,
    this.totalDays,
    this.anchoredAt,
  });

  final VoyageState state;
  final String? origin;
  final String? destination;

  /// Days remaining as entered by the sailor at save time.
  final int? totalDays;

  /// The date [totalDays] was saved against — the countdown baseline.
  final DateTime? anchoredAt;

  /// Days left, floored at 0. Null for a docked status or incomplete data.
  int? daysRemaining([DateTime? now]) {
    if (state != VoyageState.voyage || totalDays == null || anchoredAt == null) {
      return null;
    }
    final today = _dateOnly(now ?? DateTime.now());
    final anchoredDate = _dateOnly(anchoredAt!);
    final elapsed = today.difference(anchoredDate).inDays;
    final remaining = totalDays! - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// How this status should actually be displayed right now: a voyage whose
  /// countdown has reached 0 reads as docked, with no separate write-back
  /// needed to flip it.
  VoyageState effectiveState([DateTime? now]) {
    if (state == VoyageState.voyage && (daysRemaining(now) ?? 0) <= 0) {
      return VoyageState.docked;
    }
    return state;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, Object?> toMap() => {
    'id': 1,
    'status': state.name,
    'origin': origin,
    'destination': destination,
    'total_days': totalDays,
    'anchored_at': anchoredAt?.toIso8601String(),
  };

  factory VoyageStatus.fromMap(Map<String, Object?> map) => VoyageStatus(
    state: map['status'] == 'voyage' ? VoyageState.voyage : VoyageState.docked,
    origin: map['origin'] as String?,
    destination: map['destination'] as String?,
    totalDays: (map['total_days'] as num?)?.toInt(),
    anchoredAt: map['anchored_at'] != null
        ? DateTime.tryParse(map['anchored_at'] as String)
        : null,
  );
}

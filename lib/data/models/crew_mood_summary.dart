/// Anonymous, crew-wide aggregate of everyone's latest logged mood.
///
/// Returned by `GET /crew/mood-summary` — never attributed to any one
/// account, just the overall percentage reading "calm" and how many
/// accounts have ever logged a mood at all.
class CrewMoodSummary {
  const CrewMoodSummary({required this.calmPercent, required this.totalLogged});

  final int calmPercent;
  final int totalLogged;

  factory CrewMoodSummary.fromJson(Map<String, Object?> json) =>
      CrewMoodSummary(
        calmPercent: (json['calm_percent'] as num?)?.toInt() ?? 0,
        totalLogged: (json['total_logged'] as num?)?.toInt() ?? 0,
      );
}

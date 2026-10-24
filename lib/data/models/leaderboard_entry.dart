/// One row of the real, backend-sourced Fleet Knots leaderboard.
///
/// Returned by `GET /leaderboard`: the top N accounts by points, plus the
/// caller's own row (marked [isMe]) appended with their true [rank] if they
/// didn't already make the top N.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    this.fleetName,
    required this.totalPoints,
    required this.rank,
    required this.isMe,
  });

  final String name;
  final String? fleetName;
  final int totalPoints;
  final int rank;
  final bool isMe;

  factory LeaderboardEntry.fromJson(Map<String, Object?> json) =>
      LeaderboardEntry(
        name: json['name'] as String? ?? '',
        fleetName: json['fleet_name'] as String?,
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        isMe: json['is_me'] as bool? ?? false,
      );
}

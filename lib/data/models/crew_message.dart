/// The single shared "cast a float bottle" crew message, visible to every
/// account. There is no thread — casting a new one replaces it, attributed
/// to the sender's real account name at the time it was cast.
class CrewMessage {
  const CrewMessage({
    required this.body,
    required this.authorName,
    required this.postedAt,
  });

  final String body;
  final String authorName;
  final DateTime postedAt;

  factory CrewMessage.fromJson(Map<String, Object?> json) => CrewMessage(
    body: json['body'] as String? ?? '',
    authorName: json['author_name'] as String? ?? '',
    postedAt:
        DateTime.tryParse(json['posted_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

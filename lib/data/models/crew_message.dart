/// One of the latest (up to 3) shared "cast a float bottle" crew messages,
/// visible to every account, attributed to the sender's real account name
/// at the time it was cast. Casting a new one bumps the others down a slot;
/// the oldest falls off past 3.
class CrewMessage {
  const CrewMessage({
    required this.id,
    required this.body,
    required this.authorName,
    required this.postedAt,
    required this.flaggedByMe,
  });

  final int id;
  final String body;
  final String authorName;
  final DateTime postedAt;

  /// Whether the signed-in account has already flagged this message — the
  /// flag button disables once true rather than offering a no-op retap.
  final bool flaggedByMe;

  factory CrewMessage.fromJson(Map<String, Object?> json) => CrewMessage(
    id: (json['id'] as num?)?.toInt() ?? 0,
    body: json['body'] as String? ?? '',
    authorName: json['author_name'] as String? ?? '',
    postedAt:
        DateTime.tryParse(json['posted_at'] as String? ?? '') ??
        DateTime.now(),
    flaggedByMe: json['flagged_by_me'] as bool? ?? false,
  );
}

/// The `GET /crew/message` response: the latest messages plus the caller's
/// own casting-suspension status (set only while a suspension is active).
class CrewMessagesPage {
  const CrewMessagesPage({required this.messages, this.mySuspendedUntil});

  final List<CrewMessage> messages;
  final DateTime? mySuspendedUntil;

  factory CrewMessagesPage.fromJson(Map<String, Object?> json) {
    final rows = (json['messages'] as List).cast<Map<String, Object?>>();
    return CrewMessagesPage(
      messages: rows.map(CrewMessage.fromJson).toList(),
      mySuspendedUntil: DateTime.tryParse(
        json['my_suspended_until'] as String? ?? '',
      ),
    );
  }
}

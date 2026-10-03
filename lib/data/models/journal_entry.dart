/// A single "Captain's Private Log" journal entry stored on-device.
class JournalEntry {
  const JournalEntry({
    this.id,
    required this.body,
    this.prompt,
    required this.createdAt,
  });

  final int? id;

  /// The sailor's written log text.
  final String body;

  /// The daily seaprompt shown when the entry was written, if any.
  final String? prompt;

  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'body': body,
    'prompt': prompt,
    'created_at': createdAt.toIso8601String(),
  };

  factory JournalEntry.fromMap(Map<String, Object?> map) => JournalEntry(
    id: map['id'] as int?,
    body: map['body'] as String? ?? '',
    prompt: map['prompt'] as String?,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

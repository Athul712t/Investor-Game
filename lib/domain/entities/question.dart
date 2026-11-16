enum QuestionType {
  mcq,
  trueFalse,
  mythFact,
  match,
  order,
  numeric,
  scenario,
  redFlag,
}

/// One question. [payload] is type-specific JSON so new types need no migration.
class Question {
  const Question({
    required this.id,
    required this.type,
    required this.topic,
    required this.difficulty,
    required this.explanation,
    required this.payload,
    this.version = 1,
  });

  final String id;
  final QuestionType type;
  final String topic;
  final int difficulty; // 1..5
  final String explanation; // shown after every answer
  final Map<String, Object?> payload;
  final int version;

  factory Question.fromJson(String id, Map<String, Object?> json) => Question(
    id: id,
    type: QuestionType.values.byName(json['type']! as String),
    topic: json['topic']! as String,
    difficulty: (json['difficulty'] ?? 1) as int,
    explanation: json['explanation']! as String,
    payload: Map<String, Object?>.from(json['payload']! as Map),
    version: (json['version'] ?? 1) as int,
  );
}

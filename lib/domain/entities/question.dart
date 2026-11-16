enum QuestionType { mcq, trueFalse, mythFact, match, scenario }

/// One question. [payload] is type-specific:
/// - mcq:       {prompt, options: [String], correctIndex}
/// - trueFalse: {statement, answer: bool}
/// - mythFact:  {statement, answer: "myth" | "fact"}
/// - match:     {prompt, pairs: [{left, right}]}
/// - scenario:  {prompt, options: [{text, outcome}], correctIndex}
class Question {
  const Question({
    required this.id,
    required this.type,
    required this.topic,
    required this.difficulty,
    required this.explanation,
    required this.payload,
  });

  final String id;
  final QuestionType type;
  final String topic;
  final int difficulty; // 1..5
  final String explanation; // shown after every answer
  final Map<String, Object?> payload;

  /// Fast to answer, so safe to show in the middle of a game.
  bool get isQuick => type == QuestionType.mcq || type == QuestionType.trueFalse || type == QuestionType.mythFact;

  factory Question.fromJson(Map<String, Object?> json) => Question(
    id: json['id']! as String,
    type: QuestionType.values.byName(json['type']! as String),
    topic: (json['topic'] ?? '') as String,
    difficulty: (json['difficulty'] ?? 1) as int,
    explanation: json['explanation']! as String,
    payload: Map<String, Object?>.from(json['payload']! as Map),
  );
}

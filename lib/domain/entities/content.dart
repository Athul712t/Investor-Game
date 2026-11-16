import 'question.dart';

class LessonCard {
  const LessonCard({required this.emoji, required this.title, required this.body});
  final String emoji, title, body;

  factory LessonCard.fromJson(Map<String, Object?> j) =>
      LessonCard(emoji: (j['emoji'] ?? '💡') as String, title: j['title']! as String, body: j['body']! as String);
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.minutes,
    required this.cards,
    required this.questions,
  });
  final String id, title;
  final int minutes;
  final List<LessonCard> cards;
  final List<Question> questions;

  factory Lesson.fromJson(Map<String, Object?> j) => Lesson(
    id: j['id']! as String,
    title: j['title']! as String,
    minutes: (j['minutes'] ?? 2) as int,
    cards: [for (final c in j['cards']! as List) LessonCard.fromJson(Map<String, Object?>.from(c as Map))],
    questions: [for (final q in j['questions']! as List) Question.fromJson(Map<String, Object?>.from(q as Map))],
  );
}

class Module {
  const Module({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.lessons,
  });
  final String id, title, subtitle, emoji, color;
  final List<Lesson> lessons;

  factory Module.fromJson(Map<String, Object?> j) => Module(
    id: j['id']! as String,
    title: j['title']! as String,
    subtitle: (j['subtitle'] ?? '') as String,
    emoji: (j['emoji'] ?? '📘') as String,
    color: (j['color'] ?? 'mint') as String,
    lessons: [for (final l in j['lessons']! as List) Lesson.fromJson(Map<String, Object?>.from(l as Map))],
  );
}

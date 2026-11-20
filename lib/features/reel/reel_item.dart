import '../../domain/entities/content.dart';
import '../../domain/entities/question.dart';

/// One card of the reel. The next card is never shown ahead of time.
sealed class ReelItem {
  const ReelItem();

  /// Stable per card, used as the widget key. Repeats get a different id.
  String get id;
}

/// A game. [serial] makes two plays of the same game different cards.
class ReelGame extends ReelItem {
  const ReelGame(this.gameId, this.serial);
  final String gameId;
  final int serial;

  @override
  String get id => 'game:$gameId#$serial';
}

class ReelQuestion extends ReelItem {
  const ReelQuestion(this.question, this.lessonId, {this.retry = false});
  final Question question;
  final String lessonId;

  /// True when it comes back after a wrong answer.
  final bool retry;

  @override
  String get id => 'q:${question.id}${retry ? '~' : ''}';
}

/// A quick read: one lesson card on its own.
class ReelRead extends ReelItem {
  const ReelRead(this.card, this.lessonId, this.index);
  final LessonCard card;
  final String lessonId;
  final int index;

  @override
  String get id => 'r:$lessonId:$index';
}

/// Where the learning sequence resumes. Questions and reads follow the lessons in order.
class ReelCursor {
  const ReelCursor({this.lesson = 0, this.step = 0, this.retry = const []});

  /// Index into the flat list of all lessons (module order, then lesson order).
  final int lesson;

  /// Index into that lesson's script: its reads first, then its questions.
  final int step;

  /// Ids of questions answered wrong, waiting to come back.
  final List<String> retry;

  Map<String, Object?> toJson() => {'lesson': lesson, 'step': step, 'retry': retry};

  factory ReelCursor.fromJson(Map<String, Object?> j) => ReelCursor(
    lesson: (j['lesson'] ?? 0) as int,
    step: (j['step'] ?? 0) as int,
    retry: [...?(j['retry'] as List?)?.cast<String>()],
  );
}

/// Called once by a card when the player may scroll on. [correct] is false only for a
/// question answered wrong (it is queued to come back later).
typedef ReelDone = void Function({required bool correct});

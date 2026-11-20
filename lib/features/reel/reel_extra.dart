import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/content.dart';
import '../../domain/entities/question.dart';

/// Extra reads and questions used only by the reel (assets/content/reel_extra.json).
///
/// Schema:
/// {"reads":[{"lesson":"mf-basics-1","emoji":"💡","title":"...","body":"..."}],
///  "questions":[{"lesson":"mf-basics-1","id":"mf-basics-1-x1","type":"trueFalse","topic":"mf-basics",
///                "difficulty":1,"explanation":"...","payload":{...}}]}
/// Question payloads are the same as in modules.json (see lib/domain/entities/question.dart).
class ReelExtra {
  const ReelExtra({this.reads = const {}, this.questions = const {}});

  /// Lesson id -> extra reads.
  final Map<String, List<LessonCard>> reads;

  /// Lesson id -> extra questions.
  final Map<String, List<Question>> questions;

  factory ReelExtra.fromJson(String source) {
    final j = jsonDecode(source) as Map;
    final reads = <String, List<LessonCard>>{};
    for (final r in (j['reads'] as List? ?? const [])) {
      final m = Map<String, Object?>.from(r as Map);
      reads.putIfAbsent(m['lesson']! as String, () => []).add(LessonCard.fromJson(m));
    }
    final questions = <String, List<Question>>{};
    for (final q in (j['questions'] as List? ?? const [])) {
      final m = Map<String, Object?>.from(q as Map);
      questions.putIfAbsent(m['lesson']! as String, () => []).add(Question.fromJson(m));
    }
    return ReelExtra(reads: reads, questions: questions);
  }
}

final reelExtraProvider = FutureProvider<ReelExtra>((ref) async {
  try {
    return ReelExtra.fromJson(await rootBundle.loadString('assets/content/reel_extra.json'));
  } catch (_) {
    return const ReelExtra(); // extra content is optional
  }
});

import '../../domain/entities/question.dart';

/// Source of questions (Firestore in prod, in-memory in tests).
abstract class QuestionSource {
  Future<List<Question>> fetch({
    required String topic,
    required int difficulty,
    int limit = 10,
  });
}

/// Games ask for "a question on topic X at difficulty Y"; they never need to
/// know how a given question type is rendered or scored.
class QuestionEngine {
  QuestionEngine(this._source);
  final QuestionSource _source;
  final _seen = <String>{};

  Future<Question?> next({
    required String topic,
    required int difficulty,
  }) async {
    final pool = await _source.fetch(topic: topic, difficulty: difficulty);
    for (final q in pool) {
      if (_seen.add(q.id)) return q;
    }
    _seen.clear(); // pool exhausted: allow repeats
    return pool.isEmpty ? null : pool.first;
  }

  /// Pure scoring for simple types; richer types add cases here.
  bool isCorrect(Question q, Object? answer) {
    switch (q.type) {
      case QuestionType.mcq:
      case QuestionType.scenario:
        return answer == q.payload['correctIndex'];
      case QuestionType.trueFalse:
      case QuestionType.mythFact:
        return answer == q.payload['answer'];
      default:
        return answer == q.payload['answer'];
    }
  }
}

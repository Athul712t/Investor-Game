import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/features/content/question_engine.dart';

class _Fake implements QuestionSource {
  @override
  Future<List<Question>> fetch({
    required String topic,
    required int difficulty,
    int limit = 10,
  }) async => [
    Question.fromJson('q1', {
      'type': 'mcq',
      'topic': topic,
      'difficulty': difficulty,
      'explanation': 'x',
      'payload': {'correctIndex': 2},
    }),
  ];
}

void main() {
  test('scores mcq and avoids immediate repeats', () async {
    final e = QuestionEngine(_Fake());
    final q = (await e.next(topic: 'sip', difficulty: 1))!;
    expect(e.isCorrect(q, 2), isTrue);
    expect(e.isCorrect(q, 1), isFalse);
  });
}

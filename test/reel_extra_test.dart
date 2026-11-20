import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/features/reel/reel_extra.dart';

void main() {
  final extra = ReelExtra.fromJson(File('assets/content/reel_extra.json').readAsStringSync());
  final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());

  final lessonIds = {
    for (final m in ['mf-basics', 'fund-types', 'sip-power'])
      for (var i = 1; i <= 4; i++) '$m-$i',
  };
  final moduleIds = {'mf-basics', 'fund-types', 'sip-power'};

  test('exactly 12 lessons, each with 8 reads and 8 questions', () {
    expect(extra.reads.keys.toSet(), lessonIds);
    expect(extra.questions.keys.toSet(), lessonIds);
    for (final id in lessonIds) {
      expect(extra.reads[id], hasLength(8), reason: '$id reads');
      expect(extra.questions[id], hasLength(8), reason: '$id questions');
    }
  });

  test('each lesson has 3 trueFalse, 2 mythFact, 2 mcq and 1 scenario', () {
    for (final id in lessonIds) {
      final types = [for (final q in extra.questions[id]!) q.type];
      expect(types.where((t) => t == QuestionType.trueFalse), hasLength(3), reason: id);
      expect(types.where((t) => t == QuestionType.mythFact), hasLength(2), reason: id);
      expect(types.where((t) => t == QuestionType.mcq), hasLength(2), reason: id);
      expect(types.where((t) => t == QuestionType.scenario), hasLength(1), reason: id);
    }
  });

  test('reads have short titles and bodies', () {
    for (final cards in extra.reads.values) {
      for (final c in cards) {
        expect(c.title.length, lessThanOrEqualTo(40), reason: c.title);
        expect(c.body.length, lessThanOrEqualTo(200), reason: c.title);
        expect(c.body.trim(), isNotEmpty, reason: c.title);
      }
    }
  });

  test('question ids are unique and do not collide with modules.json', () {
    final existing = {
      for (final l in content.lessons)
        for (final q in l.questions) q.id,
    };
    final seen = <String>{};
    for (final entry in extra.questions.entries) {
      for (final q in entry.value) {
        expect(seen.add(q.id), isTrue, reason: 'duplicate ${q.id}');
        expect(existing, isNot(contains(q.id)), reason: 'collides with modules.json: ${q.id}');
        expect(q.id, startsWith('${entry.key}-x'), reason: q.id);
        expect(moduleIds, contains(q.topic), reason: q.id);
        expect(q.difficulty, inInclusiveRange(1, 3), reason: q.id);
        expect(q.explanation.trim(), isNotEmpty, reason: q.id);
      }
    }
    expect(seen, hasLength(96));
  });

  test('every lesson id exists in modules.json', () {
    final realLessons = {for (final l in content.lessons) l.id};
    expect(realLessons, containsAll(lessonIds));
    for (final id in [...extra.reads.keys, ...extra.questions.keys]) {
      expect(realLessons, contains(id), reason: id);
    }
  });

  test('payloads are well formed for each question type', () {
    for (final entry in extra.questions.entries) {
      for (final q in entry.value) {
        final p = q.payload;
        switch (q.type) {
          case QuestionType.trueFalse:
            expect(p['statement'], isA<String>(), reason: q.id);
            expect(p['answer'], isA<bool>(), reason: q.id);
          case QuestionType.mythFact:
            expect(p['statement'], isA<String>(), reason: q.id);
            expect(p['answer'], anyOf(['myth', 'fact']), reason: q.id);
          case QuestionType.mcq:
            final options = p['options'] as List;
            expect(options, hasLength(3), reason: q.id);
            expect(options.every((o) => o is String), isTrue, reason: q.id);
            expect(p['correctIndex'], isA<int>(), reason: q.id);
            expect(p['correctIndex'] as int, inInclusiveRange(0, options.length - 1), reason: q.id);
          case QuestionType.scenario:
            final options = p['options'] as List;
            expect(options.length, greaterThanOrEqualTo(2), reason: q.id);
            for (final o in options) {
              final m = o as Map;
              expect(m['text'], isA<String>(), reason: q.id);
              expect(m['outcome'], isA<String>(), reason: q.id);
            }
            expect(p['correctIndex'], isA<int>(), reason: q.id);
            expect(p['correctIndex'] as int, inInclusiveRange(0, options.length - 1), reason: q.id);
          case QuestionType.match:
            fail('match is not used in reel_extra.json: ${q.id}');
        }
      }
    }
  });
}

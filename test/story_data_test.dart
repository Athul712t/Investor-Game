import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/features/story/story_data.dart';

void main() {
  final story = Story.fromJson(File('assets/content/story.json').readAsStringSync());
  final lessons = {
    for (final m in ['mf-basics', 'fund-types', 'sip-power'])
      for (var i = 1; i <= 4; i++) '$m-$i',
  };

  test('story.json parses into three chapters of 8 to 10 nodes', () {
    expect(story.chapters.map((c) => c.title), ['Salary Day', 'The Fund Zoo', 'The SIP Habit']);
    for (final c in story.chapters) {
      expect(c.nodes.length, inInclusiveRange(8, 10), reason: c.id);
    }
  });

  test('every node references valid content and every chapter ends with a reward', () {
    for (final c in story.chapters) {
      expect(c.nodes.last.type, NodeType.reward, reason: c.id);
      expect(c.nodes.where((n) => n.type == NodeType.scenario), hasLength(1), reason: c.id);
      for (final n in c.nodes) {
        switch (n.type) {
          case NodeType.lesson:
            expect(lessons, contains(n.lessonId), reason: n.title);
          case NodeType.game:
            expect(['runner', 'stack', 'merge'], contains(n.gameId), reason: n.title);
            expect(n.target, greaterThan(0));
          case NodeType.dialogue:
            expect(n.lines, isNotEmpty);
            for (final l in n.lines) {
              expect(Speaker.cast.keys, contains(l.speaker), reason: l.text);
            }
          case NodeType.scenario:
            final q = n.question!;
            expect(q.type, QuestionType.scenario);
            final options = q.payload['options']! as List;
            expect(q.payload['correctIndex'], inInclusiveRange(0, options.length - 1));
            for (final o in options) {
              expect((o as Map).keys, containsAll(['text', 'outcome']));
            }
          case NodeType.reward:
            expect(n.xp, greaterThan(0));
            expect(n.coins, greaterThan(0));
        }
      }
    }
  });

  test('a chapter unlocks only when every node of the previous one is done', () {
    final ch1 = story.chapters[0];
    final all = {for (var i = 0; i < ch1.nodes.length; i++) ch1.nodeId(i)};
    final missingOne = all.difference({ch1.nodeId(3)});
    expect(story.isUnlocked(0, {}), isTrue);
    expect(story.isUnlocked(1, {}), isFalse);
    expect(story.isUnlocked(1, missingOne), isFalse);
    expect(ch1.currentIndex(missingOne), 3);
    expect(story.isUnlocked(1, all), isTrue);
    expect(story.isUnlocked(2, all), isFalse);
    expect(ch1.currentIndex(all), ch1.nodes.length);
  });
}

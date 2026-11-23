import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = jsonDecode(File('assets/content/cards.json').readAsStringSync()) as Map<String, dynamic>;
  final cards = (data['cards'] as List).cast<Map<String, dynamic>>();
  final lessons = {
    for (final m in ['mf-basics', 'fund-types', 'sip-power'])
      for (var i = 1; i <= 4; i++) '$m-$i',
  };
  const tiers = {'common', 'rare', 'gold'};
  final idPattern = RegExp(r'^[a-z0-9-]+$');

  test('has 40 cards: 24 common, 12 rare, 4 gold', () {
    expect(cards, hasLength(40));
    final counts = <String, int>{};
    for (final c in cards) {
      counts.update(c['tier'] as String, (v) => v + 1, ifAbsent: () => 1);
    }
    expect(counts, {'common': 24, 'rare': 12, 'gold': 4});
  });

  test('ids and titles are unique, ids are well formed', () {
    final ids = cards.map((c) => c['id'] as String).toList();
    final titles = cards.map((c) => c['title'] as String).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate ids');
    expect(titles.toSet(), hasLength(titles.length), reason: 'duplicate titles');
    for (final id in ids) {
      expect(idPattern.hasMatch(id), isTrue, reason: id);
    }
  });

  test('every tier is valid', () {
    for (final c in cards) {
      expect(tiers, contains(c['tier']), reason: c['id'] as String);
    }
  });

  test('every lesson is one of the 12 and has at least 3 cards', () {
    final perLesson = <String, int>{for (final l in lessons) l: 0};
    for (final c in cards) {
      final lesson = c['lesson'] as String;
      expect(lessons, contains(lesson), reason: c['id'] as String);
      perLesson[lesson] = perLesson[lesson]! + 1;
    }
    for (final entry in perLesson.entries) {
      expect(entry.value, greaterThanOrEqualTo(3), reason: entry.key);
    }
  });

  test('titles are at most 18 characters, blurbs at most 70, emoji not empty', () {
    for (final c in cards) {
      final id = c['id'] as String;
      expect((c['title'] as String).length, lessThanOrEqualTo(18), reason: id);
      expect((c['blurb'] as String).length, lessThanOrEqualTo(70), reason: id);
      expect((c['emoji'] as String).trim(), isNotEmpty, reason: id);
    }
  });
}

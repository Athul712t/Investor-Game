import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/features/cards/cards_data.dart';
import 'package:investor_game/features/cards/cards_logic.dart';

CardDef card(String tier) => CardDef(id: 'x', title: 'X', emoji: '🏷️', lesson: 'L1', tier: tier, blurb: 'b');
Profile prof({bool done = true, int credits = 0}) =>
    Profile(completedLessons: done ? {'L1'} : {}, credits: {'L1': credits});

void main() {
  test('common unlocks with the lesson alone', () {
    expect(isUnlocked(card('common'), prof()), isTrue);
    expect(isUnlocked(card('common'), prof(done: false, credits: 99)), isFalse);
  });

  test('rare boundary 5/6', () {
    expect(isUnlocked(card('rare'), prof(credits: 5)), isFalse);
    expect(isUnlocked(card('rare'), prof(credits: 6)), isTrue);
  });

  test('gold boundary 14/15', () {
    expect(isUnlocked(card('gold'), prof(credits: 14)), isFalse);
    expect(isUnlocked(card('gold'), prof(credits: 15)), isTrue);
  });

  test('lesson not completed keeps every tier locked', () {
    for (final t in ['common', 'rare', 'gold']) {
      expect(isUnlocked(card(t), prof(done: false, credits: 50)), isFalse);
    }
  });

  test('progress fraction', () {
    expect(unlockProgress(card('common'), prof()), 1);
    expect(unlockProgress(card('common'), prof(done: false)), 0);
    expect(unlockProgress(card('rare'), prof(credits: 3)), 0.5);
    expect(unlockProgress(card('rare'), prof(credits: 60)), 1);
    expect(unlockProgress(card('gold'), prof(credits: 3)), closeTo(0.2, 1e-9));
  });

  test('hint text', () {
    expect(unlockHint(card('common'), prof(done: false), 'NAV and units'), 'Finish NAV and units');
    expect(unlockHint(card('rare'), prof(done: false, credits: 4), 'NAV and units'), 'Finish NAV and units');
    expect(
      unlockHint(card('rare'), prof(credits: 3), 'NAV and units'),
      'Needs 6 correct answers in NAV and units (3 of 6)',
    );
    expect(
      unlockHint(card('gold'), prof(credits: 9), 'NAV and units'),
      'Needs 15 correct answers in NAV and units (9 of 15)',
    );
  });

  test('loader: good file, bad entries skipped, bad file gives empty', () {
    final ok = parseCards(
      '{"cards":[{"id":"a","title":"A","emoji":"x","lesson":"L1","tier":"gold","blurb":"b"},{"id":1},"junk"]}',
    );
    expect(ok.map((c) => c.id), ['a']);
    expect(ok.single.needed, 15);
    expect(parseCards('not json'), isEmpty);
    expect(parseCards('{"cards":5}'), isEmpty);
    expect(parseCards(''), isEmpty);
  });
}

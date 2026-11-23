import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/progress.dart';
import 'package:investor_game/features/quests/quest_logic.dart';

const full = DayStats(games: 9, reelCards: 20, correct: 20, lessons: 2, bests: 1, gameIds: {'a', 'b', 'c'});

void main() {
  const day = '2026-05-04';

  test('same day gives the same quests, one per tier', () {
    final a = questsForDay(day), b = questsForDay(day);
    expect([for (final q in a) q.id], [for (final q in b) q.id]);
    expect([for (final q in a) q.tier], QuestTier.values);
  });

  test('different days vary', () {
    final sets = {
      for (var d = 1; d <= 28; d++) questsForDay('2026-05-${d.toString().padLeft(2, '0')}').map((q) => q.id).join(),
    };
    expect(sets.length, greaterThan(6));
  });

  test('progress is capped and completion follows the counters', () {
    final q = questById('m-diff3')!;
    const s = DayStats(gameIds: {'a', 'b'});
    expect((q.progress(s), q.isComplete(s)), (2, false));
    final s2 = s.copyWith(gameIds: {'a', 'b', 'c', 'd'});
    expect((q.progress(s2), q.isComplete(s2)), (3, true));
    expect(questById('h-best1')!.isComplete(const DayStats(bests: 1)), true);
    expect(questById('e-reel5')!.progress(const DayStats(reelCards: 9)), 5);
  });

  test('rewards per tier', () {
    expect([for (final q in questsForDay(day)) (q.coins, q.xp)], [(15, 10), (25, 15), (40, 25)]);
  });

  test('claim pays once and only when complete', () {
    final state = freshQuests(day);
    final id = (state['ids'] as List).first as String;
    expect(claimQuest(state, id, const DayStats(), day), isNull);
    final c = claimQuest(state, id, full, day)!;
    expect(claimedOf(c.state), [id]);
    expect(c.chest, false);
    expect(claimQuest(c.state, id, full, day), isNull);
  });

  test('chest only after all three, and only once', () {
    var state = freshQuests(day);
    final ids = (state['ids'] as List).cast<String>();
    final chests = <bool>[];
    for (final id in ids) {
      final c = claimQuest(state, id, full, day)!;
      chests.add(c.chest);
      state = c.state;
    }
    expect(chests, [false, false, true]);
    expect(state['chestGiven'], true);
    expect(claimQuest(state, ids.first, full, day), isNull);
  });

  test('rollover regenerates and keeps nothing stale', () {
    final old = {
      ...freshQuests('2026-05-03'),
      'claimed': ['x'],
      'chestGiven': true,
    };
    expect(rolledQuests(old, day), freshQuests(day));
    expect(rolledQuests(const {}, day), freshQuests(day));
    final today = freshQuests(day);
    expect(identical(rolledQuests(today, day), today), true);
    // A claim on a stale state rolls first, then pays against today's quests.
    final id = (freshQuests(day)['ids'] as List).first as String;
    final c = claimQuest(old, id, full, day)!;
    expect(c.state['day'], day);
    expect(claimedOf(c.state), [id]);
    expect(c.state['chestGiven'], false);
  });

  test('resetsIn counts to midnight', () {
    expect(resetsIn(DateTime(2026, 5, 4, 18, 30)), '5h');
    expect(resetsIn(DateTime(2026, 5, 4, 23, 30)), '30m');
  });
}

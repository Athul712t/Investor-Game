import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/progress.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question q(String id) => Question.fromJson({
  'id': id,
  'type': 'trueFalse',
  'topic': 'mf-basics',
  'explanation': 'x',
  'payload': {'statement': 's', 'answer': true},
});

Future<ProviderContainer> container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
}

void main() {
  test('lesson id comes from the question id', () {
    expect(lessonIdOfQuestion('mf-basics-1-q2'), 'mf-basics-1');
    expect(lessonIdOfQuestion('sip-power-3-x7'), 'sip-power-3');
    expect(lessonIdOfQuestion('weird'), '');
  });

  test('day stats reset on a new day', () {
    final saved = const DayStats(day: '2026-01-01', games: 3, correct: 2).toJson();
    expect(DayStats.of(saved, '2026-01-01').games, 3);
    expect(DayStats.of(saved, '2026-01-02').games, 0);
    expect(DayStats.of(saved, '2026-01-02').day, '2026-01-02');
  });

  test('a correct answer counts and credits its lesson; a wrong one queues a review for tomorrow', () async {
    final c = await container();
    final n = c.read(profileProvider.notifier);
    final at = DateTime(2026, 3, 10, 9);
    n.noteAnswer(q('mf-basics-1-q1'), true, now: at);
    n.noteAnswer(q('mf-basics-1-q2'), false, now: at);
    var p = c.read(profileProvider);
    final s = p.statsFor('2026-03-10');
    expect((s.correct, s.wrong), (1, 1));
    expect(p.credits, {'mf-basics-1': 1});
    expect(p.review, [
      {'id': 'mf-basics-1-q2', 'due': '2026-03-11', 'step': 0},
    ]);
    // Wrong again: one entry, reset to step 0, due tomorrow from the new answer.
    n.mutate(
      (p) => p.copyWith(
        review: [
          {'id': 'mf-basics-1-q2', 'due': '2026-03-11', 'step': 2},
        ],
      ),
    );
    n.noteAnswer(q('mf-basics-1-q2'), false, now: DateTime(2026, 3, 12));
    p = c.read(profileProvider);
    expect(p.review, [
      {'id': 'mf-basics-1-q2', 'due': '2026-03-13', 'step': 0},
    ]);
    // The review session manages its own queue.
    n.noteAnswer(q('sip-power-1-q1'), false, fromReview: true, now: DateTime(2026, 3, 12));
    expect(c.read(profileProvider).review.length, 1);
    expect(c.read(profileProvider).statsFor('2026-03-12').reviews, 1);
  });

  test('games, lessons, reel cards and bests are counted for the day', () async {
    final c = await container();
    final n = c.read(profileProvider.notifier);
    n.recordGame(const GameResult(gameId: 'runner', score: 50, durationMs: 1));
    n.recordGame(const GameResult(gameId: 'runner', score: 10, durationMs: 1));
    n.recordGame(const GameResult(gameId: 'merge', score: 5, durationMs: 1));
    n.completeLesson('mf-basics-1');
    n.noteReelCard();
    final s = c.read(profileProvider).statsFor(dayKey(DateTime.now()));
    expect(s.games, 3);
    expect(s.bests, 2); // first runner run and first merge run; the 10 did not beat 50
    expect(s.gameIds, {'runner', 'merge'});
    expect(s.lessons, 1);
    expect(s.reelCards, 1);
    expect(c.read(profileProvider).hours.reduce((a, b) => a + b), greaterThan(0));
  });

  test('chests can be granted and mutate saves', () async {
    final c = await container();
    final n = c.read(profileProvider.notifier);
    n.grantChest('wood');
    n.grantChest('gold');
    n.mutate((p) => p.copyWith(streakFreezes: 1));
    expect(c.read(profileProvider).chests, ['wood', 'gold']);
    expect(c.read(profileProvider).streakFreezes, 1);
  });

  test('every loop field survives save and load', () async {
    final c = await container();
    final n = c.read(profileProvider.notifier);
    n.mutate(
      (p) => p.copyWith(
        dayStats: const DayStats(day: '2026-03-10', games: 2, gameIds: {'runner'}).toJson(),
        quests: {
          'day': '2026-03-10',
          'ids': ['a', 'b', 'c'],
          'claimed': ['a'],
          'chestGiven': false,
        },
        chests: ['wood', 'silver'],
        streakFreezes: 1,
        lostStreak: 6,
        lostDay: '2026-03-09',
        milestonesDone: {3, 7},
        review: [
          {'id': 'x-q1', 'due': '2026-03-11', 'step': 1},
        ],
        credits: {'mf-basics-1': 4},
        masteryClaimed: {'runner:1'},
        headStarts: 2,
        owned: {'freeze', 'tree'},
        townDecor: {'tree'},
        pawn: 'red',
        notify: true,
        playHours: List.generate(24, (i) => i),
      ),
    );
    final saved = c.read(profileProvider).toJson();
    final c2 = ProviderContainer(overrides: [prefsProvider.overrideWithValue(c.read(prefsProvider))]);
    expect(c2.read(profileProvider).toJson(), saved);
    final p = c2.read(profileProvider);
    expect(p.chests, ['wood', 'silver']);
    expect(p.milestonesDone, {3, 7});
    expect(p.review.single['step'], 1);
    expect(p.credits['mf-basics-1'], 4);
    expect(p.masteryClaimed, {'runner:1'});
    expect((p.headStarts, p.streakFreezes, p.lostStreak, p.lostDay), (2, 1, 6, '2026-03-09'));
    expect(p.owned, {'freeze', 'tree'});
    expect(p.townDecor, {'tree'});
    expect((p.pawn, p.notify), ('red', true));
    expect(p.hours[23], 23);
    expect(p.quests['ids'], ['a', 'b', 'c']);
  });
}

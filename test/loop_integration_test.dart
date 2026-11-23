import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/progress.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/cards/cards_data.dart';
import 'package:investor_game/features/cards/cards_logic.dart';
import 'package:investor_game/features/chests/chest_logic.dart';
import 'package:investor_game/features/content/question_view.dart';
import 'package:investor_game/features/games/_shared/arcade_game.dart';
import 'package:investor_game/features/games/_shared/game_run.dart';
import 'package:investor_game/features/games/arcade_screen.dart';
import 'package:investor_game/features/quests/quest_logic.dart';
import 'package:investor_game/features/quests/quests_card.dart';
import 'package:investor_game/features/reel/reel_extra.dart';
import 'package:investor_game/features/review/review_logic.dart';
import 'package:investor_game/features/review/review_screen.dart';
import 'package:investor_game/features/shop/shop_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the v1.5 loop pieces work together: answers, mastery, cards, quests, chests, streak, review, games, shop,
/// and that all of it survives a reload.

final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());
final cards = parseCards(File('assets/content/cards.json').readAsStringSync());

/// fund-types-4 has rare and gold cards in cards.json.
const lesson = 'fund-types-4';

Question q(String id) => Question(
  id: id,
  type: QuestionType.trueFalse,
  topic: '',
  difficulty: 1,
  explanation: '',
  payload: const {'statement': 's', 'answer': true},
);

Future<ProviderContainer> boot([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return container(await SharedPreferences.getInstance());
}

ProviderContainer container(SharedPreferences prefs) {
  final c = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      contentProvider.overrideWith((_) async => content),
      reelExtraProvider.overrideWith((_) async => const ReelExtra()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Set<String> tiersUnlocked(Profile p) => {
  for (final c in cards)
    if (c.lesson == lesson && isUnlocked(c, p)) c.tier,
};

Future<void> pumpScreen(WidgetTester tester, ProviderContainer c, Widget screen) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: buildTheme(), home: screen),
    ),
  );
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('a) mastery credits and cards', () {
    test('correct answers anywhere credit the lesson; rare at 6, gold at 15', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      me.completeLesson(lesson);
      expect(tiersUnlocked(c.read(profileProvider)), {'common'});
      // Lesson questions, reel extras, a wrong answer (no credit) and an id of another shape (no credit).
      for (var i = 0; i < 5; i++) {
        me.noteAnswer(q(i.isEven ? '$lesson-q$i' : '$lesson-x$i'), true);
      }
      me.noteAnswer(q('$lesson-q9'), false);
      me.noteAnswer(q('quick-1'), true);
      expect(c.read(profileProvider).credits[lesson], 5);
      expect(tiersUnlocked(c.read(profileProvider)), {'common'});
      me.noteAnswer(q('$lesson-q1'), true);
      expect(tiersUnlocked(c.read(profileProvider)), {'common', 'rare'});
      for (var i = 0; i < 8; i++) {
        me.noteAnswer(q('$lesson-x1'), true);
      }
      expect(tiersUnlocked(c.read(profileProvider)), {'common', 'rare'});
      me.noteAnswer(q('$lesson-q2'), true);
      expect(c.read(profileProvider).credits[lesson], 15);
      expect(tiersUnlocked(c.read(profileProvider)), {'common', 'rare', 'gold'});
    });

    test('credits before the lesson is finished unlock nothing until it is', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      for (var i = 0; i < 6; i++) {
        me.noteAnswer(q('$lesson-q1'), true);
      }
      expect(tiersUnlocked(c.read(profileProvider)), isEmpty);
      me.completeLesson(lesson);
      expect(tiersUnlocked(c.read(profileProvider)), {'common', 'rare'});
    });

    test('a chest study boost adds 3 credits and can unlock a rare card', () async {
      // The first seed whose wood roll is a study boost.
      final seed = List.generate(500, (i) => i).firstWhere(
        (s) => rollChest(ChestType.wood, Random(s), lessonIds: const [lesson]).kind == RewardKind.studyBoost,
      );
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      me.completeLesson(lesson);
      for (var i = 0; i < 4; i++) {
        me.noteAnswer(q('$lesson-q1'), true);
      }
      me.grantChest('wood');
      expect(tiersUnlocked(c.read(profileProvider)), {'common'});
      final r = openChest(me, ChestType.wood, Random(seed), lessonIds: const [lesson])!;
      expect((r.kind, r.lessonId), (RewardKind.studyBoost, lesson));
      final p = c.read(profileProvider);
      expect(p.credits[lesson], 7);
      expect(p.chests, isEmpty);
      expect(tiersUnlocked(p), {'common', 'rare'});
    });
  });

  group('b) quests and the silver chest', () {
    testWidgets('games, lessons, answers and reel cards drive quests; three claims give one silver chest', (
      tester,
    ) async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      final today = dayKey(DateTime.now());
      // Enough of everything to finish any quest in the pool.
      for (final (i, id) in ['runner', 'stack', 'merge', 'flap', 'slice'].indexed) {
        me.recordGame(GameResult(gameId: id, score: 10 + i, durationMs: 1000));
      }
      me.completeLesson('mf-basics-1');
      for (var i = 0; i < 8; i++) {
        me.noteAnswer(q('mf-basics-1-q1'), true);
      }
      for (var i = 0; i < 12; i++) {
        me.noteReelCard();
      }
      final stats = c.read(profileProvider).statsFor(today);
      expect(
        (stats.games, stats.gameIds.length, stats.bests, stats.lessons, stats.correct, stats.reelCards),
        (5, 5, 5, 1, 8, 12),
      );
      for (final quest in questsForDay(today)) {
        expect(quest.isComplete(stats), isTrue, reason: quest.id);
      }

      await pumpScreen(tester, c, const Scaffold(body: SingleChildScrollView(child: QuestsCard())));
      final before = c.read(profileProvider);
      final pay = questsForDay(today).fold(0, (a, quest) => a + quest.coins);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Claim').first);
        await settle(tester);
      }
      expect(find.text('Claim'), findsNothing);
      var p = c.read(profileProvider);
      expect(p.coins - before.coins, pay);
      expect(p.chests, ['silver']);
      expect(claimedOf(p.quests).length, 3);

      // Re-claiming through the logic pays nothing more.
      for (final quest in questsForDay(today)) {
        expect(claimQuest(p.quests, quest.id, p.statsFor(today), today), isNull);
      }

      // Opening applies exactly one reward and removes the chest.
      final coins = p.coins;
      final r = openChest(me, ChestType.silver, Random(1))!;
      p = c.read(profileProvider);
      expect(p.chests, isEmpty);
      if (r.kind == RewardKind.coins) expect(p.coins, coins + r.coins);
      expect(openChest(me, ChestType.silver, Random(1)), isNull);
      expect(c.read(profileProvider).coins, p.coins);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('c) streak', () {
    DateTime d(int day) => DateTime(2026, 3, day, 10);

    test('a missed day with a freeze keeps the streak and uses the freeze', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      me.touchStreak(d(1));
      me.touchStreak(d(2));
      me.mutate((p) => p.copyWith(streakFreezes: 1));
      me.touchStreak(d(4)); // missed the 3rd
      final p = c.read(profileProvider);
      expect((p.streak, p.streakFreezes, p.lostStreak), (3, 0, 0));
    });

    test('without a freeze it breaks, offers a repair, and the repair restores it', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      for (var day = 1; day <= 4; day++) {
        me.touchStreak(d(day));
      }
      me.touchStreak(d(6));
      var p = c.read(profileProvider);
      expect((p.streak, p.lostStreak, p.lostDay), (1, 4, '2026-03-06'));
      expect(me.repairStreak(d(7)), isTrue);
      p = c.read(profileProvider);
      expect((p.streak, p.lostStreak, p.lostDay, p.lastActiveDay), (5, 0, '', '2026-03-07'));
      expect(me.repairStreak(d(7)), isFalse);
    });

    test('day 3 and day 7 each grant their chest once, also after a break', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      for (var day = 1; day <= 7; day++) {
        me.touchStreak(d(day));
        me.touchStreak(d(day)); // a second activity the same day changes nothing
      }
      var p = c.read(profileProvider);
      expect(p.streak, 7);
      expect(p.chests, ['wood', 'silver']);
      expect(p.milestonesDone, {3, 7});
      // Break, then climb back to 7: nothing new.
      for (var day = 10; day <= 16; day++) {
        me.touchStreak(d(day));
      }
      p = c.read(profileProvider);
      expect(p.streak, 7);
      expect(p.chests, ['wood', 'silver']);
    });
  });

  group('d) spaced review', () {
    test('a wrong answer is queued for tomorrow and a 3-step schedule graduates it', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      final day0 = DateTime(2026, 3, 7, 21);
      me.noteAnswer(q('mf-basics-1-q2'), false, now: day0);
      final review = c.read(profileProvider).review;
      expect(review, [
        {'id': 'mf-basics-1-q2', 'due': '2026-03-08', 'step': 0},
      ]);
      final ids = {'mf-basics-1-q2'};
      expect(dueSession(review, ids, '2026-03-07'), isEmpty);
      expect(dueSession(review, ids, '2026-03-08').length, 1);
      // The same question wrong again does not add a duplicate.
      me.noteAnswer(q('mf-basics-1-q2'), false, now: day0);
      expect(c.read(profileProvider).review.length, 1);

      var r = applyAnswer(review, 'mf-basics-1-q2', true, '2026-03-08');
      expect(r.single['step'], 1);
      expect(r.single['due'], '2026-03-11');
      r = applyAnswer(r, 'mf-basics-1-q2', true, '2026-03-11');
      expect((r.single['step'], r.single['due']), (2, '2026-03-18'));
      r = applyAnswer(r, 'mf-basics-1-q2', true, '2026-03-18');
      expect(r, isEmpty);
    });

    testWidgets('a session pays, credits mastery and advances the entry', (tester) async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      const id = 'mf-basics-1-q2';
      me.noteAnswer(q(id), false, now: DateTime.now().subtract(const Duration(days: 1)));
      final p0 = c.read(profileProvider);
      expect(p0.review.single['due'], dayKey(DateTime.now()));
      await pumpScreen(tester, c, const ReviewScreen());
      await tester.tap(find.text('Start review'));
      await settle(tester);
      final question = content.lessons.expand((l) => l.questions).firstWhere((x) => x.id == id);
      await tester.tap(find.text(question.payload['answer']! as bool ? 'True' : 'False'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
      final p = c.read(profileProvider);
      expect(p.xp - p0.xp, 5 + 10);
      expect(p.coins - p0.coins, 1);
      expect(p.credits['mf-basics-1'], 1);
      expect(p.review.single['step'], 1);
      expect(p.statsFor(dayKey(DateTime.now())).reviews, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('e) game mastery and economy', () {
    Future<ProviderContainer> pumpRun(WidgetTester tester, String id, String profile) async {
      final c = await boot({'profile_v1': profile});
      await pumpScreen(tester, c, Scaffold(body: GameRun(gameId: id)));
      return c;
    }

    ArcadeGame game(WidgetTester tester) =>
        tester.widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget)).game! as ArcadeGame;

    Future<void> endRun(WidgetTester tester, int score, {int coins = 0}) async {
      await tester.tap(find.text('Start'));
      await settle(tester);
      game(tester)
        ..score.value = score
        ..coins.value = coins;
      await tester.tap(find.bySemanticsLabel('Pause'));
      await settle(tester);
      await tester.tap(find.text('End run'));
      await settle(tester);
    }

    final pick = todaysPick(DateTime.now()).id;
    final plain = pick == 'merge' ? 'stack' : 'merge';
    final plainLevels = {'merge': (2100, 25 + 50), 'stack': (30, 25 + 50)}[plain]!;

    testWidgets('a run crossing two levels pays coins and chests once', (tester) async {
      final c = await pumpRun(tester, plain, '{"name":"A"}');
      await endRun(tester, plainLevels.$1);
      var p = c.read(profileProvider);
      expect(p.coins, plainLevels.$2);
      expect(p.chests, ['wood', 'silver']);
      await tester.tap(find.text('Play again'));
      await settle(tester);
      await endRun(tester, plainLevels.$1);
      p = c.read(profileProvider);
      expect(p.coins, plainLevels.$2);
      expect(p.chests, ['wood', 'silver']);
      expect(p.statsFor(dayKey(DateTime.now())).games, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets("today's pick doubles the run's coins", (tester) async {
      final c = await pumpRun(tester, pick, '{"name":"A","masteryClaimed":["$pick:1","$pick:2","$pick:3"]}');
      await endRun(tester, 1, coins: 6);
      expect(c.read(profileProvider).coins, 12);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('head-start tokens decrement and a second chance is still one game', (tester) async {
      final c = await pumpRun(tester, plain, '{"name":"A","headStarts":2}');
      await tester.tap(find.text('Head start (2 left)'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3)); // power-up toast
      expect(c.read(profileProvider).headStarts, 1);
      game(tester).score.value = 3;
      game(tester).onGameOver!();
      await settle(tester);
      await tester.ensureVisible(find.text('Answer and continue'));
      await tester.tap(find.text('Answer and continue'));
      await settle(tester);
      tester.widget<QuestionView>(find.byType(QuestionView)).onAnswered(false); // wrong: the run ends again
      await settle(tester);
      final stats = c.read(profileProvider).statsFor(dayKey(DateTime.now()));
      expect((stats.games, stats.bests), (1, 1));
      expect(c.read(profileProvider).headStarts, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('f) shop', () {
    test('buy and equip a decoration; never negative; never bought twice', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      me.mutate((p) => p.copyWith(coins: 100));
      final tree = shopItem('tree')!;
      expect(buyItem(me, tree), isTrue);
      expect(buyItem(me, tree), isFalse); // a double tap
      var p = c.read(profileProvider);
      expect(p.coins, 20);
      expect(p.owned, {'tree'});
      me.mutate((p) => toggleDecor(p, 'tree'));
      expect(c.read(profileProvider).townDecor, {'tree'});
      expect(equippedDecor(c.read(profileProvider)), {'tree'});
      expect(buyItem(me, shopItem('lamp')!), isFalse); // 20 < 100
      me.mutate((p) => toggleDecor(p, 'lamp')); // not owned: no change
      p = c.read(profileProvider);
      expect(p.coins, 20);
      expect(p.townDecor, {'tree'});
      expect(me.spend(21), isFalse);
      expect(c.read(profileProvider).coins, 20);
      me.mutate((p) => toggleDecor(p, 'tree'));
      expect(c.read(profileProvider).townDecor, isEmpty);
    });

    test('a freeze is held at most once, head starts stack', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      me.mutate((p) => p.copyWith(coins: 300));
      expect(buyItem(me, shopItem('freeze')!), isTrue);
      expect(buyItem(me, shopItem('freeze')!), isFalse);
      expect(buyItem(me, shopItem('headstart3')!), isTrue);
      expect(buyItem(me, shopItem('headstart3')!), isTrue);
      final p = c.read(profileProvider);
      expect((p.coins, p.streakFreezes, p.headStarts), (300 - 60 - 140, 1, 6));
    });
  });

  group('g) save and reload', () {
    test('a fresh container over the same prefs restores the whole loop state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = container(prefs);
      final me = a.read(profileProvider.notifier);
      me.completeLesson(lesson);
      me.noteAnswer(q('$lesson-q1'), true);
      me.noteAnswer(q('$lesson-q2'), false);
      me.noteReelCard();
      me.recordGame(const GameResult(gameId: 'runner', score: 900, durationMs: 1));
      me.grantChest('gold');
      me.touchStreak(DateTime(2026, 3, 1));
      me.mutate(
        (p) => p.copyWith(
          coins: 500,
          headStarts: 2,
          streakFreezes: 1,
          masteryClaimed: {'runner:1'},
          quests: freshQuests('2026-03-01'),
          milestonesDone: {3},
          lostStreak: 4,
          lostDay: '2026-03-01',
          pawn: 'pawn_red',
        ),
      );
      buyItem(me, shopItem('tree')!);
      me.mutate((p) => toggleDecor(p, 'tree'));
      final saved = a.read(profileProvider);

      final b = container(prefs);
      final loaded = b.read(profileProvider);
      expect(jsonEncode(loaded.toJson()), jsonEncode(saved.toJson()));
      expect(loaded.townDecor, {'tree'});
      expect(loaded.review.single['id'], '$lesson-q2');
      expect(tiersUnlocked(loaded), {'common'});
    });
  });

  group('limits', () {
    test('the review queue is capped and keeps the newest wrong answer', () async {
      final c = await boot();
      final me = c.read(profileProvider.notifier);
      final start = DateTime(2026, 1, 1, 12);
      for (var i = 0; i < reviewCap + 50; i++) {
        me.noteAnswer(q('mf-basics-1-q$i'), false, now: start.add(Duration(days: i ~/ 10)));
      }
      final review = c.read(profileProvider).review;
      expect(review.length, reviewCap);
      expect(review.last['id'], 'mf-basics-1-q${reviewCap + 49}');
      expect(review.first['id'], 'mf-basics-1-q0'); // the oldest due stay
    });

    test('a worst-case profile stays far below the 50000 byte cloud limit', () {
      final lessons = [for (final l in content.lessons) l.id];
      final p = Profile(
        name: 'W' * 20,
        xp: 999999,
        coins: 999999,
        streak: 999,
        completedLessons: {...lessons},
        highScores: {
          for (final g in ['runner', 'stack', 'merge', 'breaker', 'flap', 'slice']) g: 999999,
        },
        storyDone: {for (var i = 0; i < 200; i++) 'chapter-name-$i/$i'},
        dayStats: DayStats(day: '2026-01-01', gameIds: {for (var i = 0; i < 11; i++) 'game$i'}).toJson(),
        quests: freshQuests('2026-01-01'),
        chests: List.filled(50, 'silver'),
        milestonesDone: {3, 7, 14, 30},
        review: [
          for (var i = 0; i < reviewCap; i++) {'id': 'fund-types-4-x$i', 'due': '2026-01-01', 'step': 2},
        ],
        credits: {for (final l in lessons) l: 9999},
        masteryClaimed: {
          for (var i = 0; i < 11; i++) ...{'game$i:1', 'game$i:2', 'game$i:3'},
        },
        owned: {for (final i in shopItems) i.id},
        townDecor: {for (final i in itemsOf(ShopKind.decor)) i.id},
        playHours: List.filled(24, 99999),
        reelCursor: {'module': 2, 'lesson': 3, 'step': 40},
      );
      final size = utf8.encode(jsonEncode(p.toJson())).length;
      expect(size, lessThan(25000), reason: '$size bytes');
    });
  });
}

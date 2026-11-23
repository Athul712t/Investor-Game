import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/progress.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/quests/quest_logic.dart';
import 'package:investor_game/features/quests/quests_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const all = DayStats(games: 9, reelCards: 20, correct: 20, lessons: 2, bests: 1, gameIds: {'a', 'b', 'c'});

Future<ProviderContainer> pump(
  WidgetTester tester,
  DayStats stats, {
  Map<String, Object?>? quests,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  final today = dayKey(DateTime.now());
  container
      .read(profileProvider.notifier)
      .mutate(
        (p) => p.copyWith(
          dayStats: DayStats(
            day: today,
            games: stats.games,
            lessons: stats.lessons,
            correct: stats.correct,
            bests: stats.bests,
            reelCards: stats.reelCards,
            gameIds: stats.gameIds,
          ).toJson(),
          quests: quests ?? freshQuests(today),
        ),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: EdgeInsets.all(16), child: QuestsCard()),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

void main() {
  testWidgets('rows show progress from the day counters', (tester) async {
    final qs = questsForDay(dayKey(DateTime.now()));
    await pump(tester, const DayStats(games: 1, correct: 1));
    expect(find.text('Daily quests'), findsOneWidget);
    expect(find.text('0 of 3 done'), findsOneWidget);
    for (final q in qs) {
      expect(find.text(q.text), findsOneWidget);
    }
    expect(find.text('Claim'), findsNothing);
    expect(find.text('Finish all 3 for a silver chest'), findsOneWidget);
  });

  testWidgets('claim pays coins and XP, flips to done, and the third grants one silver chest', (tester) async {
    final c = await pump(tester, all);
    final before = c.read(profileProvider);
    expect(find.text('Claim'), findsNWidgets(3));
    await tester.tap(find.text('Claim').first);
    await tester.pump();
    var p = c.read(profileProvider);
    final q0 = questsForDay(dayKey(DateTime.now())).first;
    expect((p.coins - before.coins, p.xp - before.xp), (q0.coins, q0.xp));
    expect(find.text('Claim'), findsNWidgets(2));
    expect(p.chests, isEmpty);
    await tester.tap(find.text('Claim').first);
    await tester.pump();
    await tester.tap(find.text('Claim').first);
    await tester.pump();
    p = c.read(profileProvider);
    expect(p.chests, ['silver']);
    expect(p.coins - before.coins, 15 + 25 + 40);
    expect(find.text('Claim'), findsNothing);
    expect(find.text('3 of 3 done'), findsOneWidget);
    expect(find.text('Silver chest earned'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(c.read(profileProvider).chests, ['silver']);
  });

  testWidgets('a stale day rolls over after the frame and keeps nothing', (tester) async {
    final stale = {
      ...freshQuests('2020-01-01'),
      'claimed': ['x'],
      'chestGiven': true,
    };
    final c = await pump(tester, const DayStats(), quests: stale);
    final q = c.read(profileProvider).quests;
    expect(q['day'], dayKey(DateTime.now()));
    expect(q['claimed'], isEmpty);
    expect(q['chestGiven'], false);
  });

  testWidgets('360x640 at text scale 1.3 renders without overflow', (tester) async {
    await pump(tester, all, scale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Claim'), findsNWidgets(3));
    expect(tester.getSize(find.byType(QuestsCard)).height, greaterThan(250));
  });
}

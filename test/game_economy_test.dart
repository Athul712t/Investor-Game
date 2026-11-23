import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/games/_shared/arcade_game.dart';
import 'package:investor_game/features/games/_shared/game_run.dart';
import 'package:investor_game/features/games/arcade_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Today's pick, and a game that is not.
final pickId = todaysPick(DateTime.now()).id;
final plainId = pickId == 'merge' ? 'stack' : 'merge';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<ProviderContainer> pump(WidgetTester tester, String id, String profile, {bool reel = false}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'profile_v1': profile});
  final prefs = await SharedPreferences.getInstance();
  final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());
  final container = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs), contentProvider.overrideWith((_) async => content)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: GameRun(gameId: id, reel: reel),
        ),
      ),
    ),
  );
  await settle(tester);
  return container;
}

/// Starts, sets the score and coins, and ends the run through the pause card.
Future<void> finish(WidgetTester tester, int score, {int coins = 0}) async {
  await tester.tap(find.text('Start'));
  await settle(tester);
  final game = tester.widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget)).game! as ArcadeGame;
  game.score.value = score;
  game.coins.value = coins;
  await tester.tap(find.bySemanticsLabel('Pause'));
  await settle(tester);
  await tester.tap(find.text('End run'));
  await settle(tester);
}

void main() {
  testWidgets('results: medal line for the highest level just reached and the next-level line', (tester) async {
    final c = await pump(tester, 'merge', '{"name":"A"}');
    await finish(tester, 2100);
    expect(find.text('Silver reached! +50 coins and a silver chest'), findsOneWidget);
    expect(find.text('Next: Gold at 6000, 3900 to go'), findsOneWidget);
    expect(c.read(profileProvider).masteryClaimed, {'merge:1', 'merge:2'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('results: near-miss line below the best', (tester) async {
    await pump(tester, 'merge', '{"name":"A","highScores":{"merge":100},"masteryClaimed":["merge:1"]}');
    await finish(tester, 88);
    expect(find.text('12 away from your best'), findsOneWidget);
    expect(find.text('Next: Silver at 2000, 1912 to go'), findsOneWidget);
    expect(find.textContaining('reached!'), findsNothing);
  });

  testWidgets('results: no near-miss far below the best; Gold mastered when all claimed', (tester) async {
    await pump(
      tester,
      'merge',
      '{"name":"A","highScores":{"merge":100},"masteryClaimed":["merge:1","merge:2","merge:3"]}',
    );
    await finish(tester, 40);
    expect(find.textContaining('away from your best'), findsNothing);
    expect(find.text('Gold mastered'), findsOneWidget);
  });

  testWidgets("today's pick: 2x pill and doubled coins recorded; other games pay normally", (tester) async {
    var c = await pump(tester, pickId, '{"name":"A"}');
    expect(find.text('2x coins today'), findsOneWidget);
    await finish(tester, 0, coins: 7);
    expect(c.read(profileProvider).coins, 14);
    expect(find.text('+14 (2x)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    c = await pump(tester, plainId, '{"name":"A"}');
    expect(find.text('2x coins today'), findsNothing);
    await finish(tester, 0, coins: 7);
    expect(c.read(profileProvider).coins, 7);
  });

  testWidgets('reel: the pick pays double too', (tester) async {
    final c = await pump(tester, pickId, '{"name":"A"}', reel: true);
    expect(find.text('2x coins today'), findsOneWidget);
    await finish(tester, 0, coins: 5);
    expect(c.read(profileProvider).coins, 10);
  });

  testWidgets('head-start token is used for free and never goes below zero', (tester) async {
    final c = await pump(tester, plainId, '{"name":"A","headStarts":1,"coins":100}');
    expect(find.text('Head start (1 left)'), findsOneWidget);
    expect(find.textContaining('30 coins'), findsNothing);
    await tester.tap(find.text('Head start (1 left)'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 3)); // power-up toast timer
    final p = c.read(profileProvider);
    expect(p.headStarts, 0);
    expect(p.coins, 100);
  });

  testWidgets('paid head start still works without tokens', (tester) async {
    final c = await pump(tester, plainId, '{"name":"A","coins":100}');
    expect(find.textContaining('Head start ('), findsNothing);
    await tester.tap(find.text('Head start  ·  30 coins'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(c.read(profileProvider).coins, 70);
    expect(c.read(profileProvider).headStarts, 0);
  });
}

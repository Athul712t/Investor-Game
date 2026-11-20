import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/_shared/arcade_game.dart';
import 'package:investor_game/features/games/_shared/game_run.dart';
import 'package:shared_preferences/shared_preferences.dart';

final gameWidget = find.byWidgetPredicate((w) => w is GameWidget);
ArcadeGame gameOf(WidgetTester t) => t.widget<GameWidget>(gameWidget).game! as ArcadeGame;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200)); // the game loop never settles
  }
}

/// Pumps [child] with a profile whose merge best is 50 and real content (so a second chance would be possible).
Future<ProviderContainer> pumpReel(WidgetTester tester, Widget Function(bool active) child) async {
  SharedPreferences.setMockInitialValues({'profile_v1': '{"name":"A","highScores":{"merge":50}}'});
  final prefs = await SharedPreferences.getInstance();
  final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());
  final container = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs), contentProvider.overrideWith((_) async => content)],
  );
  addTearDown(container.dispose);
  var active = false;
  late StateSetter set;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, s) {
              set = s;
              return child(active);
            },
          ),
        ),
      ),
    ),
  );
  await settle(tester);
  // Inactive: a static intro, no engine, Start does nothing.
  expect(gameWidget, findsNothing);
  expect(find.text('Best 50'), findsOneWidget);
  await tester.tap(find.text('Start'));
  await settle(tester);
  expect(gameWidget, findsNothing);

  set(() => active = true);
  await settle(tester);
  expect(gameWidget, findsNothing, reason: 'the engine is built on Start, not on activation');
  await tester.tap(find.text('Start'));
  await settle(tester);
  expect(gameWidget, findsOneWidget);
  expect(find.text('Best 50'), findsWidgets, reason: 'HUD shows the best under the score');
  return container;
}

void expectReelResults() {
  expect(find.text('Best 50'), findsOneWidget);
  expect(find.text('Swipe up for the next card'), findsOneWidget);
  expect(find.text('Answer and continue'), findsNothing);
  expect(find.text('Play again'), findsNothing);
  expect(find.text('Done'), findsNothing);
  expect(find.text('Back'), findsNothing);
}

void main() {
  testWidgets('reel run: End run goes straight to results with best, once', (tester) async {
    final results = <GameResult>[];
    await pumpReel(tester, (a) => GameRun(gameId: 'merge', reel: true, active: a, onFinished: results.add));
    final game = gameOf(tester);
    await tester.tap(find.bySemanticsLabel('Pause'));
    await settle(tester);
    await tester.tap(find.text('End run'));
    await settle(tester);
    expect(find.text('Run over'), findsOneWidget);
    expectReelResults();
    expect(results, hasLength(1));
    expect(results.single.gameId, 'merge');

    // Leaving the reel card stops the engine.
    await tester.pumpWidget(const SizedBox());
    expect(game.paused, isTrue);
  });

  testWidgets('reel run: game over offers no second chance', (tester) async {
    var finished = 0;
    await pumpReel(tester, (a) => GameRun(gameId: 'merge', reel: true, active: a, onFinished: (_) => finished++));
    gameOf(tester).gameOver();
    await settle(tester);
    expectReelResults();
    expect(finished, 1);
  });
}

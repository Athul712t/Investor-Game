import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/cards/album_screen.dart';
import 'package:investor_game/features/cards/cards_data.dart';
import 'package:investor_game/features/chests/chests_screen.dart';
import 'package:investor_game/features/content/lesson_screen.dart';
import 'package:investor_game/features/games/_shared/game_host.dart';
import 'package:investor_game/features/home_hub/shell.dart';
import 'package:investor_game/features/review/review_screen.dart';
import 'package:investor_game/features/shop/shop_screen.dart';
import 'package:investor_game/features/story/chapter_screen.dart';
import 'package:investor_game/features/story/dialogue_scene.dart';
import 'package:investor_game/features/story/node_screens.dart';
import 'package:investor_game/features/story/reward_scene.dart';
import 'package:investor_game/features/story/story_data.dart';
import 'package:investor_game/features/story/story_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smallest supported phone, largest supported text scale, longest name: nothing may overflow.
void main() {
  final story = Story.fromJson(File('assets/content/story.json').readAsStringSync());
  final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());
  final cards = parseCards(File('assets/content/cards.json').readAsStringSync());
  final ch = story.chapters.first;
  StoryNode first(NodeType t) => ch.nodes.firstWhere((n) => n.type == t);

  Future<void> pumpAt(WidgetTester tester, Widget screen, {int tab = 0}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      // Busy v1.5 state too: chests, a due review, an open streak repair, owned decor.
      'profile_v1':
          '{"name":"WWWWWWWWWWWWWWWWWWWW","xp":250,"coins":99999,"streak":365,"storyDone":["salary-day/0"],'
          '"chests":["wood","silver","gold"],"headStarts":3,"owned":["tree","lamp"],"townDecor":["tree"],'
          '"completedLessons":["mf-basics-1"],"credits":{"mf-basics-1":20},'
          '"review":[{"id":"mf-basics-1-q2","due":"2000-01-01","step":0}],'
          '"lostStreak":40,"lostDay":"${dayKey(DateTime.now())}"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        contentProvider.overrideWith((_) async => content),
        storyProvider.overrideWith((_) async => story),
        cardsProvider.overrideWith((_) async => cards),
      ],
    );
    addTearDown(container.dispose);
    container.read(tabProvider.notifier).go(tab);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    // Looping animations never settle.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(CircularProgressIndicator), findsNothing); // content really loaded
  }

  for (var tab = 0; tab < 4; tab++) {
    testWidgets('shell tab $tab', (tester) => pumpAt(tester, const Shell(), tab: tab));
  }
  testWidgets('story map', (tester) => pumpAt(tester, const StoryMapScreen()));
  testWidgets('chapter', (tester) => pumpAt(tester, ChapterScreen(story: story, index: 0)));
  testWidgets('dialogue', (tester) => pumpAt(tester, DialogueScene(node: first(NodeType.dialogue), chapter: ch)));
  testWidgets('game node', (tester) => pumpAt(tester, GameNodeScreen(node: first(NodeType.game), color: ch.color)));
  testWidgets('scenario', (tester) => pumpAt(tester, ScenarioScreen(node: first(NodeType.scenario), color: ch.color)));
  testWidgets(
    'reward',
    (tester) => pumpAt(
      tester,
      RewardScene(node: first(NodeType.reward), chapter: ch, number: 1, next: story.chapters[1], firstTime: true),
    ),
  );
  testWidgets('lesson', (tester) => pumpAt(tester, const LessonScreen(lessonId: 'mf-basics-4')));
  testWidgets('chests', (tester) => pumpAt(tester, const ChestsScreen()));
  testWidgets('chest opening', (tester) async {
    await pumpAt(tester, ChestsScreen(rng: Random(2)));
    await tester.tap(find.byKey(const Key('open-gold')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  });
  testWidgets('album', (tester) => pumpAt(tester, const AlbumScreen()));
  testWidgets('review', (tester) => pumpAt(tester, const ReviewScreen()));
  testWidgets('review session', (tester) async {
    await pumpAt(tester, const ReviewScreen());
    await tester.tap(find.text('Start review'));
    await tester.pump(const Duration(milliseconds: 500));
  });
  testWidgets('shop', (tester) => pumpAt(tester, const ShopScreen()));
  for (final id in ['runner', 'stack', 'merge']) {
    testWidgets('game intro $id', (tester) => pumpAt(tester, GameHostScreen(gameId: id, targetScore: 150)));
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/core/widgets.dart';
import 'package:investor_game/features/streak/streak_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Six quick questions: the first option ("Right answer") is always the correct one.
Content _content() => Content.fromJson(
  jsonEncode({
    'modules': [
      {
        'id': 'm',
        'title': 'M',
        'lessons': [
          {
            'id': 'mf-basics-1',
            'title': 'L',
            'cards': <Object>[],
            'questions': [
              for (var i = 1; i <= 6; i++)
                {
                  'id': 'mf-basics-1-q$i',
                  'type': 'mcq',
                  'explanation': 'Because.',
                  'payload': {
                    'prompt': 'Question $i?',
                    'options': ['Right answer', 'Wrong answer'],
                    'correctIndex': 0,
                  },
                },
            ],
          },
        ],
      },
    ],
  }),
);

void main() {
  final today = dayKey(DateTime.now());

  Future<ProviderContainer> pump(WidgetTester tester, Map<String, Object> seed, {bool small = false}) async {
    if (small) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(seed)});
    final c = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
        contentProvider.overrideWith((_) async => _content()),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(small ? 1.3 : 1)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(padding: EdgeInsets.all(16), child: StreakCard()),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    return c;
  }

  ChunkyButton buyButton(WidgetTester t) =>
      t.widget<ChunkyButton>(find.widgetWithText(ChunkyButton, 'Buy a freeze (60 coins)'));

  testWidgets('shows the streak and the next milestone', (tester) async {
    await pump(tester, {
      'streak': 4,
      'lastActiveDay': today,
      'milestonesDone': [3],
    });
    expect(find.text('day streak'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Next reward at 7 days: silver chest'), findsOneWidget);
    expect(find.textContaining('Streak lost'), findsNothing);
  });

  testWidgets('buying a freeze spends 60 coins and holds one', (tester) async {
    final c = await pump(tester, {'streak': 1, 'coins': 100, 'lastActiveDay': today});
    expect(find.text('No freeze'), findsOneWidget);
    await tester.tap(find.text('Buy a freeze (60 coins)'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.read(profileProvider).coins, 40);
    expect(c.read(profileProvider).streakFreezes, 1);
    expect(find.text('Freeze ready'), findsOneWidget);
    expect(buyButton(tester).onPressed, isNull); // one at a time
  });

  testWidgets('buy is disabled when poor', (tester) async {
    final c = await pump(tester, {'streak': 1, 'coins': 59, 'lastActiveDay': today});
    expect(buyButton(tester).onPressed, isNull);
    await tester.tap(find.text('Buy a freeze (60 coins)'));
    await tester.pump();
    expect(c.read(profileProvider).coins, 59);
    expect(c.read(profileProvider).streakFreezes, 0);
  });

  testWidgets('repair sheet needs 3 correct answers, wrong ones give a new question', (tester) async {
    final c = await pump(tester, {
      'streak': 1,
      'lastActiveDay': today,
      'lostStreak': 6,
      'lostDay': today,
      'milestonesDone': [3],
    });
    expect(find.text('Streak lost: repair it'), findsOneWidget);
    await tester.tap(find.text('Repair'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    Future<void> answer(String option) async {
      await tester.tap(find.text(option));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    await answer('Wrong answer');
    await answer('Right answer');
    await answer('Right answer');
    expect(c.read(profileProvider).streak, 1); // two right so far
    expect(c.read(profileProvider).lostStreak, 6);
    await answer('Right answer');
    expect(find.text('Streak restored!'), findsOneWidget);
    expect(c.read(profileProvider).streak, 7);
    expect(c.read(profileProvider).lostStreak, 0);
    expect(c.read(profileProvider).chests, ['silver']); // 7 reached for the first time
    expect(c.read(profileProvider).dayStats, isNotEmpty); // answers were noted
    await tester.tap(find.text('Keep going'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Streak lost: repair it'), findsNothing);
  });

  testWidgets('layout at 360x640, text scale 1.3, repair open', (tester) async {
    await pump(tester, {
      'streak': 12,
      'coins': 5,
      'lastActiveDay': today,
      'lostStreak': 9,
      'lostDay': today,
    }, small: true);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Repair'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull);
  });
}

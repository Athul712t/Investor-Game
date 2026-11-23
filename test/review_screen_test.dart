import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/reel/reel_extra.dart';
import 'package:investor_game/features/review/review_screen.dart';
import 'package:investor_game/features/review/review_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());

/// True/false questions from modules.json: id to (statement, answer).
const _tf = ['mf-basics-1-q2', 'mf-basics-2-q2', 'mf-basics-4-q2'];

Future<ProviderContainer> pump(
  WidgetTester tester,
  Widget screen,
  List<Map<String, Object?>> review, {
  double scale = 1,
  bool small = false,
}) async {
  if (small) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      contentProvider.overrideWith((_) async => _content),
      reelExtraProvider.overrideWith((_) async => const ReelExtra()),
    ],
  );
  addTearDown(container.dispose);
  container.read(profileProvider.notifier).mutate((p) => p.copyWith(review: review));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  // Looping animations never settle, so pump a fixed time.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return container;
}

Map<String, Object?> due(String id, [int step = 0]) => {'id': id, 'due': '2000-01-01', 'step': step};

Future<void> settle(WidgetTester tester) => tester.pump(const Duration(milliseconds: 500));

void main() {
  testWidgets('intro shows the due count and what is coming', (tester) async {
    final tomorrow = dayKey(DateTime.now().add(const Duration(days: 1)));
    await pump(tester, const ReviewScreen(), [
      due('mf-basics-1-q2'),
      due('mf-basics-2-q2'),
      due('gone-q1'),
      {'id': 'mf-basics-4-q2', 'due': tomorrow, 'step': 0},
    ]);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('due now'), findsOneWidget);
    expect(find.text('Tomorrow  1'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('start is disabled with a friendly message when nothing is due', (tester) async {
    await pump(tester, const ReviewScreen(), [due('gone-q1')]);
    expect(find.textContaining('All caught up'), findsOneWidget);
    await tester.tap(find.text('Start review'));
    await settle(tester);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Review done'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a session updates the queue, pays XP and coins and shows the summary', (tester) async {
    final c = await pump(tester, const ReviewScreen(), [
      due('mf-basics-1-q2', 2), // right answer graduates
      due('mf-basics-2-q2'), // wrong answer resets
      due('mf-basics-4-q2'), // right answer moves to step 1
    ]);
    final p0 = c.read(profileProvider);
    await tester.tap(find.text('Start review'));
    await settle(tester);
    for (final right in [true, false, true]) {
      final q = _tf
          .map((id) => _content.lessons.expand((l) => l.questions).firstWhere((q) => q.id == id))
          .firstWhere((q) => find.text(q.payload['statement']! as String).evaluate().isNotEmpty);
      final answer = q.payload['answer']! as bool;
      await tester.tap(find.text((right ? answer : !answer) ? 'True' : 'False'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
    }
    await settle(tester);
    final p = c.read(profileProvider);
    expect(p.xp - p0.xp, 2 * 5 + 10);
    expect(p.coins - p0.coins, 2);
    expect(p.review.where((r) => r['id'] == 'mf-basics-1-q2'), isEmpty);
    final tomorrow = dayKey(DateTime.now().add(const Duration(days: 1)));
    final wrong = p.review.singleWhere((r) => r['id'] == 'mf-basics-2-q2');
    expect((wrong['step'], wrong['due']), (0, tomorrow));
    final moved = p.review.singleWhere((r) => r['id'] == 'mf-basics-4-q2');
    expect(moved['step'], 1);
    expect(find.text('Review done'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('learned for good'), findsOneWidget);
    expect(find.text('Next review: tomorrow'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('screen at 360x640, text scale 1.3, does not overflow', (tester) async {
    await pump(tester, const ReviewScreen(), [due('mf-basics-1-q2')], scale: 1.3, small: true);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Start review'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tile says how many are due and fits at 360x640, scale 1.3', (tester) async {
    await pump(
      tester,
      const Scaffold(
        body: Row(
          children: [
            Expanded(child: ReviewTile()),
            Spacer(),
          ],
        ),
      ),
      [due('mf-basics-1-q2'), due('mf-basics-2-q2')],
      scale: 1.3,
      small: true,
    );
    expect(find.text('2 due'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

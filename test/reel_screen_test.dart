import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/domain/entities/content.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/features/reel/cards/question_card.dart';
import 'package:investor_game/features/reel/cards/read_card.dart';
import 'package:investor_game/features/reel/reel_chrome.dart';
import 'package:investor_game/features/reel/reel_feed.dart';
import 'package:investor_game/features/reel/reel_item.dart';
import 'package:investor_game/features/reel/reel_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alternates question, read, question, read... and records what the screen tells it.
class FakeFeed implements ReelFeed {
  int served = 0;
  final wrong = <ReelQuestion>[];

  @override
  ReelItem next() {
    final n = served++;
    return n.isEven
        ? ReelQuestion(
            Question(
              id: 'q$n',
              type: QuestionType.trueFalse,
              topic: 't',
              difficulty: 1,
              explanation: 'e',
              payload: const {'statement': 'S', 'answer': true},
            ),
            'mf-basics-1',
          )
        : ReelRead(const LessonCard(emoji: '💡', title: 'T', body: 'B'), 'mf-basics-1', n);
  }

  @override
  ReelCursor get cursor => ReelCursor(step: served);

  @override
  void reportWrong(ReelQuestion q) => wrong.add(q);
}

/// Records saveReel calls (the screen's job is to make them; storing them is the profile's).
class RecordingProfile extends ProfileController {
  final cursors = <Map<String, Object?>>[];
  int best = 0;

  @override
  void saveReel({Map<String, Object?>? cursor, int? bestStreak}) {
    if (cursor != null) cursors.add(cursor);
    if (bestStreak != null) best = bestStreak;
    super.saveReel(cursor: cursor, bestStreak: bestStreak);
  }
}

void main() {
  late FakeFeed feed;
  late RecordingProfile profile;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {FutureOr<ReelFeed> Function(Ref)? provide, double textScale = 1}) async {
    feed = FakeFeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        profileProvider.overrideWith(() => profile = RecordingProfile()),
        reelFeedProvider.overrideWith(provide ?? (_) async => feed),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const ReelScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void finishQuestion(WidgetTester tester, {bool correct = true}) =>
      tester.widget<QuestionCard>(find.byType(QuestionCard)).onDone(correct: correct);

  Finder streak(int n) => find.byWidgetPredicate((w) => w is ReelPill && w.semantic == 'Reel streak' && w.value == n);

  Future<void> dragUp(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(0, -400));
    await settle(tester);
  }

  testWidgets('the page cannot move until the card is done, then moves forward only', (tester) async {
    await pump(tester);
    expect(find.byType(QuestionCard), findsOneWidget);
    expect(find.text('Finish this card to continue'), findsOneWidget);

    await dragUp(tester);
    expect(find.byType(QuestionCard), findsOneWidget);
    expect(find.byType(ReadCard), findsNothing);

    finishQuestion(tester);
    await settle(tester);
    expect(find.text('Swipe up'), findsOneWidget);
    // The next page exists but is a hidden "?", not the real card.
    expect(feed.served, 2);
    expect(find.byType(ReadCard), findsNothing);

    await dragUp(tester);
    expect(find.byType(ReadCard), findsOneWidget);
    expect(find.byType(QuestionCard), findsNothing);
    expect(find.text('Finish this card to continue'), findsOneWidget);

    // No going back, even once the read is done.
    tester.widget<ReadCard>(find.byType(ReadCard)).onDone(correct: true);
    await settle(tester);
    await tester.drag(find.byType(PageView), const Offset(0, 400));
    await settle(tester);
    expect(find.byType(ReadCard), findsOneWidget);
  });

  testWidgets('a small drag springs back; the swipe cue advances', (tester) async {
    await pump(tester);
    finishQuestion(tester);
    await settle(tester);
    await tester.drag(find.byType(PageView), const Offset(0, -60));
    await settle(tester);
    expect(find.byType(QuestionCard), findsOneWidget);

    await tester.tap(find.text('Swipe up'));
    await settle(tester);
    expect(find.byType(ReadCard), findsOneWidget);
  });

  testWidgets('screen readers get a "Next card" action once the card is done', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(find.bySemanticsLabel('Next card'), findsNothing);
    finishQuestion(tester);
    await settle(tester);
    tester.semantics.tap(find.semantics.byLabel('Next card'));
    await settle(tester);
    expect(find.byType(ReadCard), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the hidden next card builds no real card', (tester) async {
    await pump(tester);
    finishQuestion(tester);
    await settle(tester);
    await tester.drag(find.byType(PageView), const Offset(0, -200), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 16)); // mid-drag: both pages on screen
    expect(find.byType(HiddenCard), findsOneWidget);
    expect(find.byType(ReadCard), findsNothing);
  });

  testWidgets('a wrong answer is reported and resets the streak; the cursor is saved per card', (tester) async {
    await pump(tester);
    finishQuestion(tester);
    await settle(tester);
    // Saved before the hidden next card is drawn, so leaving replays it.
    expect(profile.cursors.single, {'lesson': 0, 'step': 1, 'retry': <String>[]});
    expect(streak(1), findsOneWidget);
    await dragUp(tester);
    tester.widget<ReadCard>(find.byType(ReadCard)).onDone(correct: true);
    await settle(tester);
    expect(streak(2), findsOneWidget);
    expect(profile.best, 2);
    await dragUp(tester);

    finishQuestion(tester, correct: false);
    await settle(tester);
    expect(feed.wrong.single.id, 'q:q2');
    expect(streak(0), findsOneWidget);
    expect(profile.best, 2);
    expect(profile.cursors.map((c) => c['step']), [1, 2, 3]);
  });

  testWidgets('fits the smallest phone at the largest text scale (layout_test pattern)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, textScale: 1.3);
    finishQuestion(tester);
    await settle(tester);
    await tester.drag(find.byType(PageView), const Offset(0, -150), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(HiddenCard), findsOneWidget);
    await settle(tester);
  });

  testWidgets('loading, then a friendly error with retry', (tester) async {
    final gate = Completer<ReelFeed>();
    await pump(tester, provide: (_) => gate.future);
    expect(find.text('Shuffling your reel...'), findsOneWidget);
    gate.completeError(Exception('offline'));
    await settle(tester);
    expect(find.text('The reel is taking a break'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

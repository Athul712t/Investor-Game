import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/games/_shared/arcade_game.dart';
import 'package:investor_game/features/games/_shared/game_run.dart';
import 'package:investor_game/features/home_hub/shell.dart';
import 'package:investor_game/features/profile/profile_screen.dart';
import 'package:investor_game/features/profile/reel_mix_slider.dart';
import 'package:investor_game/features/reel/reel_extra.dart';
import 'package:investor_game/features/reel/reel_feed.dart';
import 'package:investor_game/features/reel/reel_item.dart';
import 'package:investor_game/features/reel/reel_sequencer.dart';
import 'package:shared_preferences/shared_preferences.dart';

final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());

Future<ProviderContainer> pumpApp(WidgetTester tester, Widget home, {String profile = '{}', double scale = 1}) async {
  SharedPreferences.setMockInitialValues({'profile_v1': profile});
  final prefs = await SharedPreferences.getInstance();
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
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250)); // game loops and springs never settle on their own
  }
  return container;
}

void main() {
  final track = find.descendant(of: find.byType(ReelMixSlider), matching: find.byType(GestureDetector)).first;
  Offset notch(WidgetTester tester, int stop) {
    final r = tester.getRect(track);
    const inset = 17.0; // half the thumb width
    return Offset(r.left + inset + (r.width - 2 * inset) * stop / 4, r.center.dy);
  }

  int mix(ProviderContainer c) => c.read(profileProvider).reelMix;

  testWidgets('tapping each notch selects and saves that stop', (tester) async {
    final c = await pumpApp(tester, const Scaffold(body: Center(child: ReelMixSlider())));
    expect(find.text('Even mix'), findsOneWidget);
    for (final stop in [0, 1, 2, 3, 4, 1]) {
      await tester.tapAt(notch(tester, stop));
      await tester.pump(const Duration(milliseconds: 400));
      expect(mix(c), stop);
      expect(find.text(ReelMix.labels[stop]), findsOneWidget);
      expect(find.text(ReelMix.captions[stop]), findsOneWidget);
    }
    // Saved, not just shown: a fresh container reads it back.
    final c2 = ProviderContainer(overrides: [prefsProvider.overrideWithValue(c.read(prefsProvider))]);
    addTearDown(c2.dispose);
    expect(c2.read(profileProvider).reelMix, 1);
  });

  testWidgets('dragging snaps to the nearest stop; arrow keys step', (tester) async {
    final c = await pumpApp(tester, const Scaffold(body: Center(child: ReelMixSlider())));
    final from = notch(tester, 2), to = notch(tester, 4);
    // Release a little short of the end: it snaps to Learning only.
    final g = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(from, to - const Offset(6, 0), i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(mix(c), 4);
    expect(find.text('Learning only'), findsOneWidget);

    await tester.drag(track, Offset(notch(tester, 0).dx - to.dx - 40, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(mix(c), 0);

    Focus.of(tester.element(find.text('Games only'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 400));
    expect(mix(c), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 400));
    expect(mix(c), 1);
  });

  testWidgets('screen readers get a slider with value and increase/decrease', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await pumpApp(tester, const Scaffold(body: Center(child: ReelMixSlider())));
    final node = find.bySemanticsLabel('Reel mode');
    expect(
      tester.getSemantics(node),
      isSemantics(
        label: 'Reel mode',
        value: 'Even mix',
        increasedValue: 'Mostly learning',
        decreasedValue: 'Mostly games',
        isSlider: true,
        isFocusable: true,
        isFocused: false,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    tester.semantics.performAction(find.semantics.byLabel('Reel mode'), SemanticsAction.increase);
    await tester.pump(const Duration(milliseconds: 400));
    expect(mix(c), 3);
    tester.semantics.performAction(find.semantics.byLabel('Reel mode'), SemanticsAction.decrease);
    tester.semantics.performAction(find.semantics.byLabel('Reel mode'), SemanticsAction.decrease);
    await tester.pump(const Duration(milliseconds: 400));
    expect(mix(c), 1);
    expect(tester.getSize(track).height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('Profile tab fits 360x640 at text scale 1.3 with the Reel mode section above Sound', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, const Shell(), profile: '{"name":"WWWWWWWWWWWWWWWWWWWW"}', scale: 1.3);
    c.read(tabProvider.notifier).go(3);
    await tester.pump(const Duration(milliseconds: 500));
    final list = find.descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Sound'), 200, scrollable: list);
    await tester.pump(const Duration(milliseconds: 500));
    // Sound now sits above the Daily reminder row, so the scroll can end further down: only the order matters here.
    expect(
      tester.getTopLeft(find.text('Reel mode', skipOffstage: false)).dy,
      lessThan(tester.getTopLeft(find.byType(ReelMixSlider)).dy),
    );
    expect(tester.getTopLeft(find.byType(ReelMixSlider)).dy, lessThan(tester.getTopLeft(find.text('Sound')).dy));
    for (final stop in [0, 4]) {
      // Longest captions on both ends must not overflow either.
      c.read(profileProvider.notifier).saveReelMix(stop);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(ReelMix.captions[stop]), findsOneWidget);
    }
  });

  testWidgets('chips off: a boost shows no quiz chip', (tester) async {
    await pumpApp(tester, const Scaffold(body: GameRun(gameId: 'merge', reel: true, chips: false)));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 500));
    final game = tester.widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget)).game! as ArcadeGame;
    game.requestBoost();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Quick quiz for a power-up'), findsNothing);
    game.gameOver();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('What you learned this run'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('chips on (default): a boost shows the quiz chip', (tester) async {
    await pumpApp(tester, const Scaffold(body: GameRun(gameId: 'merge', reel: true)));
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 500));
    final game = tester.widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget)).game! as ArcadeGame;
    game.requestBoost();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Quick quiz for a power-up'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  test('the feed is rebuilt per visit with the current mix and resumes the saved cursor', () async {
    SharedPreferences.setMockInitialValues({'profile_v1': '{"reelMix":4}'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        contentProvider.overrideWith((_) async => content),
        reelExtraProvider.overrideWith((_) async => const ReelExtra()),
      ],
    );
    addTearDown(c.dispose);
    Future<ReelFeed> open() async {
      final sub = c.listen(reelFeedProvider.future, (_, _) {});
      final feed = await sub.read();
      sub.close();
      await Future<void>.delayed(Duration.zero); // let the auto-dispose run
      return feed;
    }

    final first = await open();
    final learned = [for (var i = 0; i < 3; i++) first.next()];
    expect(learned.whereType<ReelGame>(), isEmpty);
    c.read(profileProvider.notifier).saveReel(cursor: first.cursor.toJson());
    c.read(profileProvider.notifier).saveReelMix(2);

    final second = await open();
    expect(identical(first, second), isFalse);
    expect(second.next(), isA<ReelGame>()); // even mix starts with a game
    final resumed = [for (var i = 0; i < 6; i++) second.next()].where((i) => i is! ReelGame).first;
    // The resumed item is the one after the three already seen.
    String key(ReelItem i) => switch (i) {
      ReelRead(:final lessonId, :final index) => '$lessonId/$index',
      ReelQuestion(:final question) => question.id,
      ReelGame() => 'game',
    };
    final fresh = ReelSequencer(
      lessons: content.lessons,
      extra: const ReelExtra(),
      gameIds: const ['g'],
      rng: Random(1),
      gameShare: 0,
    );
    final order = [for (var i = 0; i < 4; i++) key(fresh.next())];
    expect(learned.map(key), order.take(3));
    expect(key(resumed), order[3]);
  });
}

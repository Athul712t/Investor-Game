import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/home_hub/home_screen.dart';
import 'package:investor_game/features/home_hub/shell.dart';
import 'package:investor_game/features/story/story_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shell keeps every tab alive; a hidden tab must not keep ticking (town, pulsing tiles, spinning coins).
void main() {
  final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());
  final story = Story.fromJson(File('assets/content/story.json').readAsStringSync());

  Future<ProviderContainer> pumpShell(WidgetTester tester) async {
    // Chests to open and a review due: the Home tiles pulse while Home is visible.
    SharedPreferences.setMockInitialValues({
      'profile_v1':
          '{"name":"A","coins":500,"chests":["wood"],"completedLessons":["mf-basics-1"],'
          '"review":[{"id":"mf-basics-1-q2","due":"2000-01-01","step":0}]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        contentProvider.overrideWith((_) async => content),
        storyProvider.overrideWith((_) async => story),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: buildTheme(), home: const Shell()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    return c;
  }

  testWidgets('Home ticks while shown and stops once another tab is selected', (tester) async {
    final c = await pumpShell(tester);
    expect(tester.hasRunningAnimations, isTrue); // the town and the pulsing tiles
    // Arcade has no looping animation of its own once its entrance is done.
    c.read(tabProvider.notifier).go(2);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(TickerMode.of(tester.element(find.byType(HomeScreen, skipOffstage: false))), isFalse);
    expect(tester.hasRunningAnimations, isFalse);
    c.read(tabProvider.notifier).go(0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}

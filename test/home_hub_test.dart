import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/sfx.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/games/_shared/games_registry.dart';
import 'package:investor_game/features/games/arcade_screen.dart';
import 'package:investor_game/features/home_hub/shell.dart';
import 'package:investor_game/features/home_hub/town.dart';
import 'package:investor_game/features/profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('town plan', () {
    test('no progress is an empty plot', () {
      final plan = TownPlan.of(const Profile());
      expect(plan.buildings, 0);
      expect(plan.description, contains('your town starts here'));
    });

    test('lessons and story steps add buildings; level sets the tallest', () {
      final plan = TownPlan.of(const Profile(xp: 250, completedLessons: {'a', 'b'}, storyDone: {'c/0', 'c/1', 'c/2'}));
      expect(plan.buildings, 3); // 2 lessons + 3 story steps ~/ 2
      expect(plan.tallest, 4); // level 3
      expect(plan.floors.first, plan.tallest);
      expect(plan.floors.skip(1).every((f) => f < plan.tallest), isTrue);
    });

    test('the town is capped at its 16 lots and 7 floors', () {
      final plan = TownPlan.of(Profile(xp: 5000, completedLessons: {for (var i = 0; i < 40; i++) 'l$i'}));
      expect(plan.buildings, TownPlan.lots.length);
      expect(plan.tallest, 7);
      expect(TownPlan.lots.toSet().length, 16);
    });
  });

  test("today's pick rotates daily over every game", () {
    final picks = {for (var d = 0; d < games.length; d++) todaysPick(DateTime(2026, 1, 1 + d)).id};
    expect(picks.length, games.length);
    expect(todaysPick(DateTime(2026, 3, 4, 1)), todaysPick(DateTime(2026, 3, 4, 23)));
  });

  testWidgets('bottom bar switches tabs, marks the selected tab, and Profile toggles sound', (tester) async {
    final handle = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());
    final container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs), contentProvider.overrideWith((_) async => content)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(), home: const Shell()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    bool selected(String label) =>
        tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData().hasFlag(SemanticsFlag.isSelected);
    expect(selected('Home'), isTrue);
    expect(selected('Play'), isFalse);

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(tabProvider), 2);
    expect(selected('Play'), isTrue);
    expect(find.text("TODAY'S PICK"), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(tabProvider), 3);
    final before = Sound.muted;
    await tester.dragUntilVisible(
      find.text('Sound'),
      find.descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable)),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Sound'));
    await tester.pump();
    expect(Sound.muted, !before);
    Sound.setMuted(before);
    handle.dispose();
  });
}

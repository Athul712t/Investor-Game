import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/games/_shared/games_registry.dart';
import 'package:investor_game/features/games/arcade_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('arcade tiles show medal pips for the claimed levels', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'profile_v1': '{"name":"A","highScores":{"stack":30},"masteryClaimed":["stack:1","stack:2","runner:1"]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: ArcadeScreen()),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    List<Color?> pips(String title) {
      final tile = find.ancestor(of: find.text(title), matching: find.byType(Column)).first;
      return tester
          .widgetList<MedalPip>(find.descendant(of: tile, matching: find.byType(MedalPip)))
          .map((p) => p.color)
          .toList();
    }

    expect(pips('Sky Stack'), [masteryColors[0], masteryColors[1], null]);
    expect(pips('Bull Run'), [masteryColors[0], null, null]);
    expect(pips('Coin Merge'), [null, null, null]);
  });
}

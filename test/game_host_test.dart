import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/_shared/game_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ending an empty run gives no XP, and system back still returns the run', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs), contentProvider.overrideWith((_) async => Content([]))],
    );
    addTearDown(container.dispose);
    GameResult? got;
    var returned = false;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                got = await Navigator.of(ctx).push<GameResult>(
                  MaterialPageRoute(builder: (_) => const GameHostScreen(gameId: 'merge', targetScore: 200)),
                );
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200)); // the game loop never settles
      }
    }

    await tester.tap(find.text('open'));
    await settle();
    await tester.tap(find.text('Start'));
    await settle();
    await tester.tap(find.byTooltip('Pause'));
    await settle();
    await tester.tap(find.text('End run'));
    await settle();
    expect(find.text('So close'), findsOneWidget);
    expect(container.read(profileProvider).xp, 0);

    await tester.binding.handlePopRoute();
    await settle();
    expect(returned, isTrue);
    expect(got?.gameId, 'merge');
  });
}

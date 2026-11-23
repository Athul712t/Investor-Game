import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/chests/chest_logic.dart';
import 'package:investor_game/features/chests/chests_screen.dart';
import 'package:investor_game/features/chests/chests_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());
  final lessonIds = [for (final l in content.lessons) l.id];

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Profile profile, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool reduce = false,
    Widget screen = const _Seeded(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'profile_v1': jsonEncode(profile.toJson())});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs), contentProvider.overrideWith((_) async => content)],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduce),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    return c;
  }

  const some = Profile(chests: ['wood', 'wood', 'silver']);

  testWidgets('lists counts and odds for every type', (tester) async {
    await pump(tester, some);
    expect(find.text('x2 to open'), findsOneWidget);
    expect(find.text('x1 to open'), findsOneWidget);
    expect(find.text('None yet'), findsOneWidget); // gold
    expect(find.byKey(const Key('open-wood')), findsOneWidget);
    expect(find.byKey(const Key('open-gold')), findsNothing);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('15 to 30 coins'), findsOneWidget);
    expect(find.text('40 to 80 coins'), findsOneWidget);
    expect(find.text('No chests yet', skipOffstage: false), findsNothing);
  });

  testWidgets('opening applies the seeded reward, removes one chest, and the reveal can be dismissed', (tester) async {
    final c = await pump(tester, some, screen: ChestsScreen(rng: Random(9)));
    final expected = applyChest(
      some,
      ChestType.wood,
      rollChest(ChestType.wood, Random(9), lessonIds: lessonIds, credits: const {}),
    );
    await tester.tap(find.byKey(const Key('open-wood')));
    await tester.pump();
    expect(c.read(profileProvider).chests, ['wood', 'silver']);
    expect(jsonEncode(c.read(profileProvider).toJson()), jsonEncode(expected.toJson()));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const Key('reveal-title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('awesome')));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('open-wood')), findsOneWidget);
    expect(find.text('x1 to open'), findsNWidgets(2));
  });

  testWidgets('a double tap opens only once', (tester) async {
    final c = await pump(
      tester,
      const Profile(chests: ['wood', 'wood', 'wood']),
      screen: ChestsScreen(rng: Random(2)),
    );
    final b = find.byKey(const Key('open-wood'));
    final at = tester.getCenter(b);
    await tester.tapAt(at);
    await tester.tapAt(at);
    await tester.pump();
    expect(c.read(profileProvider).chests.length, 2);
  });

  testWidgets('empty state explains how to earn chests', (tester) async {
    await pump(tester, const Profile());
    expect(find.textContaining('No chests yet'), findsOneWidget);
    expect(find.textContaining('daily quests'), findsOneWidget);
    expect(find.textContaining('streak milestone'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('reduced motion reveals the reward at once', (tester) async {
    await pump(tester, some, reduce: true, screen: ChestsScreen(rng: Random(4)));
    await tester.tap(find.byKey(const Key('open-silver')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('awesome')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50)); // lets PopIn's zero-delay timer fire
  });

  testWidgets('360x640 at text scale 1.3: list, opening and reveal do not overflow', (tester) async {
    await pump(
      tester,
      const Profile(chests: ['wood', 'silver', 'gold', 'gold']),
      size: const Size(360, 640),
      scale: 1.3,
      screen: ChestsScreen(rng: Random(11)),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-gold')), warnIfMissed: false);
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('home tile shows the count and a none state', (tester) async {
    await pump(
      tester,
      some,
      screen: const Scaffold(
        body: Center(child: SizedBox(width: 180, child: ChestsTile())),
      ),
    );
    expect(find.text('3 to open'), findsOneWidget);
    expect(find.text('Chests'), findsOneWidget);
    await pump(
      tester,
      const Profile(),
      screen: const Scaffold(
        body: Center(child: SizedBox(width: 180, child: ChestsTile())),
      ),
    );
    expect(find.text('None yet'), findsOneWidget);
  });
}

class _Seeded extends StatelessWidget {
  const _Seeded();
  @override
  Widget build(BuildContext context) => const ChestsScreen();
}

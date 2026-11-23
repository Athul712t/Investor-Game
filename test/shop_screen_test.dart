import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/home_hub/town.dart';
import 'package:investor_game/features/shop/shop_screen.dart';
import 'package:investor_game/features/shop/shop_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> pump(WidgetTester tester, Profile p, {Widget screen = const ShopScreen()}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  c.read(profileProvider.notifier).mutate((_) => p);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
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
  await tester.pump(const Duration(milliseconds: 100));
  return c;
}

Future<void> tapId(WidgetTester tester, String id) async {
  final f = find.byKey(ValueKey('btn_$id'));
  await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  await tester.pump();
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('sections, items and prices show; no overflow at 360x640 scale 1.3', (tester) async {
    await pump(tester, const Profile(coins: 150));
    expect(find.text('Boosts'), findsOneWidget);
    expect(find.text('Streak freeze'), findsOneWidget);
    expect(find.text('60'), findsWidgets);
    expect(find.text('70'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Ink pawn'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.scrollUntilVisible(find.text('Town'), 100, scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('Pawns'), 100, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buy flow: coins drop, item becomes Equip, then Equipped toggles', (tester) async {
    final c = await pump(tester, const Profile(coins: 100));
    await tapId(tester, 'tree');
    expect(c.read(profileProvider).coins, 20);
    expect(c.read(profileProvider).owned, contains('tree'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Owned'), findsOneWidget);
    await tapId(tester, 'tree');
    expect(c.read(profileProvider).townDecor, {'tree'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Equipped'), findsOneWidget);
    await tapId(tester, 'tree');
    expect(c.read(profileProvider).townDecor, isEmpty);
  });

  testWidgets('poor: buy is disabled, tapping shakes and says what is missing', (tester) async {
    final c = await pump(tester, const Profile(coins: 50));
    final btn = find.byKey(const ValueKey('btn_tree'));
    await tester.scrollUntilVisible(btn, 150, scrollable: find.byType(Scrollable).first);
    final sem = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Buy Oak tree, need 30 more coins')), findsOneWidget);
    sem.dispose();
    await tester.tap(btn, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(profileProvider).coins, 50);
    expect(c.read(profileProvider).owned, isEmpty);
    expect(find.text('Need 30 more coins'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('freeze shows Held and boosts apply', (tester) async {
    final c = await pump(tester, const Profile(coins: 300, streakFreezes: 1));
    expect(find.text('Held'), findsOneWidget);
    await tapId(tester, 'headstart3');
    expect(c.read(profileProvider).headStarts, 3);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('pawn equip', (tester) async {
    final c = await pump(tester, const Profile(owned: {'pawn_red', 'card:x'}));
    await tapId(tester, 'pawn_red');
    expect(c.read(profileProvider).pawn, 'pawn_red');
    await tapId(tester, 'pawn_red');
    expect(c.read(profileProvider).pawn, '');
  });

  testWidgets('shop tile and town with every decoration build', (tester) async {
    await pump(
      tester,
      const Profile(coins: 12, owned: {'tree', 'lamp', 'flag', 'fountain', 'windmill', 'statue'}),
      screen: Scaffold(
        body: ListView(
          children: [
            const ShopTile(),
            SizedBox(
              height: 240,
              child: PortfolioTown(
                plan: TownPlan.of(const Profile(completedLessons: {'a', 'b', 'c'})),
                decor: const {'tree', 'lamp', 'flag', 'fountain', 'windmill', 'statue'},
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Shop'), findsOneWidget);
    expect(find.byType(PortfolioTown), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

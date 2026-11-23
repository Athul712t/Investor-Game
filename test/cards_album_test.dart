import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/cards/album_screen.dart';
import 'package:investor_game/features/cards/album_tile.dart';
import 'package:investor_game/features/cards/cards_data.dart';
import 'package:investor_game/features/cards/cards_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fixture = [
  CardDef(id: 'nav', title: 'NAV', emoji: '🏷️', lesson: 'mf-basics-3', tier: 'common', blurb: 'Price of one unit.'),
  CardDef(id: 'units', title: 'Units', emoji: '🧮', lesson: 'mf-basics-3', tier: 'rare', blurb: 'Your share count.'),
  CardDef(
    id: 'sip',
    title: 'SIP',
    emoji: '🔁',
    lesson: 'sip-power-1',
    tier: 'common',
    blurb: 'A fixed amount on a schedule.',
  ),
  CardDef(
    id: 'comp',
    title: 'Compounding',
    emoji: '❄️',
    lesson: 'sip-power-3',
    tier: 'gold',
    blurb: 'Growth on growth.',
  ),
];

void main() {
  final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());

  Future<void> pump(WidgetTester tester, {Map<String, Object> prefsInit = const {}, double scale = 1.0}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'profile_v1': '{"completedLessons":["mf-basics-3"],"credits":{"mf-basics-3":3,"sip-power-3":2}}',
      ...prefsInit,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          contentProvider.overrideWith((_) async => content),
          cardsProvider.overrideWith((_) async => _fixture),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const AlbumScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('grid shows unlocked and locked states', (tester) async {
    await pump(tester);
    expect(find.text('1 of 4 collected'), findsOneWidget);
    expect(find.bySemanticsLabel('NAV, common, unlocked'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Units, rare, locked, Needs 6 correct answers in NAV and units (3 of 6)'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('SIP, common, locked, Finish ')), findsOneWidget);
  });

  testWidgets('tapping opens the sheet', (tester) async {
    await pump(tester);
    await tester.tap(find.text('NAV').first);
    await tester.pumpAndSettle();
    expect(find.text('Price of one unit.'), findsNWidgets(2)); // grid + sheet
    expect(find.text('Nice'), findsOneWidget);
    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Units').first);
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('New tag shows once', (tester) async {
    await pump(tester);
    expect(find.text('New'), findsOneWidget);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(seenKey), ['nav']);
    // Reopen: seen, so no tag.
    await tester.pumpWidget(const SizedBox());
    await pump(
      tester,
      prefsInit: {
        seenKey: ['nav'],
      },
    );
    expect(find.text('New'), findsNothing);
  });

  testWidgets('360x640 at text scale 1.3 has no overflow', (tester) async {
    await pump(tester, scale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tile shows count', (tester) async {
    SharedPreferences.setMockInitialValues({'profile_v1': '{"completedLessons":["sip-power-1"]}'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs), cardsProvider.overrideWith((_) async => _fixture)],
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            body: Row(children: [Expanded(child: AlbumTile())]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
  });
}

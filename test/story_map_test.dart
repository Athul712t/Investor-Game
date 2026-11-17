import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/story/story_data.dart';
import 'package:investor_game/features/story/story_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final story = Story.fromJson(File('assets/content/story.json').readAsStringSync());

  Future<void> pumpMap(WidgetTester tester, List<String> done) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'profile_v1': jsonEncode({'name': 'Riya', 'storyDone': done}),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs), storyProvider.overrideWith((_) async => story)],
        child: MaterialApp(theme: buildTheme(), home: const StoryMapScreen()),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  final ch1 = story.chapters[0], ch2 = story.chapters[1];

  testWidgets('a fresh map offers chapter 1 and locks chapter 2 behind it', (tester) async {
    await pumpMap(tester, []);
    expect(find.text('START'), findsWidgets);
    expect(find.text('Finish ${ch1.title} to unlock'), findsOneWidget);
    expect(find.text('More chapters coming soon'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Chapter 2, ${ch2.title}. Finish')), findsOneWidget);
  });

  testWidgets('finishing chapter 1 marks it complete and unlocks chapter 2', (tester) async {
    await pumpMap(tester, [for (var i = 0; i < ch1.nodes.length; i++) ch1.nodeId(i)]);
    expect(find.text('Complete · tap to replay'), findsOneWidget);
    expect(find.text('Finish ${ch1.title} to unlock'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Chapter 2, ${ch2.title}. 0 of ${ch2.nodes.length} steps done')),
      findsOneWidget,
    );
  });
}

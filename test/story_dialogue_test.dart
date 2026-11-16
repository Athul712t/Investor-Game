import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/story/dialogue_scene.dart';
import 'package:investor_game/features/story/story_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tapping completes each line, then advances, then finishes the dialogue', (tester) async {
    SharedPreferences.setMockInitialValues({'profile_v1': '{"name":"Riya"}'});
    final prefs = await SharedPreferences.getInstance();
    const node = StoryNode(
      type: NodeType.dialogue,
      title: 'Test',
      lines: [DialogueLine('asha', 'Hello {name}, welcome!'), DialogueLine('you', 'Thanks Asha.')],
    );
    const chapter = Chapter(id: 'c', title: 'C', subtitle: '', emoji: '💸', color: AppColors.amber, nodes: [node]);
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const DialogueScene(node: node, chapter: chapter),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Asha'), findsOneWidget);
    expect(find.textContaining('Hello Riya, welcome!', findRichText: true), findsOneWidget);

    final scene = find.byType(DialogueScene);
    await tester.tap(scene); // finish typing
    await tester.pump();
    expect(find.text('Tap to continue  ▾'), findsOneWidget);
    await tester.tap(scene); // next line
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Riya'), findsOneWidget); // the player's own name tag
    await tester.tap(scene);
    await tester.pump();
    await tester.tap(scene); // last line done: closes the scene
    await tester.pump(const Duration(seconds: 1)); // the character bob loops forever, so no pumpAndSettle
    expect(result, isTrue);
  });
}

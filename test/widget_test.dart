import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
}

void main() {
  testWidgets('hub loads with story mode and the tab bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const InvestorGameApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Story Mode'), findsOneWidget);
    expect(find.text('Choose your mode'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget); // bottom bar
  });

  test('profile: rewards, streak, lesson and game records persist', () async {
    final c = await _container();
    final n = c.read(profileProvider.notifier);
    expect(n.completeLesson('l1'), isTrue);
    expect(n.completeLesson('l1'), isFalse);
    expect(c.read(profileProvider).xp, 25);
    expect(c.read(profileProvider).streak, 1);
    n.touchStreak(DateTime.now().add(const Duration(days: 1)));
    expect(c.read(profileProvider).streak, 2);
    n.touchStreak(DateTime.now().add(const Duration(days: 5)));
    expect(c.read(profileProvider).streak, 1);
    expect(n.recordGame(const GameResult(gameId: 'runner', score: 40, durationMs: 1, coinsEarned: 7)), isTrue);
    expect(n.recordGame(const GameResult(gameId: 'runner', score: 10, durationMs: 1)), isFalse);
    expect(n.spend(100), isFalse);
    expect(n.spend(7), isTrue);

    // A fresh container reads the same saved state.
    final c2 = ProviderContainer(overrides: [prefsProvider.overrideWithValue(c.read(prefsProvider))]);
    expect(c2.read(profileProvider).highScores['runner'], 40);
    expect(c2.read(profileProvider).completedLessons, {'l1'});
  });

  test('bundled content parses and every question is well formed', () {
    final content = Content.fromJson(File('assets/content/modules.json').readAsStringSync());
    expect(content.modules, isNotEmpty);
    final ids = <String>{};
    for (final l in content.lessons) {
      expect(l.cards, isNotEmpty, reason: l.id);
      for (final q in l.questions) {
        expect(ids.add(q.id), isTrue, reason: 'duplicate id ${q.id}');
        expect(q.explanation, isNotEmpty, reason: q.id);
        final p = q.payload;
        switch (q.type.name) {
          case 'mcq' || 'scenario':
            final n = (p['options']! as List).length;
            expect(p['prompt'], isA<String>(), reason: q.id);
            expect(p['correctIndex'], inInclusiveRange(0, n - 1), reason: q.id);
          case 'trueFalse':
            expect(p['answer'], isA<bool>(), reason: q.id);
            expect(p['statement'], isA<String>(), reason: q.id);
          case 'mythFact':
            expect(p['answer'], anyOf('myth', 'fact'), reason: q.id);
            expect(p['statement'], isA<String>(), reason: q.id);
          case 'match':
            expect((p['pairs']! as List).length, greaterThanOrEqualTo(3), reason: q.id);
        }
      }
    }
    expect(content.quickQuestions, isNotEmpty);
  });
}

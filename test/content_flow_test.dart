import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/domain/entities/content.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/features/content/lesson_screen.dart';
import 'package:investor_game/features/content/question_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question _q(String id, QuestionType type, Map<String, Object?> payload) =>
    Question(id: id, type: type, topic: 't', difficulty: 1, explanation: 'Because reasons.', payload: payload);

final _mcq = _q('mcq', QuestionType.mcq, {
  'prompt': 'Pick B',
  'options': ['Alpha', 'Beta', 'Gamma'],
  'correctIndex': 1,
});
final _tf = _q('tf', QuestionType.trueFalse, {'statement': 'Water is wet.', 'answer': true});
final _mf = _q('mf', QuestionType.mythFact, {'statement': 'Cats bark.', 'answer': 'myth'});
final _match = _q('match', QuestionType.match, {
  'prompt': 'Match them',
  'pairs': [
    {'left': 'One', 'right': 'Uno'},
    {'left': 'Two', 'right': 'Dos'},
    {'left': 'Three', 'right': 'Tres'},
  ],
});
final _scenario = _q('sc', QuestionType.scenario, {
  'prompt': 'Market drops',
  'options': [
    {'text': 'Panic sell', 'outcome': 'You locked in a loss.'},
    {'text': 'Stay calm', 'outcome': 'You kept your plan.'},
  ],
  'correctIndex': 1,
});

Future<List<bool>> _pump(WidgetTester tester, Question q) async {
  final got = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuestionView(question: q, onAnswered: got.add),
        ),
      ),
    ),
  );
  return got;
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester, List<bool> got, bool expected) async {
  expect(find.text('Because reasons.'), findsOneWidget);
  expect(got, isEmpty);
  await _tap(tester, 'Continue');
  expect(got, [expected]);
  await tester.tap(find.text('Continue'), warnIfMissed: false);
  await tester.pumpAndSettle();
  expect(got, [expected]); // exactly once
}

void main() {
  testWidgets('mcq right and wrong', (tester) async {
    var got = await _pump(tester, _mcq);
    await _tap(tester, 'Beta');
    await _finish(tester, got, true);

    got = await _pump(tester, _q('mcq2', QuestionType.mcq, _mcq.payload));
    await _tap(tester, 'Alpha');
    await _tap(tester, 'Beta'); // locked after the first pick
    await _finish(tester, got, false);
  });

  testWidgets('true/false right and wrong', (tester) async {
    var got = await _pump(tester, _tf);
    await _tap(tester, 'True');
    await _finish(tester, got, true);

    got = await _pump(tester, _q('tf2', QuestionType.trueFalse, _tf.payload));
    await _tap(tester, 'False');
    await _finish(tester, got, false);
  });

  testWidgets('myth or fact by buttons and by swipe', (tester) async {
    var got = await _pump(tester, _mf);
    await _tap(tester, 'Myth');
    await _finish(tester, got, true);

    got = await _pump(tester, _q('mf2', QuestionType.mythFact, _mf.payload));
    await _tap(tester, 'Fact');
    await _finish(tester, got, false);

    got = await _pump(tester, _q('mf3', QuestionType.mythFact, _mf.payload));
    await tester.drag(find.text('Cats bark.'), const Offset(-250, 0)); // left = myth
    await tester.pumpAndSettle();
    await _finish(tester, got, true);
  });

  testWidgets('match: perfect run is correct, a slip is wrong', (tester) async {
    var got = await _pump(tester, _match);
    for (final p in [('One', 'Uno'), ('Two', 'Dos'), ('Three', 'Tres')]) {
      await _tap(tester, p.$1);
      await _tap(tester, p.$2);
    }
    await _finish(tester, got, true);

    got = await _pump(tester, _q('match2', QuestionType.match, _match.payload));
    await _tap(tester, 'One');
    await _tap(tester, 'Dos'); // mistake, 'One' stays selected
    await _tap(tester, 'Uno');
    for (final p in [('Two', 'Dos'), ('Three', 'Tres')]) {
      await _tap(tester, p.$1);
      await _tap(tester, p.$2);
    }
    await _finish(tester, got, false);
  });

  testWidgets('scenario shows outcome and judges the choice', (tester) async {
    var got = await _pump(tester, _scenario);
    await _tap(tester, 'Stay calm');
    expect(find.text('You kept your plan.'), findsOneWidget);
    await _finish(tester, got, true);

    got = await _pump(tester, _q('sc2', QuestionType.scenario, _scenario.payload));
    await _tap(tester, 'Panic sell');
    expect(find.textContaining('You locked in a loss.'), findsOneWidget);
    expect(find.textContaining('The wiser choice: Stay calm'), findsOneWidget);
    await _finish(tester, got, false);
  });

  testWidgets('lesson runs from first card to summary and awards XP', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lesson = Lesson(
      id: 'x-1',
      title: 'X',
      minutes: 1,
      cards: const [
        LessonCard(emoji: '🤝', title: 'Card one', body: 'Body one'),
        LessonCard(emoji: '💡', title: 'Card two', body: 'Body two'),
      ],
      questions: [_mcq, _tf],
    );
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        contentProvider.overrideWith(
          (ref) async => Content([
            Module(id: 'm', title: 'M', subtitle: '', emoji: '📘', color: 'mint', lessons: [lesson]),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(contentProvider.future);
    bool? popped;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    popped = await Navigator.of(ctx)
                        .push<bool>(MaterialPageRoute(builder: (_) => const LessonScreen(lessonId: 'x-1'))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await _tap(tester, 'open');
    expect(find.text('Card one'), findsOneWidget);
    await _tap(tester, 'Next');
    expect(find.text('Card two'), findsOneWidget);
    await _tap(tester, 'Start quiz');
    await _tap(tester, 'Beta');
    await _tap(tester, 'Continue');
    await _tap(tester, 'False'); // wrong
    await _tap(tester, 'Continue');
    expect(find.text('1 of 2 correct'), findsOneWidget);
    expect(container.read(profileProvider).completedLessons, {'x-1'});
    expect(container.read(profileProvider).xp, 12);
    await tester.pump(const Duration(seconds: 3));
    await _tap(tester, 'Continue');
    expect(popped, isTrue);
  });

  testWidgets('unknown lesson shows a friendly message', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs), contentProvider.overrideWith((ref) async => Content([]))],
        child: MaterialApp(
          theme: buildTheme(),
          home: const LessonScreen(lessonId: 'nope'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('We could not find that lesson'), findsOneWidget);
  });
}

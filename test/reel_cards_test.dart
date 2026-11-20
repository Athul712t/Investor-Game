import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/content_repo.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/domain/entities/content.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/features/reel/cards/question_card.dart';
import 'package:investor_game/features/reel/cards/read_card.dart';
import 'package:investor_game/features/reel/reel_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question _q(String id, QuestionType type, Map<String, Object?> payload) =>
    Question(id: id, type: type, topic: 't', difficulty: 1, explanation: 'Because reasons.', payload: payload);

final _qs = {
  'mcq': _q('mcq', QuestionType.mcq, {
    'prompt': 'Pick B',
    'options': ['Alpha', 'Beta', 'Gamma'],
    'correctIndex': 1,
  }),
  'tf': _q('tf', QuestionType.trueFalse, {'statement': 'Water is wet.', 'answer': true}),
  'mf': _q('mf', QuestionType.mythFact, {'statement': 'Cats bark.', 'answer': 'myth'}),
  'match': _q('match', QuestionType.match, {
    'prompt': 'Match them',
    'pairs': [
      {'left': 'One', 'right': 'Uno'},
      {'left': 'Two', 'right': 'Dos'},
      {'left': 'Three', 'right': 'Tres'},
    ],
  }),
  'sc': _q('sc', QuestionType.scenario, {
    'prompt': 'Market drops',
    'options': [
      {'text': 'Panic sell', 'outcome': 'You locked in a loss.'},
      {'text': 'Stay calm', 'outcome': 'You kept your plan.'},
    ],
    'correctIndex': 1,
  }),
};

// How to answer each type: right and wrong, as lists of tap labels.
const _right = {
  'mcq': ['Beta'],
  'tf': ['True'],
  'mf': ['Myth'],
  'match': ['One', 'Uno', 'Two', 'Dos', 'Three', 'Tres'],
  'sc': ['Stay calm'],
};
const _wrong = {
  'mcq': ['Alpha'],
  'tf': ['False'],
  'mf': ['Fact'],
  'match': ['One', 'Dos', 'Uno', 'Two', 'Dos', 'Three', 'Tres'],
  'sc': ['Panic sell'],
};

const _read = LessonCard(emoji: '💡', title: 'Read title', body: 'Read body text.');

class _Harness {
  _Harness(this.container);
  final ProviderContainer container;
  final calls = <bool>[];
  void done({required bool correct}) => calls.add(correct);
  int get xp => container.read(profileProvider).xp;
  int get coins => container.read(profileProvider).coins;
}

Future<_Harness> _pump(
  WidgetTester tester,
  Widget Function(_Harness h) card, {
  Size size = const Size(390, 700),
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      contentProvider.overrideWith(
        (ref) async => Content([
          Module(
            id: 'm',
            title: 'Module Name',
            subtitle: '',
            emoji: '📘',
            color: 'amber',
            lessons: [
              Lesson(id: 'l-1', title: 'L', minutes: 1, cards: const [_read], questions: const []),
            ],
          ),
        ]),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(contentProvider.future);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = _Harness(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: card(h)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

QuestionCard _qCard(_Harness h, String key, {bool active = true, bool retry = false}) => QuestionCard(
  item: ReelQuestion(_qs[key]!, 'l-1', retry: retry),
  active: active,
  onDone: h.done,
);

ReadCard _rCard(_Harness h, {bool active = true}) =>
    ReadCard(item: const ReelRead(_read, 'l-1', 0), active: active, onDone: h.done);

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  for (final key in _qs.keys) {
    for (final correct in [true, false]) {
      testWidgets('question $key answered ${correct ? 'right' : 'wrong'}', (tester) async {
        final h = await _pump(tester, (h) => _qCard(h, key));
        expect(find.text('Question  ·  Module Name'), findsOneWidget);
        for (final t in (correct ? _right : _wrong)[key]!) {
          await _tap(tester, t);
        }
        expect(h.calls, isEmpty);
        await _tap(tester, 'Continue');
        expect(h.calls, [correct]);
        expect(h.xp, correct ? 8 : 3);
        expect(h.coins, correct ? 1 : 0);
        await tester.tap(find.text('Continue'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(h.calls, [correct]);
        expect(h.xp, correct ? 8 : 3);
      });
    }
  }

  testWidgets('retry shows Second look', (tester) async {
    await _pump(tester, (h) => _qCard(h, 'tf', retry: true));
    expect(find.text('Second look'), findsOneWidget);
  });

  testWidgets('inactive question ignores taps', (tester) async {
    final h = await _pump(tester, (h) => _qCard(h, 'tf', active: false));
    await tester.tap(find.text('True'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Because reasons.'), findsNothing);
    expect(h.calls, isEmpty);
  });

  testWidgets('read card: Got it fires once and rewards once', (tester) async {
    final h = await _pump(tester, _rCard);
    expect(find.text('Quick read  ·  Module Name'), findsOneWidget);
    await _tap(tester, 'Got it');
    expect(h.calls, [true]);
    expect(h.xp, 3);
    expect(find.text('Nice'), findsOneWidget);
    await tester.tap(find.text('Nice'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(h.calls, [true]);
    expect(h.xp, 3);
  });

  testWidgets('inactive read card ignores taps', (tester) async {
    final h = await _pump(tester, (h) => _rCard(h, active: false));
    await tester.tap(find.text('Got it'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(h.calls, isEmpty);
    expect(h.xp, 0);
  });

  testWidgets('both cards fit 360x560 at text scale 1.3', (tester) async {
    const small = Size(360, 560);
    for (final key in _qs.keys) {
      await _pump(tester, (h) => _qCard(h, key, retry: true), size: small, textScale: 1.3);
      expect(tester.takeException(), isNull, reason: key);
      for (final t in _right[key]!) {
        await _tap(tester, t);
      }
      expect(tester.takeException(), isNull, reason: '$key feedback');
    }
    await _pump(tester, _rCard, size: small, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}

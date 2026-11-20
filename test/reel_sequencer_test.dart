import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/entities/content.dart';
import 'package:investor_game/domain/entities/question.dart';
import 'package:investor_game/features/reel/reel_extra.dart';
import 'package:investor_game/features/reel/reel_feed.dart';
import 'package:investor_game/features/reel/reel_item.dart';
import 'package:investor_game/features/reel/reel_sequencer.dart';

Question q(String id) => Question(
  id: id,
  type: QuestionType.trueFalse,
  topic: 't',
  difficulty: 1,
  explanation: 'e',
  payload: const {'statement': 's', 'answer': true},
);

LessonCard card(String t) => LessonCard(emoji: 'x', title: t, body: 'b');

Lesson lesson(String id, int reads, int qs) => Lesson(
  id: id,
  title: id,
  minutes: 1,
  cards: [for (var i = 0; i < reads; i++) card('$id-r$i')],
  questions: [for (var i = 0; i < qs; i++) q('$id-q$i')],
);

final lessons = [lesson('a', 2, 2), lesson('b', 1, 1), lesson('c', 0, 0), lesson('d', 1, 2)];
final extra = ReelExtra(
  reads: {
    'a': [card('a-x')],
  },
  questions: {
    'b': [q('b-x')],
  },
);
const ids6 = ['g1', 'g2', 'g3', 'g4', 'g5', 'g6'];

ReelSequencer make({
  int seed = 1,
  List<Lesson>? ls,
  List<String> gameIds = ids6,
  ReelCursor? cursor,
  ReelExtra? ex,
  double share = 0.5,
}) => ReelSequencer(
  lessons: ls ?? lessons,
  extra: ex ?? extra,
  gameIds: gameIds,
  rng: Random(seed),
  cursor: cursor,
  gameShare: share,
);

String label(ReelItem i) => switch (i) {
  ReelGame() => 'G',
  ReelQuestion(:final question, :final retry) => retry ? 'R:${question.id}' : 'Q:${question.id}',
  ReelRead(:final lessonId, :final index) => 'r:$lessonId$index',
};

List<ReelItem> draw(ReelFeed f, int n) => [for (var i = 0; i < n; i++) f.next()];

void main() {
  test('first card is a game', () {
    for (var s = 0; s < 20; s++) {
      expect(make(seed: s).next(), isA<ReelGame>());
    }
  });

  test('guard rails over 2000 draws', () {
    final items = draw(make(seed: 7), 2000);
    var games = 0, learn = 0;
    final played = <String>[];
    for (final it in items) {
      if (it is ReelGame) {
        games++;
        learn = 0;
        expect(games, lessThanOrEqualTo(2));
        expect(played.reversed.take(2), isNot(contains(it.gameId)));
        played.add(it.gameId);
      } else {
        learn++;
        games = 0;
        expect(learn, lessThanOrEqualTo(2));
      }
    }
    expect([
      for (final it in items.whereType<ReelGame>()) it.serial,
    ], List.generate(items.whereType<ReelGame>().length, (i) => i));
    final share = items.whereType<ReelGame>().length / items.length;
    expect(share, inInclusiveRange(0.35, 0.55));
  });

  test('learning order: reads then questions, extras merged, empty lesson skipped, loops', () {
    final f = make(seed: 3);
    final learning = [
      for (final it in draw(f, 200))
        if (it is! ReelGame) label(it),
    ];
    const loop = [
      'r:a0', 'r:a1', 'r:a2', 'Q:a-q0', 'Q:a-q1', //
      'r:b0', 'Q:b-q0', 'Q:b-x',
      'r:d0', 'Q:d-q0', 'Q:d-q1',
    ];
    expect(learning.take(loop.length * 2), [...loop, ...loop]);
  });

  test('wrong answer returns once, about 3 learning cards later, not duplicated', () {
    final f = make(seed: 5);
    final seen = <ReelItem>[];
    ReelQuestion? wrong;
    var learningAfter = 0;
    for (var i = 0; i < 60; i++) {
      final it = f.next();
      seen.add(it);
      if (wrong != null && it is! ReelGame) learningAfter++;
      if (wrong == null && it is ReelQuestion) {
        wrong = it;
        f.reportWrong(it);
        f.reportWrong(it);
        expect(f.cursor.retry, [it.question.id]);
        continue;
      }
      if (it is ReelQuestion && it.retry) {
        expect(it.question.id, wrong!.question.id);
        expect(learningAfter, 4); // 3 script items in between, then the retry
        expect(f.cursor.retry, isEmpty);
        break;
      }
    }
    final retries = seen.whereType<ReelQuestion>().where((x) => x.retry);
    expect(retries.length, 1);
    final more = draw(f, 40).whereType<ReelQuestion>().where((x) => x.retry);
    expect(more, isEmpty);
  });

  test('cursor round-trips and resumes the same learning order', () {
    final f = make(seed: 9);
    var first = true;
    for (var i = 0; i < 9; i++) {
      final it = f.next();
      if (it is ReelQuestion && first) {
        first = false;
        f.reportWrong(it);
      }
    }
    final saved = ReelCursor.fromJson(Map<String, Object?>.from(f.cursor.toJson()));
    expect(saved.lesson, f.cursor.lesson);
    expect(saved.step, f.cursor.step);
    expect(saved.retry, f.cursor.retry);
    final a = [
      for (final it in draw(f, 80))
        if (it is! ReelGame && !(it is ReelQuestion && it.retry)) label(it),
    ];
    final b = [
      for (final it in draw(make(seed: 2, cursor: saved), 80))
        if (it is! ReelGame && !(it is ReelQuestion && it.retry)) label(it),
    ];
    expect(b.take(10), a.take(10));
  });

  test('unknown retry ids are dropped, retry kept otherwise', () {
    final f = make(cursor: const ReelCursor(lesson: 1, step: 1, retry: ['a-q0', 'gone']));
    expect(f.cursor.retry, ['a-q0']);
    final learning = [
      for (final it in draw(f, 40))
        if (it is! ReelGame) label(it),
    ];
    expect(learning.first, 'Q:b-q0');
    expect(learning, contains('R:a-q0'));
  });

  test('out of range cursor is normalised', () {
    final f = make(cursor: const ReelCursor(lesson: 99, step: 99));
    expect(f.cursor.lesson, inInclusiveRange(0, 3));
    draw(f, 20);
  });

  test('all lessons empty: games forever', () {
    final f = make(ls: [lesson('e', 0, 0), lesson('f', 0, 0)], ex: const ReelExtra());
    final items = draw(f, 100);
    expect(items.every((i) => i is ReelGame), isTrue);
    f.reportWrong(ReelQuestion(q('zzz'), 'e'));
    expect(f.next(), isA<ReelGame>());
    expect(make(ls: const [], ex: const ReelExtra()).next(), isA<ReelGame>());
  });

  test('1 or 2 game ids work and keep guard rails', () {
    for (final gs in [
      ['only'],
      ['x', 'y'],
    ]) {
      final items = draw(make(seed: 4, gameIds: gs), 500);
      var run = 0;
      for (final it in items) {
        run = it is ReelGame ? run + 1 : 0;
        expect(run, lessThanOrEqualTo(2));
      }
      final played = items.whereType<ReelGame>().map((g) => g.gameId).toList();
      expect(played.toSet(), gs.toSet());
      if (gs.length == 2) {
        for (var i = 1; i < played.length; i++) {
          expect(played[i], isNot(played[i - 1]));
        }
      }
    }
  });

  test('type order is not a fixed pattern', () {
    String types(int seed) => draw(make(seed: seed), 60).map((i) => i is ReelGame ? 'G' : 'L').join();
    expect(types(1), isNot(types(2)));
    expect(types(1), types(1));
  });

  group('Reel mode share', () {
    for (var stop = 0; stop <= 4; stop++) {
      final share = ReelMix.shareOf(stop);
      test('stop $stop (${ReelMix.labels[stop]}): fraction, run caps, first card, no repeats', () {
        for (final seed in [1, 2, 3]) {
          final f = make(seed: seed, share: share);
          final items = draw(f, 2000);
          final games = items.whereType<ReelGame>().length;
          expect(games / items.length, closeTo(share, 0.05), reason: 'seed $seed');
          if (share == 1) expect(games, items.length);
          if (share == 0) expect(games, 0);
          expect(items.first is ReelGame, share > 0);
          final maxG = share <= 0.5 ? 2 : 4, maxL = share >= 0.5 ? 2 : 4;
          var g = 0, l = 0;
          final played = <String>[];
          for (final it in items) {
            if (it is ReelGame) {
              g++;
              l = 0;
              if (share < 1) expect(g, lessThanOrEqualTo(maxG));
              expect(played.reversed.take(2), isNot(contains(it.gameId)));
              played.add(it.gameId);
            } else {
              l++;
              g = 0;
              if (share > 0) expect(l, lessThanOrEqualTo(maxL));
            }
          }
        }
      });
    }

    test('games only: the learning cursor and queued retries stay put', () {
      const saved = ReelCursor(lesson: 1, step: 1, retry: ['a-q0']);
      final f = make(share: 1, cursor: saved);
      draw(f, 200);
      expect(f.cursor.toJson(), saved.toJson());
    });

    test('learning only keeps the lesson order and serves retries', () {
      final f = make(share: 0);
      final first = draw(f, 4);
      expect(first.map(label), ['r:a0', 'r:a1', 'r:a2', 'Q:a-q0']);
      f.reportWrong(first.last as ReelQuestion);
      expect(draw(f, 6).map(label), contains('R:a-q0'));
    });

    test('shareOf clamps out-of-range stops', () {
      expect(ReelMix.shareOf(-3), 1.0);
      expect(ReelMix.shareOf(9), 0.0);
      expect(ReelMix.shareOf(2), 0.5);
    });
  });
}

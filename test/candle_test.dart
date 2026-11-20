import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/candle/candle_game.dart';
import 'package:investor_game/features/games/candle/candle_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('points formula and clamps', () {
    expect(pointsFor(250), 800);
    expect(pointsFor(500), 300);
    expect(pointsFor(150), 1000);
    expect(pointsFor(50), 1000);
    expect(pointsFor(650), 0);
    expect(pointsFor(5000), 0);
  });

  test('false start scores 0; coins by speed', () {
    expect(roundScore(null), 0);
    expect(coinsFor(null), 0);
    expect(coinsFor(200), 2);
    expect(coinsFor(250), 1);
    expect(coinsFor(300), 0);
  });

  test('wait is always within 1.2 to 3.5 s', () {
    final rng = Random(3);
    for (var i = 0; i < 2000; i++) {
      expect(nextWait(rng), inInclusiveRange(1.2, 3.5));
    }
  });

  test('decoys only from round 3 and clear of the go moment', () {
    final rng = Random(4);
    for (var r = 1; r <= 5; r++) {
      for (var i = 0; i < 300; i++) {
        final w = nextWait(rng);
        final d = planDecoy(rng, r, w);
        if (r < 3) {
          expect(d, isNull);
        } else {
          expect(d, isNotNull);
          expect(d! + candleDecoyLen, lessThan(w));
        }
      }
    }
  });

  test('run ends after exactly 5 rounds', () {
    expect([for (var i = 0; i <= 6; i++) runEnds(i)], [false, false, false, false, false, true, true]);
  });

  test('average and best skip false starts', () {
    expect(averageMs([200, null, 300]), 250);
    expect(bestMs([200, null, 300]), 200);
    expect(averageMs([null, null]), isNull);
    expect(bestMs([]), isNull);
  });

  test('smoke: five rounds of taps, render, revive', () async {
    final g = CandleGame(const GameConfig(seed: 7))..onGameResize(Vector2(390, 844));
    await g.onLoad();
    var over = false;
    g.onGameOver = () => over = true;
    var goFrames = 0;
    var falseStarted = false;
    var rounds = 0;
    for (var f = 0; f < 20000 && !over; f++) {
      g.update(1 / 60);
      if (f % 400 == 0) g.render(Canvas(PictureRecorder()));
      if (g.phase == CandlePhase.waiting && !falseStarted) {
        falseStarted = true; // round 1: tap while red
        g.tap();
        rounds++;
      } else if (g.phase == CandlePhase.go && ++goFrames == 15) {
        g.tap(); // 0.25 s after green
        goFrames = 0;
        rounds++;
      }
    }
    expect(over, isTrue);
    expect(rounds, 5);
    expect(g.score.value, inInclusiveRange(3200, 3400));
    g.render(Canvas(PictureRecorder()));
    g.continueAfterRevive();
    expect(g.score.value, inInclusiveRange(2400, 2600));
    g.update(1 / 60);
    g.render(Canvas(PictureRecorder()));
  });
}

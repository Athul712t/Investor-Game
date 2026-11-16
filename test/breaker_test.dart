import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/breaker/breaker_game.dart';
import 'package:investor_game/features/games/breaker/breaker_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('paddleBounce', () {
    test('left, centre and right map to the right directions', () {
      final l = paddleBounce(-1, 400), c = paddleBounce(0, 400), r = paddleBounce(1, 400);
      expect(l.$1, lessThan(-300));
      expect(c.$1, closeTo(0, 1e-9));
      expect(c.$2, closeTo(-400, 1e-9));
      expect(r.$1, greaterThan(300));
      expect(l.$2, lessThan(0));
      expect(r.$2, lessThan(0));
    });
  });

  group('fixVelocity', () {
    test('a near-horizontal ball gets a minimum vertical speed and keeps its speed', () {
      final v = fixVelocity(400, 2, 400);
      expect(v.$2.abs(), greaterThanOrEqualTo(400 * minVerticalFraction - 1e-9));
      expect(sqrt(v.$1 * v.$1 + v.$2 * v.$2), closeTo(400, 1e-6));
      expect(v.$2, greaterThan(0)); // keeps its direction
    });

    test('a ball with no vertical speed still ends up moving vertically', () {
      expect(fixVelocity(400, 0, 400).$2.abs(), greaterThan(0));
    });
  });

  test('ball speed rises slowly and is capped', () {
    expect(ballSpeed(2), greaterThan(ballSpeed(1)));
    expect(ballSpeed(500), ballSpeed(100));
  });

  test('a 2-hit brick needs two hits', () {
    final b = Brick(0, 0, BrickType.steel);
    expect(b.hit(), isFalse);
    expect(b.hit(), isTrue);
    final v = Brick(0, 0, BrickType.vault);
    expect([v.hit(), v.hit(), v.hit()], [false, false, true]);
  });

  test('combo multiplier grows and is capped', () {
    expect(comboMultiplier(0), 1);
    expect(comboMultiplier(3), 2);
    expect(comboMultiplier(1000), 8);
  });

  test('levels always have bricks inside the grid', () {
    for (var level = 1; level <= 60; level++) {
      for (final rows in [3, 6, 10]) {
        final bricks = generateLevel(level, 8, rows, Random(level * 31 + rows));
        expect(bricks, isNotEmpty);
        for (final b in bricks) {
          expect(b.row, lessThan(rows));
          expect(b.col, inInclusiveRange(0, 7));
        }
      }
    }
  });

  test('losing the last life ends the run', () {
    final l = Lives();
    expect([l.loseLife(), l.loseLife(), l.loseLife()], [false, false, true]);
  });

  group('BreakerGame', () {
    test('runs 600 frames and renders without throwing', () async {
      final g = BreakerGame(const GameConfig(seed: 4))..onGameResize(Vector2(390, 844));
      await g.onLoad();
      g.applyPowerup(PowerupType.magnet);
      g.applyPowerup(PowerupType.doubleScore);
      for (var i = 0; i < 600; i++) {
        g.update(1 / 60);
        if (i == 40) g.launch();
        g.movePaddle(sin(i / 20) * 12);
      }
      final recorder = PictureRecorder();
      g.render(Canvas(recorder));
      recorder.endRecording();
    });

    test('missing every ball three times is game over', () async {
      final g = BreakerGame(const GameConfig(seed: 2))..onGameResize(Vector2(390, 844));
      await g.onLoad();
      var over = false;
      g.onGameOver = () => over = true;
      for (var i = 0; i < 20000 && !over; i++) {
        g.update(1 / 60);
        if (i > 30) g.launch();
      }
      expect(over, isTrue);
      expect(g.lives.count, 0);
    });
  });
}

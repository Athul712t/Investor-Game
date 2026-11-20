import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/lock/lock_game.dart';
import 'package:investor_game/features/games/lock/lock_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hit window', () {
    test('wraps around 0/360', () {
      expect(angleGap(359, 1), closeTo(2, 1e-9));
      expect(dotHit(358, 3, 6), isTrue);
      expect(dotHit(3, 358, 6), isTrue);
      expect(dotHit(350, 10, 6), isFalse);
    });
    test('both directions', () {
      expect(aheadOf(10, 50, 1), 40);
      expect(aheadOf(10, 50, -1), 320);
      expect(aheadOf(5, 355, -1), 10);
    });
    test('perfect is a small centre window', () {
      expect(isPerfect(100, 103), isTrue);
      expect(isPerfect(100, 106), isFalse);
      expect(isPerfect(359, 1), isTrue);
    });
    test('pin passing the dot is detected in both directions', () {
      expect(dotPassed(100, 90, 1, 20), isFalse); // dot just behind, still inside window
      expect(dotPassed(120, 90, 1, 20), isTrue);
      expect(dotPassed(60, 90, -1, 20), isTrue);
      expect(dotPassed(80, 90, -1, 20), isFalse);
      expect(dotPassed(5, 350, -1, 20), isFalse);
    });
    test('window shrinks slowly with a floor', () {
      expect(dotHalfWidth(0), greaterThan(dotHalfWidth(10)));
      expect(dotHalfWidth(500), 11);
    });
  });

  test('dot is never closer than 70 degrees ahead of the pin', () {
    final rng = Random(3);
    for (var i = 0; i < 3000; i++) {
      final pin = rng.nextDouble() * 360;
      final dir = rng.nextBool() ? 1 : -1;
      final d = pickDotAngle(rng, pin, dir);
      expect(aheadOf(pin, d, dir), inInclusiveRange(minDotGap - 1e-6, maxDotGap + 1e-6));
      expect(dotPassed(pin, d, dir, 24), isFalse);
    }
  });

  test('combo grows and a miss resets via comboMult(0)', () {
    expect(comboMult(0), 1);
    expect(comboMult(3), 2);
    expect(comboMult(100), 5);
    expect(popPoints(perfect: true, combo: 3), 4);
    expect(popPoints(perfect: false, combo: 0, doubled: true), 2);
  });

  test('speed is slow first, rises, and is capped', () {
    expect(pinSpeed(0), baseSpeed);
    expect(pinSpeed(2), baseSpeed);
    expect(pinSpeed(10), greaterThan(pinSpeed(4)));
    expect(pinSpeed(1000), maxSpeed);
  });

  test('every 8th pop is a bolt', () {
    expect(
      [
        for (var i = 0; i < 20; i++)
          if (nextIsBolt(i)) i,
      ],
      [7, 15],
    );
  });

  test('run ends on time or lives', () {
    expect(runEnded(timeLeft: 1, lives: 1), isFalse);
    expect(runEnded(timeLeft: 0, lives: 3), isTrue);
    expect(runEnded(timeLeft: 20, lives: 0), isTrue);
  });

  test('smoke: runs, renders, revives, powerups', () async {
    final g = LockGame(const GameConfig(seed: 5))..onGameResize(Vector2(390, 844));
    await g.onLoad();
    for (var i = 0; i < 600; i++) {
      if (i % 25 == 0) g.tap();
      g.update(1 / 60);
    }
    g.render(Canvas(PictureRecorder()));
    g.revive();
    for (final p in PowerupType.values) {
      g.applyPowerup(p);
    }
    g.render(Canvas(PictureRecorder()));
    g.update(1 / 60);
  });
}

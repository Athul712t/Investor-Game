import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/slice/slice_game.dart';
import 'package:investor_game/features/games/slice/slice_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('segmentHitsCircle', () {
    test('hit through the middle', () => expect(segmentHitsCircle(-10, 0, 10, 0, 0, 0, 5), isTrue));
    test('miss', () => expect(segmentHitsCircle(-10, 8, 10, 8, 0, 0, 5), isFalse));
    test('tangent counts', () => expect(segmentHitsCircle(-10, 5, 10, 5, 0, 0, 5), isTrue));
    test('segment ending short misses', () => expect(segmentHitsCircle(-10, 0, -6, 0, 0, 0, 5), isFalse));
    test('segment fully inside', () => expect(segmentHitsCircle(-1, 0, 1, 1, 0, 0, 5), isTrue));
  });

  test('a slow drag does not slice, a fast one does', () {
    expect(isSwipeFast(4, 0.1), isFalse); // 40 px/s
    expect(isSwipeFast(40, 0.05), isTrue); // 800 px/s
  });

  test('combo counting within one swipe', () {
    final t = SwipeTracker();
    expect(t.hit().bonus, 0);
    expect(t.hit().bonus, 0);
    final third = t.hit();
    expect((third.count, third.bonus), (3, 3));
    expect(t.hit().bonus, 1);
    t.end();
    expect(t.hit().count, 1);
  });

  test('a slow pause ends the swipe', () {
    final t = SwipeTracker();
    t.move(50, 0.05, 1);
    t.hit();
    t.move(1, 0.05, 1.5);
    expect(t.count, 0);
  });

  test('shield defuses a bomb without losing a life', () {
    final r = resolveBomb(3, true);
    expect((r.lives, r.shield, r.cleared), (3, false, false));
    final u = resolveBomb(3, false);
    expect((u.lives, u.cleared), (2, true));
  });

  test('a wave never contains only bombs', () {
    final rng = Random(1);
    for (var i = 0; i < 3000; i++) {
      final w = planWave(rng, rng.nextDouble() * 600);
      expect(w, isNotEmpty);
      expect(w.length, lessThanOrEqualTo(5));
      expect(w.any((k) => k != SliceKind.bomb), isTrue);
    }
  });

  test('toss arcs peak inside the visible play area', () {
    final rng = Random(2);
    for (final h in [640.0, 844.0, 1200.0]) {
      final g = h * 1.25;
      for (var i = 0; i < 500; i++) {
        final peak = peakOf(g, h - 96, tossVy(g, h - 96, tossPeakY(rng, h)));
        expect(peak, greaterThanOrEqualTo(130 - 1e-6));
        expect(peak, lessThanOrEqualTo(h * 2 / 3));
      }
    }
  });

  test('smoke: runs and renders', () async {
    final g = SliceGame(const GameConfig(seed: 5))..onGameResize(Vector2(390, 844));
    await g.onLoad();
    for (var i = 0; i < 600; i++) {
      g.update(1 / 60);
    }
    g.render(Canvas(PictureRecorder()));
    expect(g.isOver, isFalse);
  });
}

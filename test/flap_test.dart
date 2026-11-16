import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/flap/flap_game.dart';
import 'package:investor_game/features/games/flap/flap_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const top = flapHud, bottom = 844 - flapGroundInset;

  test('gap centres stay inside the playfield and are reachable', () {
    final rng = Random(5);
    var c = nextCentre(0, rng, 0, top, bottom);
    for (var n = 1; n < 2000; n++) {
      final gap = gapFor(n, bottom - top);
      final next = nextCentre(c, rng, n, top, bottom);
      expect(next - gap / 2, greaterThanOrEqualTo(top + flapMargin - 1e-9));
      expect(next + gap / 2, lessThanOrEqualTo(bottom - flapMargin + 1e-9));
      expect((next - c).abs(), lessThanOrEqualTo(maxGapStep(speedFor(n)) + 1e-9));
      c = next;
    }
  });

  test('gap shrinks to a minimum and speed is capped', () {
    expect(gapFor(0, 564), greaterThan(gapFor(20, 564)));
    for (var n = 0; n < 500; n++) {
      expect(gapFor(n, 564), greaterThanOrEqualTo(150));
      expect(speedFor(n), lessThanOrEqualTo(200));
    }
  });

  test('a shield absorbs one hit, no shield ends the run', () {
    final a = resolveHit(shield: true);
    expect(a.dead, isFalse);
    expect(a.shield, isFalse);
    expect(resolveHit(shield: false).dead, isTrue);
  });

  test('each candle scores once', () {
    final pairs = [for (var i = 1; i <= 3; i++) CandlePair(x: 100.0 * i, centre: 300, gap: 200, index: i)];
    expect(collectPassed(pairs, 150), hasLength(1));
    expect(collectPassed(pairs, 150), isEmpty);
    expect(collectPassed(pairs, 1000), hasLength(2));
    expect(collectPassed(pairs, 1000), isEmpty);
  });

  test('smoke: 600 frames with taps, then render', () async {
    final g = FlapGame(const GameConfig(seed: 2))..onGameResize(Vector2(390, 844));
    await g.onLoad();
    for (var i = 0; i < 600; i++) {
      if (i % 20 == 0) g.thrust();
      g.update(1 / 60);
    }
    g.render(Canvas(PictureRecorder()));
    g.applyPowerup(PowerupType.shield);
    g.revive();
    g.update(1 / 60);
    g.render(Canvas(PictureRecorder()));
  });
}

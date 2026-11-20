import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/dunk/dunk_game.dart';
import 'package:investor_game/features/games/dunk/dunk_rules.dart';

List<DunkEvent> fly(DunkSim s, {double max = 8}) {
  final all = <DunkEvent>[];
  for (var t = 0.0; t < max && s.flying; t += 1 / 60) {
    s.advance(1 / 60);
    all.addAll(s.events);
  }
  return all;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final f = DunkField(390, 844);

  test('a solved launch reaches the hoop and swishes for 2', () {
    final hoop = DunkHoop(250, 844 * 0.3, f.ringHalf(0));
    final v = findLaunch(f, hoop)!;
    final sim = DunkSim(f, hoop)..launch(v.vx, v.vy);
    final ev = fly(sim);
    expect(ev, contains(DunkEvent.swish));
    expect(ev, isNot(contains(DunkEvent.rim)));
    expect(DunkRun().basket(swish: true), 2);
  });

  test('a rim touch before the basket scores 1', () {
    var found = false;
    final hoop = DunkHoop(250, 844 * 0.3, f.ringHalf(0));
    final speed = findLaunch(f, hoop)!.speed;
    for (var off = 0.0; off < 40 && !found; off += 0.5) {
      final v = solveLaunch(f, hoop.x - hoop.half + off, hoop.y, speed)!;
      final sim = DunkSim(f, hoop)..launch(v.vx, v.vy);
      final ev = fly(sim);
      if (ev.contains(DunkEvent.rim) && ev.contains(DunkEvent.basket)) {
        found = true;
        expect(ev, isNot(contains(DunkEvent.swish)));
        expect(DunkRun().basket(swish: false), 1);
      }
    }
    expect(found, isTrue);
  });

  test('a throw that falls short is a miss and costs a life', () {
    final sim = DunkSim(f, DunkHoop(250, 250, f.ringHalf(0)))..launch(60, -300);
    final ev = fly(sim);
    expect(ev.last, DunkEvent.miss);
    final run = DunkRun()..streak = 4;
    run.miss();
    expect((run.lives, run.streak), (2, 0));
  });

  test('a fast coin cannot tunnel through a rim end', () {
    final hoop = DunkHoop(195, 300, f.ringHalf(0));
    final sim = DunkSim(f, hoop)
      ..x = hoop.x - hoop.half
      ..y = 100
      ..vy = 6000
      ..flying = true;
    final ev = fly(sim, max: 0.5);
    expect(ev, contains(DunkEvent.rim));
    expect(ev, isNot(contains(DunkEvent.swish)));
  });

  test('streak multiplier steps at 3 and 6 and resets on a miss', () {
    expect([for (var i = 0; i <= 7; i++) streakMultiplier(i)], [1, 1, 1, 2, 2, 2, 3, 3]);
    final run = DunkRun();
    final pts = [for (var i = 0; i < 6; i++) run.basket(swish: false)];
    expect(pts, [1, 1, 2, 2, 2, 3]);
    run.miss();
    expect(run.basket(swish: false), 1);
    expect(DunkRun().basket(swish: true, doubled: true), 4);
  });

  test('hoops stay in the allowed area and are reachable', () {
    for (final (w, h) in const [(390.0, 844.0), (360.0, 640.0), (820.0, 1100.0)]) {
      final fl = DunkField(w, h);
      final rng = Random(3);
      DunkHoop? prev;
      for (var i = 0; i < 400; i++) {
        final hp = nextHoop(fl, rng, i % 30, prev);
        expect(hp.y, inInclusiveRange(h * 0.18, h * 0.45));
        expect(hp.x - hp.half, greaterThan(fl.rimR));
        expect(hp.x + hp.half, lessThan(w - fl.rimR));
        expect(hoopReachable(fl, hp.x, hp.y), isTrue);
        prev = hp;
      }
      expect(fl.startY, lessThanOrEqualTo(h - 190));
    }
  });

  test('launch speed is capped and short pulls are ignored', () {
    final v = launchVelocity(f, -80, 900)!;
    expect(sqrt(v.vx * v.vx + v.vy * v.vy), closeTo(f.maxSpeed, 1e-6));
    expect(v.vy, lessThan(0));
    expect(v.vx, greaterThan(0));
    expect(launchVelocity(f, 5, 5), isNull);
    expect(launchVelocity(f, 0, -100), isNull);
  });

  test('run ends on time or lives, revive gives a life and 10 s', () {
    final run = DunkRun();
    run.tick(44);
    expect(run.over, isFalse);
    run.tick(1);
    expect(run.over, isTrue);
    run.revive();
    expect((run.over, run.timeLeft), (false, 10.0));
    final r2 = DunkRun();
    for (var i = 0; i < 3; i++) {
      r2.miss();
    }
    expect(r2.over, isTrue);
    r2.revive();
    expect(r2.lives, 1);
    for (var i = 0; i < 9; i++) {
      r2.addLife();
    }
    expect(r2.lives, dunkMaxLives);
  });

  test('smoke: runs, flicks, renders, revives', () async {
    final g = DunkGame(const GameConfig(seed: 7))..onGameResize(Vector2(390, 844));
    await g.onLoad();
    final rng = Random(1);
    var over = false;
    g.onGameOver = () => over = true;
    for (var i = 0; i < 900 && !over; i++) {
      if (i % 20 == 0 && g.canFlick) {
        final hp = g.hoop;
        final v = solveLaunch(DunkField(390, 844), hp.x + (rng.nextDouble() - 0.5) * 30, hp.y, 1400);
        if (v != null) {
          // Invert launchVelocity: drag opposite to the velocity at full power.
          final s = 120 / sqrt(v.vx * v.vx + v.vy * v.vy);
          g.flick(-v.vx * s, -v.vy * s);
        } else {
          g.flick(-30, 100);
        }
      }
      g.update(1 / 60);
    }
    g.render(Canvas(PictureRecorder()));
    expect(g.score.value, greaterThan(0));
    g.applyPowerup(PowerupType.slowMo);
    g.applyPowerup(PowerupType.doubleScore);
    g.applyPowerup(PowerupType.extraLife);
    g.revive();
    g.update(1 / 60);
    g.render(Canvas(PictureRecorder()));
  });
}

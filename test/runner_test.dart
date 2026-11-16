import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/runner/runner_game.dart';
import 'package:investor_game/features/games/runner/runner_sim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generated rows always leave a passable lane', () {
    final r = Random(1);
    for (var i = 0; i < 5000; i++) {
      final d = (i % 11) / 10;
      final row = RunnerSim.genRow(r, d, needEmpty: i.isEven);
      expect(RunnerSim.passable(row), isTrue, reason: '$row');
      if (i.isEven) expect(row, contains(Cell.empty));
    }
  });

  test('every spawned row in a long run is passable and gaps stay fair', () {
    final sim = RunnerSim(seed: 7)..invuln = 1e9; // never crash
    for (var i = 0; i < 60 * 240; i++) {
      sim.step(1 / 60);
    }
    final rows = <double, List<Kind>>{};
    for (final e in sim.entities.where((e) => e.kind == Kind.low || e.kind == Kind.tall)) {
      rows.putIfAbsent(e.at, () => []).add(e.kind);
    }
    expect(rows, isNotEmpty);
    for (final kinds in rows.values) {
      expect(kinds.where((k) => k == Kind.tall).length, lessThan(3));
    }
    final ats = rows.keys.toList()..sort();
    for (var i = 1; i < ats.length; i++) {
      // At least ~0.85 s of running between rows, even at top speed.
      expect(ats[i] - ats[i - 1], greaterThanOrEqualTo(sim.speed * 0.85 - 0.01));
    }
    expect(sim.speed, lessThanOrEqualTo(RunnerSim.maxSpeed));
  });

  test('a hit with a shield consumes the shield and does not end the run', () {
    final sim = RunnerSim(seed: 1)..shield = true;
    sim.entities.add(Entity(Kind.tall, 0, sim.distance + 0.2));
    final events = sim.step(1 / 60);
    expect(sim.shield, isFalse);
    expect(sim.crashed, isFalse);
    expect(events.map((e) => e.type), contains(SimEventType.shieldBreak));
  });

  test('a hit without a shield ends the run; jumping clears a low block', () {
    final sim = RunnerSim(seed: 1);
    sim.entities.add(Entity(Kind.tall, 0, sim.distance + 0.2));
    expect(sim.step(1 / 60).map((e) => e.type), contains(SimEventType.hit));
    expect(sim.crashed, isTrue);

    final s2 = RunnerSim(seed: 1)..jump();
    for (var i = 0; i < 12; i++) {
      s2.step(1 / 60);
    }
    s2.entities.add(Entity(Kind.low, 0, s2.distance + 0.1));
    s2.step(1 / 60);
    expect(s2.crashed, isFalse);
  });

  test('revive clears nearby obstacles and grants invulnerability', () {
    final sim = RunnerSim(seed: 3);
    sim.entities.add(Entity(Kind.tall, 0, sim.distance + 0.2));
    sim.step(1 / 60);
    sim.entities.add(Entity(Kind.low, 3, sim.distance + 20));
    sim.revive();
    expect(sim.crashed, isFalse);
    expect(sim.invuln, 2);
    expect(sim.entities.where((e) => e.kind != Kind.coin && sim.zOf(e) < 50), isEmpty);
  });

  test('same seed gives the same run', () {
    List<double> run(int seed) {
      final s = RunnerSim(seed: seed)..invuln = 1e9;
      for (var i = 0; i < 600; i++) {
        s.step(1 / 60);
      }
      return [for (final e in s.entities) e.at + e.x];
    }

    expect(run(42), run(42));
  });

  test('smoke: game runs 600 frames and renders', () async {
    final game = RunnerGame(const GameConfig(seed: 5));
    game.onGameResize(Vector2(390, 844));
    await game.onLoad();
    game.applyPowerup(PowerupType.shield);
    game.applyPowerup(PowerupType.magnet);
    for (var i = 0; i < 600; i++) {
      game.update(1 / 60);
      if (i % 60 == 0) game.render(Canvas(PictureRecorder()));
    }
    expect(game.score.value, greaterThan(0));
    if (game.isOver) game.continueAfterRevive();
    game.update(1 / 60);
  });
}

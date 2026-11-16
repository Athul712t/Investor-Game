import 'dart:math';

/// Pure-Dart simulation of Bull Run: spawning, movement, collisions, powerup timers.
/// Units are metres. `z` is distance ahead of the player, `x` is lateral (lanes at -3, 0, 3).
enum Kind { low, tall, coin, boost }

/// One lane of a generated obstacle row.
enum Cell { empty, low, tall }

enum SimEventType { coin, boost, hit, shieldBreak, land }

class SimEvent {
  const SimEvent(this.type, this.x, this.y, this.z);
  final SimEventType type;
  final double x, y, z;
}

class Entity {
  Entity(this.kind, this.x, this.at, [this.y = 0]);
  final Kind kind;
  double x, y;
  final double at; // absolute track position
  bool dead = false;
}

class RunnerSim {
  RunnerSim({int? seed}) : rng = Random(seed) {
    _boostIn = _nextBoostGap();
  }

  static const laneW = 3.0;
  static const spawnAhead = 110.0;
  static const baseSpeed = 10.0, maxSpeed = 28.0;
  static const jumpDur = 0.7, jumpPeak = 2.4;
  static const lowHeight = 1.0, clearHeight = 0.9;

  final Random rng;
  final entities = <Entity>[];
  double distance = 0, time = 0, score = 0;
  double speed = baseSpeed;
  int lane = 0;
  double x = 0; // tweened lateral position
  double jumpT = -1; // seconds into the current jump, <0 when grounded
  bool shield = false, crashed = false;
  double invuln = 0, magnet = 0, doubleScore = 0, slowMo = 0;
  int coins = 0;
  double _nextRowAt = 45, _boostIn = 0;

  double get difficulty => ((speed - baseSpeed) / (maxSpeed - baseSpeed)).clamp(0.0, 1.0);
  double get jumpH => jumpT < 0 ? 0 : jumpPeak * sin(pi * jumpT / jumpDur);
  double zOf(Entity e) => e.at - distance;

  double _nextBoostGap() => 12 + rng.nextDouble() * 6;

  void moveLane(int dir) {
    if (crashed) return;
    lane = (lane + dir).clamp(-1, 1);
  }

  /// Returns true if a jump started.
  bool jump() {
    if (crashed || jumpT >= 0) return false;
    jumpT = 0;
    return true;
  }

  /// Fast-fall out of a jump.
  void drop() {
    if (jumpT >= 0 && jumpT < jumpDur / 2) jumpT = jumpDur - jumpT;
  }

  List<SimEvent> step(double rawDt) {
    final events = <SimEvent>[];
    if (crashed) return events;
    // Powerup timers tick in real time so slow-mo doesn't extend itself.
    magnet = max(0, magnet - rawDt);
    doubleScore = max(0, doubleScore - rawDt);
    slowMo = max(0, slowMo - rawDt);
    final dt = rawDt * (slowMo > 0 ? 0.55 : 1);
    invuln = max(0, invuln - dt);
    time += dt;
    speed = min(maxSpeed, baseSpeed + (maxSpeed - baseSpeed) * (1 - exp(-time / 110)));
    distance += speed * dt;
    score += speed * dt * (doubleScore > 0 ? 2 : 1);

    // Lane tween: exponential ease, ~0.15 s to settle.
    x += (lane * laneW - x) * (1 - exp(-dt * 18));
    if (jumpT >= 0) {
      jumpT += dt;
      if (jumpT >= jumpDur) {
        jumpT = -1;
        events.add(SimEvent(SimEventType.land, x, 0, 0));
      }
    }

    _boostIn -= dt;
    while (_nextRowAt - distance < spawnAhead) {
      _spawnRow();
    }
    _collide(events, dt);
    entities.removeWhere((e) => e.dead || zOf(e) < -6);
    return events;
  }

  void _collide(List<SimEvent> events, double dt) {
    final h = jumpH;
    for (final e in entities) {
      if (e.dead) continue;
      final z = zOf(e);
      if (e.kind == Kind.coin && magnet > 0 && z < 28 && z > -1) {
        final k = 1 - exp(-dt * 10);
        e.x += (x - e.x) * k;
        e.y += (h + 0.8 - e.y) * k;
      }
      final dx = (e.x - x).abs();
      switch (e.kind) {
        case Kind.coin || Kind.boost:
          if (z.abs() < 1.0 && dx < 1.6 && (e.y - (h + 0.8)).abs() < 1.6) {
            e.dead = true;
            if (e.kind == Kind.coin) {
              coins++;
              events.add(SimEvent(SimEventType.coin, e.x, e.y, z));
            } else {
              events.add(SimEvent(SimEventType.boost, e.x, e.y, z));
            }
          }
        case Kind.low || Kind.tall:
          final depth = e.kind == Kind.low ? 0.4 : 0.3;
          if (z.abs() > depth + 0.6 || dx > 1.9) continue;
          if (e.kind == Kind.low && h > clearHeight) continue;
          if (invuln > 0) continue;
          if (hit(e)) {
            events.add(SimEvent(SimEventType.hit, x, h, 0));
            return;
          }
          events.add(SimEvent(SimEventType.shieldBreak, e.x, 0, z));
      }
    }
  }

  /// Resolve a collision. Returns true if the run ends.
  bool hit(Entity e) {
    if (shield) {
      shield = false;
      e.dead = true;
      invuln = 1;
      return false;
    }
    crashed = true;
    return true;
  }

  /// Clear the road around the player and grant 2 s of invulnerability.
  void revive() {
    crashed = false;
    jumpT = -1;
    invuln = 2;
    entities.removeWhere((e) => e.kind != Kind.coin && zOf(e) < 50);
    _nextRowAt = max(_nextRowAt, distance + 50);
  }

  void _spawnRow() {
    final d = difficulty;
    final at = _nextRowAt;
    final boostDue = _boostIn <= 0;
    final row = genRow(rng, d, needEmpty: boostDue);
    for (var i = 0; i < 3; i++) {
      final lx = (i - 1) * laneW;
      if (row[i] == Cell.low) entities.add(Entity(Kind.low, lx, at));
      if (row[i] == Cell.tall) entities.add(Entity(Kind.tall, lx, at));
    }
    // Gap in seconds of running shrinks with difficulty; never below a fair reaction window.
    final gapTime = 1.55 - 0.6 * d + rng.nextDouble() * (0.6 - 0.3 * d);
    final gap = max(16.0, speed * gapTime);
    final empties = [
      for (var i = 0; i < 3; i++)
        if (row[i] == Cell.empty) i,
    ];
    if (boostDue) {
      _boostIn = _nextBoostGap();
      final i = empties[rng.nextInt(empties.length)];
      entities.add(Entity(Kind.boost, (i - 1) * laneW, at, 1.3));
      empties.remove(i);
    }
    // Coins: an arc over a low block, or a line along an open lane.
    final lows = [
      for (var i = 0; i < 3; i++)
        if (row[i] == Cell.low) i,
    ];
    if (lows.isNotEmpty && rng.nextDouble() < 0.4) {
      final i = lows[rng.nextInt(lows.length)];
      final span = speed * jumpDur * 0.8;
      for (var k = 0; k < 5; k++) {
        final f = k / 4;
        entities.add(Entity(Kind.coin, (i - 1) * laneW, at - span / 2 + span * f, 0.9 + jumpPeak * 0.85 * sin(pi * f)));
      }
    } else if (empties.isNotEmpty && rng.nextDouble() < 0.75) {
      final i = empties[rng.nextInt(empties.length)];
      final n = min(4 + rng.nextInt(3), ((gap - 7) / 3.2).floor() + 1);
      for (var k = 0; k < n; k++) {
        entities.add(Entity(Kind.coin, (i - 1) * laneW, at + 3 + k * 3.2, 0.9));
      }
    }
    _nextRowAt = at + gap;
  }

  /// A row of three lanes. At least one lane is always passable (not tall);
  /// with [needEmpty] at least one lane is fully empty.
  static List<Cell> genRow(Random r, double d, {bool needEmpty = false}) {
    Cell ob() => r.nextDouble() < 0.5 - 0.15 * d ? Cell.low : Cell.tall;
    final roll = r.nextDouble();
    final List<Cell> row;
    if (roll < 0.45 - 0.25 * d) {
      row = [Cell.empty, Cell.empty, Cell.empty]..[r.nextInt(3)] = ob();
    } else if (roll < 0.85 - 0.1 * d || needEmpty) {
      row = [ob(), ob(), ob()]..[r.nextInt(3)] = Cell.empty;
    } else {
      // Full wall: at least one block must be jumpable.
      row = [ob(), ob(), ob()];
      if (!row.contains(Cell.low)) row[r.nextInt(3)] = Cell.low;
    }
    return row;
  }

  static bool passable(List<Cell> row) => row.any((c) => c != Cell.tall);
}

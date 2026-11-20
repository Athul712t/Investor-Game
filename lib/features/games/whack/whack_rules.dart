import 'dart:math';

enum TileKind { coin, offer, bag, scam, boost }

class WhackTile {
  WhackTile(this.hole, this.kind, this.label, this.life);
  final int hole;
  final TileKind kind;
  final String label;
  final double life;
  double age = 0;
  bool get isReal => kind == TileKind.coin || kind == TileKind.offer || kind == TileKind.bag;
}

class TapOutcome {
  const TapOutcome(this.tile, this.points, {this.lifeLost = false, this.comboStep = false});
  final WhackTile tile;
  final int points;
  final bool lifeLost, comboStep;
}

class StepResult {
  final expired = <WhackTile>[];
  final spawned = <WhackTile>[];
}

const whackHoles = 9;
const whackMaxTiles = 3;
const whackMaxLives = 5;
const _ramp = 30.0;

double _ease(double t) => (t / _ramp).clamp(0.0, 1.0);

/// Seconds a tile stays up, by elapsed run time: 1.1 s shrinking to 0.55 s.
double tileLifetime(double t) => 1.1 - 0.55 * _ease(t);

/// Share of scam tiles among regular tiles: 25 percent rising to 45 percent.
double scamShare(double t) => 0.25 + 0.2 * _ease(t);

/// Points multiplier from the current combo (x1, x2 from 8, x3 from 16).
int comboMultiplier(int combo) => 1 + min(2, combo ~/ 8);

/// Pure rules of Scam Whack: spawning, tapping, expiry, lives, combo and the clock.
class WhackRules {
  WhackRules(this.rng, {required this.offers, required this.scams});
  final Random rng;
  final List<String> offers, scams;

  final tiles = <WhackTile>[];
  int lives = 3, combo = 0, score = 0, coins = 0;
  double time = 0, duration = 30, slowT = 0, doubleT = 0;
  double _spawnT = 0.4, _boostT = 10;
  bool _first = true;

  double get remaining => max(0, duration - time);
  bool get over => lives <= 0 || time >= duration;

  String _pick(List<String> l) => l[rng.nextInt(l.length)];

  /// Spawns one tile if there is room. Never exceeds [whackMaxTiles] or reuses an occupied hole.
  WhackTile? spawn({bool boost = false}) {
    if (tiles.length >= whackMaxTiles) return null;
    final free = [
      for (var i = 0; i < whackHoles; i++)
        if (!tiles.any((t) => t.hole == i)) i,
    ];
    if (free.isEmpty) return null;
    final hole = free[rng.nextInt(free.length)];
    final slow = slowT > 0 ? 1.6 : 1.0;
    final WhackTile tile;
    if (boost) {
      tile = WhackTile(hole, TileKind.boost, '', 2.0 * slow);
    } else {
      final life = tileLifetime(time) * slow;
      if (!_first && rng.nextDouble() < scamShare(time)) {
        tile = WhackTile(hole, TileKind.scam, _pick(scams), life);
      } else {
        final r = rng.nextDouble();
        tile = r < 0.25
            ? WhackTile(hole, TileKind.coin, '', life)
            : r < 0.35
            ? WhackTile(hole, TileKind.bag, '', life)
            : WhackTile(hole, TileKind.offer, _pick(offers), life);
      }
      _first = false;
    }
    tiles.add(tile);
    return tile;
  }

  /// Advances the clock, ages tiles, expires them and spawns new ones.
  StepResult step(double dt) {
    final res = StepResult();
    if (over) return res;
    time += dt;
    slowT = max(0, slowT - dt);
    doubleT = max(0, doubleT - dt);
    final rate = slowT > 0 ? 1 / 1.6 : 1.0;
    for (final t in List.of(tiles)) {
      t.age += dt * rate;
      if (t.age >= t.life) {
        tiles.remove(t);
        res.expired.add(t);
        if (t.isReal) combo = 0; // a missed good tile only costs the combo
      }
    }
    _spawnT -= dt;
    _boostT -= dt;
    if (_boostT <= 0 && remaining > 4) {
      final b = spawn(boost: true);
      if (b != null) {
        res.spawned.add(b);
        _boostT = 10 + rng.nextDouble() * 2;
      }
    }
    if (_spawnT <= 0 && !over) {
      final t = spawn();
      if (t != null) {
        res.spawned.add(t);
        _spawnT = tileLifetime(time) * (0.4 + 0.25 * rng.nextDouble());
      } else {
        _spawnT = 0.05;
      }
    }
    return res;
  }

  /// Player taps [hole]. Null when the hole is empty.
  TapOutcome? tap(int hole) {
    if (over) return null;
    final i = tiles.indexWhere((t) => t.hole == hole);
    if (i < 0) return null;
    final t = tiles.removeAt(i);
    switch (t.kind) {
      case TileKind.scam:
        lives--;
        combo = 0;
        return TapOutcome(t, 0, lifeLost: true);
      case TileKind.boost:
        return TapOutcome(t, 0);
      default:
        final base = switch (t.kind) {
          TileKind.coin => 3,
          TileKind.bag => 5,
          _ => 1,
        };
        if (t.kind == TileKind.coin) coins++;
        combo++;
        final pts = base * comboMultiplier(combo) * (doubleT > 0 ? 2 : 1);
        score += pts;
        return TapOutcome(t, pts, comboStep: combo % 5 == 0);
    }
  }

  void slowMo() => slowT = 6;
  void doubleScore() => doubleT = 8;
  void extraLife() => lives = min(whackMaxLives, lives + 1);

  /// +1 life, +6 seconds, empty grid. Score is kept.
  void revive() {
    lives = min(whackMaxLives, max(0, lives) + 1);
    duration = max(duration, time) + 6;
    combo = 0;
    tiles.clear();
    _spawnT = 0.6;
  }
}

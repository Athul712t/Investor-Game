import 'dart:math';

/// Pure rules of Brick Bank: no Flame, no canvas. Unit tested.

const maxBounceAngle = 1.05; // radians from straight up (about 60 degrees)
const minVerticalFraction = 0.28; // |vy| never drops below this share of the speed

/// Velocity after the ball meets the paddle. [hit] is -1 (left edge) .. 1 (right edge).
(double, double) paddleBounce(double hit, double speed) {
  final a = hit.clamp(-1.0, 1.0) * maxBounceAngle;
  return (speed * sin(a), -speed * cos(a));
}

/// Keeps the speed constant and stops near-horizontal loops.
(double, double) fixVelocity(double vx, double vy, double speed) {
  final minVy = speed * minVerticalFraction;
  if (vy.abs() < minVy) {
    vy = (vy == 0 ? -1.0 : vy.sign) * minVy;
    vx = vx.sign * sqrt(max(0.0, speed * speed - vy * vy));
    if (vx == 0) vx = speed * 0.1;
  }
  final m = sqrt(vx * vx + vy * vy);
  return m == 0 ? (0, -speed) : (vx / m * speed, vy / m * speed);
}

/// Ball speed in px/s, rising slowly per level and capped.
double ballSpeed(int level, {int difficulty = 1, double scale = 1}) =>
    min(560.0, 400.0 + 14.0 * (level - 1)) * (0.92 + 0.04 * difficulty) * scale;

enum BrickType { normal, steel, gold, vault }

extension BrickInfo on BrickType {
  int get hits => switch (this) {
    BrickType.normal || BrickType.gold => 1,
    BrickType.steel => 2,
    BrickType.vault => 3,
  };
  int get points => switch (this) {
    BrickType.normal || BrickType.gold => 10,
    BrickType.steel => 25,
    BrickType.vault => 50,
  };
}

class Brick {
  Brick(this.col, this.row, this.type) : hp = type.hits;
  final int col, row;
  final BrickType type;
  int hp;

  /// Returns true when this hit destroys the brick.
  bool hit() => --hp <= 0;
}

/// Score multiplier: grows every 3 bricks hit without touching the paddle.
int comboMultiplier(int combo) => 1 + min(combo ~/ 3, 7);

/// Lives of one run. [loseLife] returns true when the run is over.
class Lives {
  Lives([this.count = 3]);
  int count;
  static const max = 5;

  bool loseLife() => --count <= 0;
  void add() => count = min(max, count + 1);
}

enum _Pattern { rows, checker, pyramid, columns }

/// Bricks of a level on a [cols] x [maxRows] grid. Denser with every level.
List<Brick> generateLevel(int level, int cols, int maxRows, Random rng) {
  final rows = max(1, min(maxRows, 4 + level ~/ 2));
  final pattern = _Pattern.values[(level - 1 + (level > 4 ? rng.nextInt(2) : 0)) % _Pattern.values.length];
  final out = <Brick>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final on = switch (pattern) {
        _Pattern.rows => true,
        _Pattern.checker => (r + c).isEven,
        _Pattern.pyramid => (c - (cols - 1) / 2).abs() <= r + 0.5,
        _Pattern.columns => c % 3 != 2,
      };
      if (!on) continue;
      final roll = rng.nextDouble();
      final steel = min(0.45, 0.08 + 0.04 * level);
      final type = roll < 0.03 && level >= 2
          ? BrickType.vault
          : roll < 0.03 + 0.07
          ? BrickType.gold
          : roll < 0.1 + steel
          ? BrickType.steel
          : BrickType.normal;
      out.add(Brick(c, r, type));
    }
  }
  if (out.isEmpty) out.add(Brick(cols ~/ 2, 0, BrickType.normal));
  return out;
}

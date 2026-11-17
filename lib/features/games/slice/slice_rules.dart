import 'dart:math';

/// Plain-Dart rules of Coin Slash, kept free of Flame so they can be unit tested.
enum SliceKind { bronze, silver, gold, bag, piggy, mini, bomb, orb }

/// True when the segment a-b touches the circle (tangent counts, a segment fully inside counts).
bool segmentHitsCircle(double ax, double ay, double bx, double by, double cx, double cy, double r) {
  final dx = bx - ax, dy = by - ay;
  final l2 = dx * dx + dy * dy;
  final t = l2 == 0 ? 0.0 : (((cx - ax) * dx + (cy - ay) * dy) / l2).clamp(0.0, 1.0);
  final px = ax + t * dx - cx, py = ay + t * dy - cy;
  return px * px + py * py <= r * r + 1e-9;
}

/// Slow drags (aiming, resting a finger) must not slice. Speed in px per second.
bool isSwipeFast(double len, double dt, {double minSpeed = 500}) => len / max(dt, 1 / 240) >= minSpeed;

/// Counts slices of one continuous swipe. A swipe ends when the finger lifts or stays slow for [idleGap].
class SwipeTracker {
  SwipeTracker({this.idleGap = 0.25});
  final double idleGap;
  int count = 0;
  bool active = false;
  double _lastFast = -99;

  /// Feed one pointer step. Returns true when it was fast enough to slice.
  bool move(double len, double dt, double now) {
    final fast = isSwipeFast(len, dt);
    if (fast) {
      _lastFast = now;
      active = true;
    } else if (active && now - _lastFast > idleGap) {
      end();
    }
    return fast;
  }

  /// Register one finished slice. Bonus makes the combo total equal the count: 3 at the third slice, +1 after.
  ({int count, int bonus}) hit() {
    count++;
    return (count: count, bonus: count == 3 ? 3 : (count > 3 ? 1 : 0));
  }

  void end() {
    count = 0;
    active = false;
  }
}

/// Outcome of slicing a bomb. A shield defuses it: no life lost, no clear.
({int lives, bool shield, bool cleared}) resolveBomb(int lives, bool shield) =>
    shield ? (lives: lives, shield: false, cleared: false) : (lives: lives - 1, shield: false, cleared: true);

int streakMultiplier(int streak) => min(4, 1 + streak ~/ 10);

/// Objects of one wave. Never only bombs; size and bomb share ramp up with game time [t] (seconds), capped.
List<SliceKind> planWave(Random rng, double t) {
  final n = 1 + rng.nextInt(min(5, 2 + t ~/ 20));
  final bombP = min(0.3, 0.06 + t / 600);
  final kinds = List.generate(n, (_) {
    if (rng.nextDouble() < bombP) return SliceKind.bomb;
    final r = rng.nextInt(100);
    if (r < 42) return SliceKind.bronze;
    if (r < 70) return SliceKind.silver;
    if (r < 80) return SliceKind.gold;
    if (r < 88) return SliceKind.bag;
    return SliceKind.piggy;
  });
  if (kinds.every((k) => k == SliceKind.bomb)) kinds[0] = SliceKind.silver;
  return kinds;
}

double waveGap(double t) => max(0.6, 1.7 - t / 100);

/// Height (y, screen coordinates) where a toss peaks: inside the upper two thirds, below the HUD.
double tossPeakY(Random rng, double h) {
  final top = max(130.0, h * 0.2), bottom = max(top + 1, h * 0.55);
  return top + rng.nextDouble() * (bottom - top);
}

/// Launch speed (px/s, upwards positive) so the arc started at [startY] peaks at [peakY] under gravity [g].
double tossVy(double g, double startY, double peakY) => sqrt(2 * g * max(0.0, startY - peakY));

double peakOf(double g, double startY, double vy) => startY - vy * vy / (2 * g);

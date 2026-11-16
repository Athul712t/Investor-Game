import 'dart:math';
import 'dart:ui';

/// Pure rules of Candle Hop: no Flame, no canvas, so they can be unit tested.

const flapHud = 90.0; // host HUD height
const flapGroundInset = 190.0; // ground line distance from the bottom of the screen
const flapMargin = 34.0; // min distance between a wick tip and the playfield edge
const flapSpacing = 250.0; // horizontal distance between candle pairs
const candleBodyW = 56.0;
const candleWickW = 8.0;
const candleTail = 14.0; // wick sticks out of the body toward the gap

/// Gap height after [n] candles passed, capped so it always stays playable.
double gapFor(int n, double field) => min(max(150.0, 270.0 - 3.0 * n), field * 0.62);

/// Scroll speed (px/s) after [n] candles passed.
double speedFor(int n) => min(200.0, 120.0 + 2.5 * n);

/// Largest change of the gap centre between two pairs that the player can still follow at [speed]:
/// a tap-spamming rocket climbs about 140 px/s, we ask for 70 percent of that.
double maxGapStep(double speed) => min(200.0, 0.7 * 140.0 * flapSpacing / speed);

/// Centre of the first gap and of every later one: a smooth random walk (like a price line) pulled gently to the middle.
double nextCentre(double prev, Random rng, int n, double top, double bottom) {
  final gap = gapFor(n, bottom - top);
  final lo = top + flapMargin + gap / 2, hi = bottom - flapMargin - gap / 2;
  if (n == 0) return (lo + hi) / 2;
  final step = maxGapStep(speedFor(n));
  final u1 = 1 - rng.nextDouble(), u2 = rng.nextDouble();
  final gauss = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  final d = (gauss * step * 0.45 + ((lo + hi) / 2 - prev) * 0.08).clamp(-step, step);
  return (prev + d).clamp(lo, hi).toDouble();
}

class CandlePair {
  CandlePair({
    required this.x,
    required this.centre,
    required this.gap,
    required this.index,
    this.greenTop = true,
    this.greenBottom = false,
    this.lenTop = 0.6,
    this.lenBottom = 0.6,
  });
  double x; // screen x of the centre line
  final double centre, gap;
  final int index; // 1-based
  final bool greenTop, greenBottom;
  final double lenTop, lenBottom; // body length as a fraction of the candle
  bool passed = false;
  double minClear = double.infinity;

  bool get golden => index % 10 == 0;
  double get gapTop => centre - gap / 2;
  double get gapBottom => centre + gap / 2;

  /// Body span (top, bottom) of the hanging and of the rising candle.
  (double, double) bodyTop() {
    final len = (gapTop * lenTop).clamp(40.0, gapTop - candleTail).toDouble();
    return (gapTop - candleTail - len, gapTop - candleTail);
  }

  (double, double) bodyBottom(double ground) {
    final len = ((ground - gapBottom) * lenBottom).clamp(40.0, ground - gapBottom - candleTail).toDouble();
    return (gapBottom + candleTail, gapBottom + candleTail + len);
  }

  /// Solid parts (wick and body of each candle) for [ground] being the y of the ground line.
  List<Rect> rects(double ground) {
    final t = bodyTop(), b = bodyBottom(ground);
    return [
      Rect.fromLTRB(x - candleWickW / 2, -20, x + candleWickW / 2, gapTop),
      Rect.fromLTRB(x - candleBodyW / 2, t.$1, x + candleBodyW / 2, t.$2),
      Rect.fromLTRB(x - candleWickW / 2, gapBottom, x + candleWickW / 2, ground + 20),
      Rect.fromLTRB(x - candleBodyW / 2, b.$1, x + candleBodyW / 2, b.$2),
    ];
  }
}

/// Distance from the edge of a circle to a rectangle (negative when they overlap).
double clearance(Rect r, double cx, double cy, double radius) {
  final dx = max(max(r.left - cx, 0.0), cx - r.right);
  final dy = max(max(r.top - cy, 0.0), cy - r.bottom);
  return sqrt(dx * dx + dy * dy) - radius;
}

double pairClearance(CandlePair p, double ground, double cx, double cy, double radius) =>
    p.rects(ground).map((r) => clearance(r, cx, cy, radius)).reduce(min);

/// What a hit does: a shield absorbs it once, otherwise the run ends.
({bool shield, bool dead}) resolveHit({required bool shield}) => (shield: false, dead: !shield);

/// Marks pairs the rocket has flown past and returns only the newly passed ones, so each candle scores once.
List<CandlePair> collectPassed(List<CandlePair> pairs, double rocketX) {
  final out = <CandlePair>[];
  for (final p in pairs) {
    if (!p.passed && p.x + candleBodyW / 2 < rocketX) {
      p.passed = true;
      out.add(p);
    }
  }
  return out;
}

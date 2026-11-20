import 'dart:math';

/// Fixed physics step. The sim always advances in these slices so a run is deterministic.
const dunkStep = 1 / 120;
const dunkRunSeconds = 45.0;
const dunkMaxLives = 5;

/// Screen-space geometry and tuning (y grows downwards).
class DunkField {
  DunkField(this.w, this.h)
    : k = (w / 390).clamp(0.8, 1.3).toDouble(),
      gravity = h * 1.5,
      maxSpeed = h * 1.75,
      startY = min(h * 0.70, h - 200);

  final double w, h, k, gravity, maxSpeed, startY;
  double get startX => w / 2;
  double get coinR => 16 * k;
  double get rimR => 5 * k;
  double get grabRadius => 80;
  double get maxDrag => 120 * k;
  double get minDrag => 26;
  double get hoopMinY => h * 0.18;
  double get hoopMaxY => h * 0.45;
  double ringHalf(int baskets) => (46 - min(baskets, 14) * 0.6) * k;
  double hoopMargin(double half) => half + rimR + 22 * k;
}

class DunkHoop {
  const DunkHoop(this.x, this.y, this.half);
  final double x, y, half;
}

/// Launch velocity from a drag displacement (finger moved by dx, dy from where it touched down).
/// Dragging down and back flicks up and forward; speed is capped.
({double vx, double vy})? launchVelocity(DunkField f, double dx, double dy) {
  final len = sqrt(dx * dx + dy * dy);
  if (len < f.minDrag || dy <= 0) return null;
  final power = min(len, f.maxDrag) / f.maxDrag;
  final s = f.maxSpeed * power / len;
  return (vx: -dx * s, vy: -dy * s);
}

/// The lob (high arc, descending at the target) launching from the start spot with the given speed.
({double vx, double vy})? solveLaunch(DunkField f, double tx, double ty, double speed) {
  final x = tx - f.startX, y = f.startY - ty; // y up
  final g = f.gravity, v2 = speed * speed;
  final disc = v2 * v2 - g * (g * x * x + 2 * y * v2);
  if (disc < 0) return null;
  if (x.abs() < 1e-6) return v2 >= 2 * g * y ? (vx: 0, vy: -speed) : null;
  final tan = (v2 + sqrt(disc)) / (g * x.abs());
  final c = 1 / sqrt(1 + tan * tan);
  return (vx: speed * c * x.sign, vy: -speed * c * tan);
}

/// A launch within the allowed power that swishes through the hoop, found by simulating; null if none exists.
({double vx, double vy, double speed})? findLaunch(DunkField f, DunkHoop hoop) {
  for (final frac in const [0.62, 0.7, 0.78, 0.86, 0.94]) {
    final speed = f.maxSpeed * frac;
    final v = solveLaunch(f, hoop.x, hoop.y, speed);
    if (v == null) continue;
    final sim = DunkSim(f, hoop)..launch(v.vx, v.vy);
    while (sim.flying) {
      sim.advance(1 / 30);
      if (sim.events.contains(DunkEvent.swish)) return (vx: v.vx, vy: v.vy, speed: speed);
    }
  }
  return null;
}

bool hoopReachable(DunkField f, double x, double y) => findLaunch(f, DunkHoop(x, y, f.ringHalf(0))) != null;

/// New hoop: further and wider ranging as baskets pile up, always reachable and away from the last one.
DunkHoop nextHoop(DunkField f, Random rng, int baskets, DunkHoop? prev) {
  final half = f.ringHalf(baskets);
  final m = f.hoopMargin(half);
  final spread = (0.3 + baskets * 0.07).clamp(0.3, 1.0);
  final mid = f.w / 2;
  final yMid = (f.hoopMinY + f.hoopMaxY) / 2, yHalf = (f.hoopMaxY - f.hoopMinY) / 2 * (0.5 + 0.5 * spread);
  for (var i = 0; i < 40; i++) {
    final x = (mid + (rng.nextDouble() * 2 - 1) * (f.w / 2 - m) * spread).clamp(m, f.w - m).toDouble();
    final y = yMid + (rng.nextDouble() * 2 - 1) * yHalf;
    if (prev != null && (x - prev.x).abs() + (y - prev.y).abs() < 90 * f.k) continue;
    if (hoopReachable(f, x, y)) return DunkHoop(x, y, half);
  }
  return DunkHoop(mid, yMid, half);
}

enum DunkEvent { rim, wall, basket, swish, miss }

/// One coin in flight. Steps in fixed slices; swept circle checks against the two rim ends so a fast coin never tunnels.
class DunkSim {
  DunkSim(this.f, this.hoop) {
    reset();
  }

  final DunkField f;
  DunkHoop hoop;
  double x = 0, y = 0, vx = 0, vy = 0, angle = 0, spin = 0, flight = 0;
  bool flying = false, rimTouched = false, scored = false;
  double _acc = 0;
  final events = <DunkEvent>[];

  void reset() {
    x = f.startX;
    y = f.startY;
    vx = vy = angle = spin = flight = _acc = 0;
    flying = rimTouched = scored = false;
  }

  void launch(double vx, double vy) {
    reset();
    this.vx = vx;
    this.vy = vy;
    spin = (vx >= 0 ? 1 : -1) * 6;
    flying = true;
  }

  /// Advances by [dt] seconds; the events that happened land in [events] (cleared first).
  void advance(double dt) {
    events.clear();
    if (!flying) return;
    _acc += dt;
    while (_acc >= dunkStep && flying) {
      _acc -= dunkStep;
      _step(dunkStep);
    }
  }

  void _step(double h) {
    flight += h;
    final px = x, py = y;
    vy += f.gravity * h;
    var nx = px + vx * h, ny = py + vy * h;

    // Rim ends: earliest swept entry into the expanded circle, then reflect.
    final rr = f.coinR + f.rimR;
    var hitT = 2.0;
    var hitCx = 0.0;
    // Rim ends only catch a falling coin: a rising one passes up through the ring.
    for (final cx in vy > 0 ? [hoop.x - hoop.half, hoop.x + hoop.half] : const <double>[]) {
      final t = _sweepCircle(px, py, nx - px, ny - py, cx, hoop.y, rr);
      if (t != null && t < hitT) {
        hitT = t;
        hitCx = cx;
      }
    }
    if (hitT <= 1) {
      final cx = px + (nx - px) * hitT, cy = py + (ny - py) * hitT;
      var nX = cx - hitCx, nY = cy - hoop.y;
      final nl = sqrt(nX * nX + nY * nY);
      nX /= nl;
      nY /= nl;
      final vn = vx * nX + vy * nY;
      if (vn < 0) {
        vx -= 1.55 * vn * nX;
        vy -= 1.55 * vn * nY;
        vx *= 0.97;
        spin = -spin * 0.6 + vx * 0.01;
      }
      nx = cx + nX * 0.01 + vx * h * (1 - hitT);
      ny = cy + nY * 0.01 + vy * h * (1 - hitT);
      rimTouched = true;
      events.add(DunkEvent.rim);
    }

    if (nx < f.coinR) {
      nx = f.coinR;
      vx = vx.abs() * 0.72;
      events.add(DunkEvent.wall);
    } else if (nx > f.w - f.coinR) {
      nx = f.w - f.coinR;
      vx = -vx.abs() * 0.72;
      events.add(DunkEvent.wall);
    }

    // One-way basket: centre crosses the ring line downward between the rim ends.
    if (!scored && py < hoop.y && ny >= hoop.y && vy > 0) {
      final xc = px + (nx - px) * ((hoop.y - py) / (ny - py));
      if ((xc - hoop.x).abs() < hoop.half) {
        scored = true;
        events.add(rimTouched ? DunkEvent.basket : DunkEvent.swish);
      }
    }

    x = nx;
    y = ny;
    angle += spin * h;
    if (y > f.h + f.coinR * 3 || flight > 12) {
      flying = false;
      if (!scored) events.add(DunkEvent.miss);
    }
  }

  /// Smallest t in [0,1] where the segment p + d*t first enters circle (c, r) from outside, else null.
  static double? _sweepCircle(double px, double py, double dx, double dy, double cx, double cy, double r) {
    final fx = px - cx, fy = py - cy;
    final c = fx * fx + fy * fy - r * r;
    if (c <= 0) return 0; // already overlapping: resolve as a hit at the start
    final a = dx * dx + dy * dy;
    if (a == 0) return null;
    final b = 2 * (fx * dx + fy * dy);
    final disc = b * b - 4 * a * c;
    if (disc < 0) return null;
    final t = (-b - sqrt(disc)) / (2 * a);
    return t >= 0 && t <= 1 ? t : null;
  }
}

int streakMultiplier(int streak) => min(3, 1 + streak ~/ 3);

/// Score, streak, lives and clock of a run.
class DunkRun {
  int lives = 3, streak = 0, baskets = 0;
  double timeLeft = dunkRunSeconds;

  bool get over => lives <= 0 || timeLeft <= 0;

  /// Returns the points for this basket (base 1, swish 2, times streak multiplier, times 2 when doubled).
  int basket({required bool swish, bool doubled = false}) {
    streak++;
    baskets++;
    return (swish ? 2 : 1) * streakMultiplier(streak) * (doubled ? 2 : 1);
  }

  void miss() {
    streak = 0;
    lives--;
  }

  void tick(double dt) => timeLeft = max(0, timeLeft - dt);

  void addLife() => lives = min(dunkMaxLives, lives + 1);

  void revive() {
    lives = min(dunkMaxLives, max(0, lives) + 1);
    timeLeft += 10;
    streak = 0;
  }
}

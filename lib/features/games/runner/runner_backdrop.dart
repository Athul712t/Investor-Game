import '../_shared/arcade_colors.dart';

import 'dart:math';
import 'dart:ui';

/// Perspective camera shared by the backdrop and the game. Metres in, pixels out.
class Cam {
  static const d0 = 10.0; // depth at which things appear half size
  double w = 1, h = 1, hy = 0, py = 0, cx = 0, ppu = 1, camX = 0;

  void resize(double width, double height) {
    w = width;
    h = height;
    hy = h * 0.34;
    py = h * 0.68;
    cx = w / 2;
    ppu = min(w * 0.43, (py - hy) * 0.75) / 4.5;
  }

  double k(double z) => d0 / (d0 + z);
  Offset p(double x, double y, double z) {
    final s = k(z);
    return Offset(cx + (x - camX) * ppu * s, hy + ((py - hy) - y * ppu) * s);
  }

  /// Depth (negative) at which the ground meets the bottom edge of the screen.
  double get zBottom => d0 * (py - hy) / (h - hy) - d0;
}

double _hash(int i) {
  final v = sin(i * 12.9898 + 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

class _Building {
  _Building(this.x, this.w, this.h, this.windows, this.sign);
  final double x, w, h; // x and w as fractions of screen width, h of screen height
  final List<Offset> windows; // fractions inside the building
  final Color? sign;
}

/// Sky, stars, skyline, horizon chart, ground grid, road and lamps.
class Backdrop {
  Backdrop() {
    final r = Random(11);
    for (var i = 0; i < 70; i++) {
      _stars.add((Offset(r.nextDouble(), r.nextDouble()), r.nextDouble()));
    }
    _far = _city(r, 0.05, 0.14, 0.75);
    _near = _city(r, 0.025, 0.085, 0.45);
  }

  final _stars = <(Offset, double)>[];
  late final List<_Building> _far, _near;
  static const _signs = [
    ArcadeColors.mint,
    ArcadeColors.coral,
    ArcadeColors.violet,
    ArcadeColors.sky,
    ArcadeColors.amber,
  ];

  static List<_Building> _city(Random r, double minH, double maxH, double litChance) {
    final out = <_Building>[];
    var x = -0.3;
    while (x < 1.3) {
      final bw = 0.05 + r.nextDouble() * 0.09;
      final bh = minH + r.nextDouble() * (maxH - minH);
      final win = <Offset>[
        for (var wy = 0.12; wy < 0.92; wy += 0.11)
          for (var wx = 0.18; wx < 0.85; wx += 0.22)
            if (r.nextDouble() < litChance * 0.35) Offset(wx, wy),
      ];
      final sign = r.nextDouble() < 0.28 ? _signs[r.nextInt(_signs.length)] : null;
      out.add(_Building(x, bw, bh, win, sign));
      x += bw + r.nextDouble() * 0.015;
    }
    return out;
  }

  void render(Canvas c, Cam cam, double t, double distance) {
    final w = cam.w, h = cam.h, hy = cam.hy;
    final skyTop = ArcadeColors.ink;
    final skyLow = Color.lerp(ArcadeColors.ink, ArcadeColors.violet, 0.32)!;
    c.drawRect(
      Rect.fromLTWH(0, 0, w, hy + 1),
      Paint()..shader = Gradient.linear(Offset.zero, Offset(0, hy), [skyTop, skyTop, skyLow], [0, 0.35, 1]),
    );

    // Stars, twinkling.
    final star = Paint();
    for (final (i, (o, phase)) in _stars.indexed) {
      final a = 0.25 + 0.55 * (0.5 + 0.5 * sin(t * (1 + phase * 2) + i));
      star.color = ArcadeColors.text.withValues(alpha: a * (1 - o.dy * 0.6));
      c.drawCircle(Offset(o.dx * w, o.dy * hy * 0.85), 0.6 + phase * 1.1, star);
    }

    // Horizon glow.
    c.drawRect(
      Rect.fromLTWH(0, 0, w, hy + h * 0.2),
      Paint()
        ..shader = Gradient.radial(Offset(cam.cx, hy), max(w, h) * 0.55, [
          ArcadeColors.violet.withValues(alpha: 0.38),
          ArcadeColors.violet.withValues(alpha: 0.0),
        ]),
    );

    _chart(c, cam, t);
    _skyline(c, cam, _far, Color.lerp(ArcadeColors.ink, ArcadeColors.violet, 0.28)!, 0.4, t);
    _skyline(c, cam, _near, Color.lerp(ArcadeColors.ink, ArcadeColors.surface, 0.55)!, 1.0, t);

    // Ground.
    c.drawRect(
      Rect.fromLTWH(0, hy, w, h - hy),
      Paint()
        ..shader = Gradient.linear(Offset(0, hy), Offset(0, h), [
          Color.lerp(ArcadeColors.ink, ArcadeColors.violet, 0.18)!,
          ArcadeColors.ink,
        ]),
    );
    _grid(c, cam, distance);
    _road(c, cam, distance);
    // Bright horizon line sells the distance.
    c.drawLine(
      Offset(0, hy),
      Offset(w, hy),
      Paint()
        ..color = ArcadeColors.mint.withValues(alpha: 0.35)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  /// A rising price line on the horizon, scrolling left forever.
  void _chart(Canvas c, Cam cam, double t) {
    double v(double i) {
      final n = i.floor();
      final f = i - n;
      double raw(int j) => j * 0.45 + (_hash(j) - 0.5) * 3.2;
      return raw(n) + (raw(n + 1) - raw(n)) * f;
    }

    const pts = 34;
    final step = cam.w / (pts - 2);
    final pos = t * 1.1;
    final base = v(pos);
    final kpx = cam.h * 0.16 / (pts * 0.45);
    final baseY = cam.hy - cam.h * 0.025;
    final line = Path();
    final first = pos.floor();
    for (var j = 0; j <= pts; j++) {
      final i = first + j;
      final x = (i - pos) * step;
      final y = baseY - (v(i.toDouble()) - base) * kpx;
      j == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
    }
    final fill = Path.from(line)
      ..lineTo(cam.w + step * 2, cam.hy)
      ..lineTo(-step, cam.hy)
      ..close();
    c.drawPath(
      fill,
      Paint()
        ..shader = Gradient.linear(Offset(0, cam.hy - cam.h * 0.2), Offset(0, cam.hy), [
          ArcadeColors.mint.withValues(alpha: 0.13),
          ArcadeColors.mint.withValues(alpha: 0.0),
        ]),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      line,
      stroke
        ..color = ArcadeColors.mint.withValues(alpha: 0.28)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.drawPath(
      line,
      stroke
        ..color = ArcadeColors.mint.withValues(alpha: 0.55)
        ..strokeWidth = 1.6
        ..maskFilter = null,
    );
  }

  void _skyline(Canvas c, Cam cam, List<_Building> city, Color color, double depth, double t) {
    final shift = -cam.camX * 6 * depth;
    final body = Paint()..color = color;
    final win = Paint();
    for (final b in city) {
      final left = b.x * cam.w + shift;
      final bw = b.w * cam.w, bh = b.h * cam.h;
      if (left > cam.w || left + bw < 0) continue;
      final rect = Rect.fromLTWH(left, cam.hy - bh, bw, bh + 1);
      c.drawRect(rect, body);
      for (final (i, o) in b.windows.indexed) {
        final flick = 0.55 + 0.45 * sin(t * 0.7 + i * 3.1 + b.x * 40);
        win.color = (i.isEven ? ArcadeColors.amber : ArcadeColors.sky).withValues(alpha: 0.32 * flick * depth + 0.08);
        c.drawRect(Rect.fromLTWH(rect.left + o.dx * bw, rect.top + o.dy * bh, max(1.5, bw * 0.1), 2.2), win);
      }
      if (b.sign != null) {
        final s = Rect.fromLTWH(rect.left + bw * 0.2, rect.top + 3, bw * 0.6, 3.5 * depth + 1.5);
        c.drawRect(
          s.inflate(2),
          Paint()
            ..color = b.sign!.withValues(alpha: 0.45 * depth)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        c.drawRect(s, Paint()..color = b.sign!.withValues(alpha: 0.5 + 0.4 * depth));
      }
    }
  }

  void _grid(Canvas c, Cam cam, double distance) {
    final p = Paint()..strokeWidth = 1;
    final zb = cam.zBottom;
    for (final gx in const [7.5, 11.0, 15.5, 21.0, 28.0, 38.0, 52.0]) {
      for (final sx in const [-1.0, 1.0]) {
        p.color = ArcadeColors.violet.withValues(alpha: 0.28);
        c.drawLine(cam.p(sx * gx, 0, 300), cam.p(sx * gx, 0, zb), p);
      }
    }
    const spacing = 8.0;
    final off = distance % spacing;
    for (var z = zb - off + spacing; z < 140; z += spacing) {
      final a = (1 - z / 140).clamp(0.0, 1.0);
      p.color = ArcadeColors.violet.withValues(alpha: 0.26 * a);
      final y = cam.p(0, 0, z).dy;
      c.drawLine(Offset(0, y), Offset(cam.w, y), p);
    }
  }

  void _road(Canvas c, Cam cam, double distance) {
    const half = 4.6, far = 400.0;
    final zb = cam.zBottom;
    final road = Path()
      ..moveTo(cam.p(-half, 0, far).dx, cam.p(-half, 0, far).dy)
      ..lineTo(cam.p(half, 0, far).dx, cam.p(half, 0, far).dy)
      ..lineTo(cam.p(half, 0, zb).dx, cam.p(half, 0, zb).dy)
      ..lineTo(cam.p(-half, 0, zb).dx, cam.p(-half, 0, zb).dy)
      ..close();
    c.drawPath(
      road,
      Paint()
        ..shader = Gradient.linear(Offset(0, cam.hy), Offset(0, cam.h), [
          ArcadeColors.ink,
          Color.lerp(ArcadeColors.surface, ArcadeColors.ink, 0.15)!,
        ]),
    );

    // Alternating bands rushing toward the camera give a strong sense of speed.
    const band = 12.0;
    final band0 = zb - (distance % (band * 2));
    final bandPaint = Paint()..color = ArcadeColors.text.withValues(alpha: 0.03);
    for (var z = band0; z < 150; z += band * 2) {
      _quad(c, cam, -half, half, z, z + band, bandPaint);
    }

    // Dashed lane dividers.
    const dash = 3.2, period = 8.0;
    final dOff = distance % period;
    final glow = Paint()..color = ArcadeColors.mint.withValues(alpha: 0.18);
    for (final lx in const [-1.5, 1.5]) {
      for (var z = zb - dOff; z < 130; z += period) {
        final a = (1 - z / 130).clamp(0.0, 1.0);
        final core = Paint()..color = ArcadeColors.mint.withValues(alpha: 0.85 * a);
        _quad(c, cam, lx - 0.16, lx + 0.16, z, z + dash, glow);
        _quad(c, cam, lx - 0.06, lx + 0.06, z, z + dash, core);
      }
    }

    // Neon road edges.
    for (final ex in const [-half, half]) {
      final a = cam.p(ex, 0, far), b = cam.p(ex, 0, zb);
      c.drawLine(
        a,
        b,
        Paint()
          ..color = ArcadeColors.violet.withValues(alpha: 0.7)
          ..strokeWidth = 7
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      c.drawLine(
        a,
        b,
        Paint()
          ..color = Color.lerp(ArcadeColors.violet, ArcadeColors.text, 0.35)!
          ..strokeWidth = 2.2,
      );
    }
  }

  /// Flat ground quad between depths [z0] and [z1], clipped to the visible ground.
  static void _quad(Canvas c, Cam cam, double x0, double x1, double z0, double z1, Paint p) {
    z0 = max(z0, cam.zBottom);
    if (z1 <= z0) return;
    final a = cam.p(x0, 0, z0), b = cam.p(x1, 0, z0), d = cam.p(x1, 0, z1), e = cam.p(x0, 0, z1);
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(d.dx, d.dy)
        ..lineTo(e.dx, e.dy)
        ..close(),
      p,
    );
  }

  /// Street lamps on both sides, drawn back to front before the entities.
  void lamps(Canvas c, Cam cam, double distance) {
    const spacing = 16.0, lx = 6.4, pole = 4.6;
    const colors = [ArcadeColors.mint, ArcadeColors.violet, ArcadeColors.amber, ArcadeColors.sky];
    final firstIdx = ((distance + cam.zBottom) / spacing).ceil();
    final lastIdx = ((distance + 130) / spacing).floor();
    for (var i = lastIdx; i >= firstIdx; i--) {
      final z = i * spacing - distance;
      final a = (1 - z / 130).clamp(0.0, 1.0);
      for (final sx in const [-1.0, 1.0]) {
        final col = colors[(i + (sx > 0 ? 2 : 0)) % colors.length];
        final base = cam.p(sx * lx, 0, z), top = cam.p(sx * lx, pole, z);
        final arm = cam.p(sx * (lx - 1.0), pole, z);
        final s = cam.k(z) * cam.ppu;
        c.drawOval(
          Rect.fromCenter(center: cam.p(sx * (lx - 1.4), 0, z), width: s * 3.2, height: s * 1.0),
          Paint()
            ..color = col.withValues(alpha: 0.12 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        final pp = Paint()
          ..color = Color.lerp(ArcadeColors.line, ArcadeColors.ink, 0.2)!.withValues(alpha: a)
          ..strokeWidth = max(1, s * 0.16)
          ..strokeCap = StrokeCap.round;
        c.drawLine(base, top, pp);
        c.drawLine(top, arm, pp);
        c.drawCircle(
          arm,
          s * 0.7,
          Paint()
            ..color = col.withValues(alpha: 0.5 * a)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(2, s * 0.6)),
        );
        c.drawCircle(
          arm,
          max(1, s * 0.22),
          Paint()..color = Color.lerp(col, ArcadeColors.text, 0.5)!.withValues(alpha: a),
        );
      }
    }
  }
}

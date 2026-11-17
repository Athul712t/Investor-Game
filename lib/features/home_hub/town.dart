import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';

/// What the town shows for a given profile. Pure, so it is easy to test.
class TownPlan {
  const TownPlan({required this.floors, required this.level});

  /// Lots on the 4x4 board, in the order they get built: centre first, then outward.
  static const lots = [
    (1, 1), (2, 1), (1, 2), (2, 2), //
    (0, 1), (1, 0), (3, 2), (2, 3),
    (0, 2), (2, 0), (3, 1), (1, 3),
    (0, 0), (3, 3), (3, 0), (0, 3),
  ];

  /// One building per finished lesson, plus one per two story steps. The first one
  /// (the landmark) grows with level; the rest stay shorter so it always stands out.
  factory TownPlan.of(Profile p) {
    final count = min(lots.length, p.completedLessons.length + p.storyDone.length ~/ 2);
    final tallest = (p.level + 1).clamp(2, 7);
    return TownPlan(
      floors: [for (var k = 0; k < count; k++) k == 0 ? tallest : 1 + (k * 5) % (tallest - 1)],
      level: p.level,
    );
  }

  final List<int> floors; // per building, in build order
  final int level;
  int get buildings => floors.length;
  int get tallest => floors.isEmpty ? 0 : floors.reduce(max);

  String get description => buildings == 0
      ? 'Portfolio Town. An empty plot: your town starts here. Finish a lesson or story steps to build.'
      : 'Portfolio Town: $buildings of ${lots.length} buildings, tallest $tallest floors, level $level.';
}

/// Isometric town on a raised board tile. Idle life: a drifting cloud, blinking
/// windows, a waving flag and a coin bobbing over the newest building.
class PortfolioTown extends StatefulWidget {
  const PortfolioTown({super.key, required this.plan});
  final TownPlan plan;

  @override
  State<PortfolioTown> createState() => _PortfolioTownState();
}

class _PortfolioTownState extends State<PortfolioTown> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 12), value: 0.2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.reduceMotion ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.plan.description,
    image: true,
    excludeSemantics: true,
    child: RepaintBoundary(
      child: CustomPaint(painter: _TownPainter(widget.plan, _c), size: Size.infinite),
    ),
  );
}

class _TownPainter extends CustomPainter {
  _TownPainter(this.plan, this.t) : super(repaint: t);
  final TownPlan plan;
  final Animation<double> t;

  // Design space; scaled to fit the widget.
  static const w = 330.0, h = 240.0;
  static const cw = 34.0, ch = 17.0, top = 82.0, thick = 14.0, floorH = 11.0;
  static const palette = [AppColors.blue, AppColors.red, AppColors.teal, AppColors.orange, AppColors.yellow];

  static Color shade(Color c, double k) => Color.lerp(c, AppColors.ink, k)!;
  static Offset lot(int i, int j) => Offset(w / 2 + (i - j) * cw, top + (i + j + 1) * ch);

  late Paint _stroke;
  late Canvas _canvas;

  void _poly(List<Offset> pts, Color fill) {
    final p = Path()..addPolygon(pts, true);
    _canvas
      ..drawPath(p, Paint()..color = fill)
      ..drawPath(p, _stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / w, size.height / h);
    _canvas = canvas;
    canvas
      ..save()
      ..translate((size.width - w * s) / 2, (size.height - h * s) / 2)
      ..scale(s);
    _stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.2
      ..color = AppColors.ink;
    final v = t.value;

    _cloud(Offset(-50 + (w + 100) * v, 36), 1);
    _cloud(Offset(-50 + (w + 100) * ((v + 0.55) % 1), 62), 0.7);
    _board();

    final newest = plan.buildings - 1;
    final order = [for (var k = 0; k < plan.buildings; k++) k]
      ..sort((a, b) {
        final (ai, aj) = TownPlan.lots[a];
        final (bi, bj) = TownPlan.lots[b];
        return ai + aj != bi + bj ? (ai + aj) - (bi + bj) : ai - bi;
      });
    for (final k in order) {
      final (i, j) = TownPlan.lots[k];
      _building(lot(i, j), plan.floors[k], palette[k % palette.length], k, v, flag: k == newest);
    }
    if (plan.buildings == 0) {
      _sign();
    } else {
      final (i, j) = TownPlan.lots[newest];
      final roof = lot(i, j).dy - plan.floors[newest] * floorH - 6;
      _coin(Offset(lot(i, j).dx + 14, roof - 22 + 3 * sin(v * 2 * pi * 6)), v * 2 * pi * 8);
    }
    canvas.restore();
  }

  void _cloud(Offset c, double k) {
    final puffs = [(Offset(-16 * k, 2 * k), 11 * k), (Offset(0, -5 * k), 15 * k), (Offset(17 * k, 2 * k), 10 * k)];
    final ink = Paint()..color = AppColors.ink;
    final white = Paint()..color = AppColors.card;
    final base = Rect.fromLTRB(c.dx - 26 * k, c.dy, c.dx + 27 * k, c.dy + 12 * k);
    // Outline the union by drawing ink puffs slightly larger, then white on top.
    for (final (o, r) in puffs) {
      _canvas.drawCircle(c + o, r + 2.2, ink);
    }
    _canvas.drawRRect(RRect.fromRectAndRadius(base.inflate(2.2), Radius.circular(8 * k)), ink);
    for (final (o, r) in puffs) {
      _canvas.drawCircle(c + o, r, white);
    }
    _canvas.drawRRect(RRect.fromRectAndRadius(base, Radius.circular(6 * k)), white);
  }

  void _board() {
    final n = lot(0, 0) - const Offset(0, ch), e = lot(3, 0) + const Offset(cw * 1, 0);
    final sth = lot(3, 3) + const Offset(0, ch), wst = lot(0, 3) - const Offset(cw, 0);
    const d = Offset(0, thick);
    _poly([wst, sth, sth + d, wst + d], shade(AppColors.green, 0.25));
    _poly([sth, e, e + d, sth + d], shade(AppColors.green, 0.45));
    _poly([n, e, sth, wst], AppColors.green);
    // Paved lots, so the empty plot reads as land waiting to be built on.
    for (final (i, j) in TownPlan.lots) {
      final c = lot(i, j);
      _poly([
        c - const Offset(0, ch * 0.72),
        c + const Offset(cw * 0.72, 0),
        c + const Offset(0, ch * 0.72),
        c - const Offset(cw * 0.72, 0),
      ], AppColors.paperDeep);
    }
  }

  void _building(Offset c, int floors, Color color, int seed, double v, {required bool flag}) {
    const bw = cw * 0.6, bh = ch * 0.6;
    final hgt = floors * floorH + 6;
    final l = c - const Offset(bw, 0), f = c + const Offset(0, bh), r = c + const Offset(bw, 0);
    final b = c - const Offset(0, bh);
    final up = Offset(0, hgt);
    _poly([l, f, f - up, l - up], color);
    _poly([f, r, r - up, f - up], shade(color, 0.3));
    _poly([l - up, b - up, r - up, f - up], AppColors.tint(color, 0.45));

    // Windows: two per floor per face. Each blinks on its own beat.
    final tick = (v * 36).floor();
    for (var fl = 0; fl < floors; fl++) {
      for (final (a, z, side) in [(l, f, 0), (f, r, 1)]) {
        for (final u0 in [0.2, 0.6]) {
          Offset p(double u, double y) => a + (z - a) * u - Offset(0, y);
          final y0 = 5 + fl * floorH, y1 = y0 + 6;
          final lit = (seed * 7 + fl * 13 + side * 5 + (u0 * 10).round() + tick) % 9 > 1;
          _poly([
            p(u0, y0),
            p(u0 + 0.22, y0),
            p(u0 + 0.22, y1),
            p(u0, y1),
          ], lit ? AppColors.yellow : shade(color, 0.55));
        }
      }
    }
    if (flag) {
      final foot = c - up;
      final topP = foot - const Offset(0, 24);
      _canvas.drawLine(foot, topP, _stroke);
      final wave = 3 * sin(v * 2 * pi * 12);
      _poly([topP, topP + Offset(16, 4 + wave), topP + const Offset(0, 9)], AppColors.red);
    }
  }

  void _coin(Offset c, double angle) {
    const r = 9.0;
    final face = cos(angle).abs().clamp(0.15, 1.0);
    final rim = Rect.fromCenter(center: c + const Offset(1.5, 0), width: 2 * r * face + 3, height: 2 * r);
    final front = Rect.fromCenter(center: c, width: 2 * r * face, height: 2 * r);
    _canvas
      ..drawOval(rim, Paint()..color = shade(AppColors.yellow, 0.25))
      ..drawOval(rim, _stroke)
      ..drawOval(front, Paint()..color = AppColors.yellow)
      ..drawOval(front, _stroke);
  }

  void _sign() {
    final c = lot(2, 2) - const Offset(0, 10);
    _canvas.drawLine(c, c - const Offset(0, 34), _stroke..strokeWidth = 4);
    _stroke.strokeWidth = 2.2;
    final board = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c - const Offset(0, 46), width: 112, height: 40),
      const Radius.circular(8),
    );
    _canvas
      ..drawRRect(board.shift(const Offset(0, 3)), Paint()..color = AppColors.ink)
      ..drawRRect(board, Paint()..color = AppColors.card)
      ..drawRRect(board, _stroke);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Your town\nstarts here',
        style: TextStyle(
          fontFamily: 'Baloo2',
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1,
          color: AppColors.ink,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(_canvas, board.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_TownPainter old) => old.plan != plan;
}

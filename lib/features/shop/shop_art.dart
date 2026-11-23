import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../story/story_art.dart';
import 'shop_catalog.dart';

Color _shade(Color c, double k) => Color.lerp(c, AppColors.ink, k)!;

/// Small isometric props for Portfolio Town, drawn in the same solid outlined style as its buildings.
/// [b] is the centre of the prop's footprint on the ground; [k] scales it; [t] (0..1, looping) drives sails and flags.
class DecorArt {
  DecorArt(this.canvas, this.stroke);
  final Canvas canvas;
  final Paint stroke;

  void _poly(List<Offset> pts, Color fill) {
    final p = Path()..addPolygon(pts, true);
    canvas
      ..drawPath(p, Paint()..color = fill)
      ..drawPath(p, stroke);
  }

  /// Isometric block: footprint half-width [hw], half-depth [hh], [h] tall.
  void _box(Offset b, double hw, double hh, double h, Color c) {
    final l = b - Offset(hw, 0), f = b + Offset(0, hh), r = b + Offset(hw, 0), n = b - Offset(0, hh);
    final up = Offset(0, h);
    _poly([l, f, f - up, l - up], c);
    _poly([f, r, r - up, f - up], _shade(c, 0.3));
    _poly([l - up, n - up, r - up, f - up], AppColors.tint(c, 0.4));
  }

  void _ball(Offset c, double r, Color fill) {
    canvas
      ..drawCircle(c, r, Paint()..color = fill)
      ..drawCircle(c, r, stroke);
  }

  void paint(String id, Offset b, double k, double t) {
    canvas
      ..save()
      ..translate(b.dx, b.dy)
      ..scale(k);
    final o = Offset.zero;
    switch (id) {
      case 'tree':
        _box(o, 2.6, 1.3, 9, _shade(AppColors.orange, 0.5));
        _ball(const Offset(0, -17), 9, _shade(AppColors.green, 0.2));
        _ball(const Offset(-3, -20), 7, AppColors.green);
        _ball(const Offset(5, -15), 5.5, AppColors.green);
      case 'lamp':
        _box(o, 3.5, 1.8, 3, AppColors.ink);
        canvas.drawLine(const Offset(0, -2), const Offset(0, -26), stroke..strokeWidth = 4);
        canvas.drawLine(
          const Offset(0, -2),
          const Offset(0, -26),
          Paint()
            ..color = _shade(AppColors.card, 0.2)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
        stroke.strokeWidth = 2.2;
        _box(const Offset(0, -26), 4.5, 2.2, 7, AppColors.yellow);
      case 'flag':
        _box(o, 3.5, 1.8, 3, AppColors.paperDeep);
        canvas.drawLine(const Offset(0, -2), const Offset(0, -34), stroke);
        final w = 2.5 * sin(t * 2 * pi * 12);
        _poly([
          const Offset(0, -34),
          Offset(17, -30 + w),
          Offset(14, -26 + w * 0.6),
          const Offset(0, -23),
        ], AppColors.blue);
      case 'fountain':
        _box(o, 13, 6.5, 5, AppColors.paperDeep);
        _poly([
          const Offset(-9, -5),
          const Offset(0, -9.5),
          const Offset(9, -5),
          const Offset(0, -0.5),
        ], AppColors.blue);
        _box(const Offset(0, -5), 2.4, 1.2, 8, AppColors.paperDeep);
        final drip = 1.5 * sin(t * 2 * pi * 20);
        _ball(Offset(0, -17 + drip), 2.6, AppColors.tint(AppColors.blue, 0.2));
        _ball(Offset(-5, -11 - drip), 1.8, AppColors.tint(AppColors.blue, 0.2));
        _ball(Offset(5, -11 + drip), 1.8, AppColors.tint(AppColors.blue, 0.2));
      case 'windmill':
        final top = [const Offset(-7, -26), const Offset(7, -26)];
        _poly([const Offset(-9, 3), const Offset(0, 7.5), const Offset(0, -24), top[0]], AppColors.card);
        _poly([const Offset(0, 7.5), const Offset(9, 3), top[1], const Offset(0, -24)], _shade(AppColors.card, 0.2));
        _poly([
          const Offset(-10, -25),
          const Offset(0, -33),
          const Offset(10, -25),
          const Offset(0, -20),
        ], AppColors.red);
        final hub = const Offset(0, -26);
        final spin = t * 2 * pi * 6;
        for (var i = 0; i < 4; i++) {
          final a = spin + i * pi / 2, d = Offset(cos(a), sin(a));
          final p = hub + d * 16, q = Offset(-d.dy, d.dx) * 4.5;
          _poly([hub + d * 3, p, p + q, hub + d * 3 + q], AppColors.card);
        }
        _ball(hub, 2.4, AppColors.ink);
      case 'statue':
        _box(o, 8, 4, 8, AppColors.paperDeep);
        final body = Path()
          ..moveTo(-5.5, -8)
          ..quadraticBezierTo(-2, -16, -3, -23)
          ..lineTo(3, -23)
          ..quadraticBezierTo(2, -16, 5.5, -8)
          ..close();
        canvas
          ..drawPath(body, Paint()..color = AppColors.yellow)
          ..drawPath(body, stroke);
        _ball(const Offset(0, -27), 5, AppColors.yellow);
        canvas.drawCircle(const Offset(-1.6, -28.5), 1.2, Paint()..color = AppColors.card);
    }
    canvas.restore();
  }
}

/// Shop card art: one painter for every item id, no emoji.
class ItemArt extends StatelessWidget {
  const ItemArt(this.id, {super.key, this.size = 64});
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ItemPainter(id)),
    ),
  );
}

class _ItemPainter extends CustomPainter {
  const _ItemPainter(this.id);
  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..color = AppColors.ink;
    final s = size.width / 64;
    if (id.startsWith('pawn_')) {
      canvas
        ..translate(size.width * 0.22, size.height * 0.1)
        ..scale(0.9 * s);
      PawnPainter(pawnColor(id)).paint(canvas, const Size(36, 52));
      return;
    }
    canvas.scale(s);
    switch (id) {
      case 'freeze':
        _snowflake(canvas, stroke);
      case 'headstart3':
        _rocket(canvas, stroke);
      default:
        // Props are drawn about 40 high; scale them up to fill the 64 box.
        final k = switch (id) {
          'fountain' => 2.0,
          'windmill' => 1.5,
          'statue' || 'tree' => 1.6,
          _ => 1.7,
        };
        canvas
          ..drawOval(
            Rect.fromCenter(center: const Offset(32, 54), width: 44, height: 12),
            Paint()..color = AppColors.track,
          )
          ..drawOval(Rect.fromCenter(center: const Offset(32, 54), width: 44, height: 12), stroke);
        DecorArt(canvas, stroke).paint(id, const Offset(32, 52), k, 0.1);
    }
  }

  void _snowflake(Canvas canvas, Paint stroke) {
    const c = Offset(32, 32);
    canvas
      ..drawCircle(c, 28, Paint()..color = AppColors.tint(AppColors.blue, 0.55))
      ..drawCircle(c, 28, stroke);
    final arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (paint, w) in [(AppColors.ink, 6.0), (AppColors.card, 3.0)]) {
      arm
        ..color = paint
        ..strokeWidth = w;
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3, d = Offset(cos(a), sin(a));
        canvas.drawLine(c, c + d * 19, arm);
        final m = c + d * 12, n = Offset(-d.dy, d.dx);
        canvas
          ..drawLine(m, m + (d + n) * 5.5, arm)
          ..drawLine(m, m + (d - n) * 5.5, arm);
      }
    }
  }

  void _rocket(Canvas canvas, Paint stroke) {
    canvas
      ..save()
      ..translate(32, 32)
      ..rotate(pi / 4)
      ..translate(-32, -32);
    void shape(Path p, Color c) => canvas
      ..drawPath(p, Paint()..color = c)
      ..drawPath(p, stroke);
    shape(
      Path()
        ..moveTo(24, 40)
        ..lineTo(12, 52)
        ..lineTo(14, 36)
        ..close(),
      AppColors.red,
    );
    shape(
      Path()
        ..moveTo(40, 40)
        ..lineTo(52, 52)
        ..lineTo(50, 36)
        ..close(),
      AppColors.red,
    );
    shape(
      Path()
        ..moveTo(26, 52)
        ..lineTo(32, 64)
        ..lineTo(38, 52)
        ..close(),
      AppColors.yellow,
    );
    shape(
      Path()
        ..moveTo(32, 2)
        ..quadraticBezierTo(46, 16, 40, 50)
        ..lineTo(24, 50)
        ..quadraticBezierTo(18, 16, 32, 2)
        ..close(),
      AppColors.card,
    );
    shape(
      Path()
        ..moveTo(32, 2)
        ..quadraticBezierTo(39, 8, 41, 20)
        ..lineTo(23, 20)
        ..quadraticBezierTo(25, 8, 32, 2)
        ..close(),
      AppColors.red,
    );
    canvas
      ..drawCircle(const Offset(32, 32), 6, Paint()..color = AppColors.blue)
      ..drawCircle(const Offset(32, 32), 6, stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_ItemPainter old) => old.id != id;
}

/// Home tile pictogram: a market stall with a striped awning and a coin on the counter.
class StallPainter extends CustomPainter {
  const StallPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.4
      ..color = AppColors.ink;
    void poly(List<double> xy, Color fill) {
      final p = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        p.lineTo(xy[i], xy[i + 1]);
      }
      p.close();
      canvas
        ..drawPath(p, Paint()..color = fill)
        ..drawPath(p, stroke);
    }

    poly([18, 44, 22, 90, 78, 90, 82, 44], AppColors.card);
    poly([14, 62, 86, 62, 86, 74, 14, 74], AppColors.orange);
    canvas
      ..drawCircle(const Offset(50, 50), 8, Paint()..color = AppColors.yellow)
      ..drawCircle(const Offset(50, 50), 8, stroke);
    poly([6, 40, 16, 12, 84, 12, 94, 40], AppColors.red);
    for (final x in [28.0, 50.0, 72.0]) {
      poly([x - 6, 12, x + 5, 12, x + 7, 40, x - 8, 40], AppColors.card);
    }
    canvas.drawLine(const Offset(6, 40), const Offset(94, 40), stroke);
  }

  @override
  bool shouldRepaint(_) => false;
}

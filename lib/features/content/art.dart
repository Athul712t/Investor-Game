import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/theme.dart';

/// Runs a spring on an unbounded controller from its current value, so a second tap interrupts the first cleanly.
extension SpringRun on AnimationController {
  TickerFuture springTo(double to, {SpringDescription spring = AppMotion.spring, double velocity = 0}) =>
      animateWith(SpringSimulation(spring, value, to, velocity));
}

Path starPath(Offset c, double outer, [double inner = 0.5]) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : outer * inner;
    final a = -pi / 2 + i * pi / 5;
    final o = c + Offset(cos(a) * r, sin(a) * r);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Outlined five-point star, solid fill.
class StarPainter extends CustomPainter {
  const StarPainter(this.fill);
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = starPath(size.center(Offset.zero), size.width * 0.47, 0.5);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(StarPainter old) => old.fill != fill;
}

/// A medal on a V ribbon. [child] sits in the middle of the disc; without one the disc shows a star.
class Medal extends StatelessWidget {
  const Medal({super.key, required this.size, required this.core, this.child});
  final double size;
  final Color core;
  final Widget? child;

  double get _h => size * 1.18;
  double get _r => size * 0.36;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: _h,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MedalPainter(core, child == null))),
          if (child != null)
            Positioned(
              left: 0,
              right: 0,
              top: _h - 6 - 2 * _r,
              height: 2 * _r,
              child: Center(child: child),
            ),
        ],
      ),
    ),
  );
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter(this.core, this.withStar);
  final Color core;
  final bool withStar;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, r = w * 0.36;
    final c = Offset(w / 2, h - r - 6);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;
    void ribbon(List<Offset> pts, Color fill) {
      final p = Path()..addPolygon(pts, true);
      canvas.drawPath(p, Paint()..color = fill);
      canvas.drawPath(p, edge);
    }

    ribbon([Offset(w * 0.18, 0), Offset(w * 0.46, 0), Offset(w * 0.66, c.dy), Offset(w * 0.4, c.dy)], AppColors.blue);
    ribbon([Offset(w * 0.54, 0), Offset(w * 0.82, 0), Offset(w * 0.6, c.dy), Offset(w * 0.34, c.dy)], AppColors.red);
    canvas.drawCircle(c.translate(0, w * 0.04), r, Paint()..color = AppColors.ink); // hard shadow
    canvas.drawCircle(c, r, Paint()..color = AppColors.yellow);
    canvas.drawCircle(c, r, edge);
    canvas.drawCircle(c, r * 0.72, Paint()..color = core);
    canvas.drawCircle(c, r * 0.72, edge..strokeWidth = w * 0.025);
    if (withStar) {
      final s = starPath(c, r * 0.5);
      canvas.drawPath(s, Paint()..color = AppColors.card);
      canvas.drawPath(s, edge);
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.core != core;
}

/// Shelf of mini medals, one per lesson, grouped by module. Earned ones are solid colour with a star.
class MedalShelf extends StatelessWidget {
  const MedalShelf({super.key, required this.groups});
  final List<(Color, List<bool>)> groups;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (_, box) {
        final n = groups.fold<int>(0, (a, g) => a + g.$2.length);
        final r = n == 0 ? 10.0 : (((box.maxWidth - 14.0 * (groups.length - 1) - 6 * n) / n) / 2).clamp(6.0, 14.0);
        return CustomPaint(size: Size(box.maxWidth, 2 * r + 20), painter: _ShelfPainter(groups, r));
      },
    ),
  );
}

class _ShelfPainter extends CustomPainter {
  _ShelfPainter(this.groups, this.r);
  final List<(Color, List<bool>)> groups;
  final double r;

  @override
  void paint(Canvas canvas, Size size) {
    final plank = RRect.fromRectAndRadius(Rect.fromLTWH(0, 2 * r + 5, size.width, 9), const Radius.circular(5));
    canvas.drawRRect(plank.shift(const Offset(0, 3)), Paint()..color = AppColors.ink);
    canvas.drawRRect(plank, Paint()..color = AppColors.yellow);
    canvas.drawRRect(
      plank,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.ink,
    );
    final n = groups.fold<int>(0, (a, g) => a + g.$2.length);
    final total = n * (2 * r + 6) + 14.0 * (groups.length - 1);
    var x = (size.width - total) / 2 + r + 3;
    for (final (color, slots) in groups) {
      for (final earned in slots) {
        final c = Offset(x, r + 2);
        final edge = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = earned ? AppColors.ink : AppColors.inkDim;
        canvas.drawCircle(c, r, Paint()..color = earned ? color : AppColors.paperDeep);
        canvas.drawCircle(c, r, edge);
        if (earned) {
          final s = starPath(c, r * 0.58);
          canvas.drawPath(s, Paint()..color = AppColors.card);
          canvas.drawPath(s, edge..strokeWidth = 1.4);
        }
        x += 2 * r + 6;
      }
      x += 14;
    }
  }

  @override
  bool shouldRepaint(_ShelfPainter old) => true;
}

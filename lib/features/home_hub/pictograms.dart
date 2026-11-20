import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Bold, ink-outlined pictograms drawn in code (chrome icons: no emoji, no icon font).
enum Pic { home, story, arcade, learn, profile, flame, reel }

class Pictogram extends StatelessWidget {
  const Pictogram(this.pic, {super.key, this.size = 28, this.color = AppColors.yellow});
  final Pic pic;
  final double size;
  final Color color; // main fill; details use fixed palette colours

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _PicPainter(pic, color)),
  );
}

class _PicPainter extends CustomPainter {
  _PicPainter(this.pic, this.color);
  final Pic pic;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw in a 100x100 box; keep the outline about 2px at tab size and 3.5px at tile size.
    final k = size.width / 100;
    canvas.scale(k);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (size.width < 40 ? 2.2 : 3.6) / k
      ..color = AppColors.ink;
    void shape(Path p, Color fill) => canvas
      ..drawPath(p, Paint()..color = fill)
      ..drawPath(p, stroke);
    Path poly(List<double> xy) {
      final p = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        p.lineTo(xy[i], xy[i + 1]);
      }
      return p..close();
    }

    switch (pic) {
      case Pic.home:
        shape(poly([22, 48, 78, 48, 78, 88, 22, 88]), AppColors.card);
        shape(poly([10, 54, 50, 14, 90, 54]), color);
        shape(poly([42, 64, 58, 64, 58, 88, 42, 88]), AppColors.ink);
      case Pic.story:
        // Open book with a dotted path across the pages ending in a flag.
        shape(poly([6, 30, 50, 38, 50, 88, 6, 80]), AppColors.card);
        shape(poly([94, 30, 50, 38, 50, 88, 94, 80]), AppColors.card);
        final path = Path()
          ..moveTo(16, 70)
          ..quadraticBezierTo(34, 46, 50, 62)
          ..quadraticBezierTo(66, 78, 80, 52);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
        canvas.drawLine(const Offset(80, 52), const Offset(80, 14), stroke);
        shape(poly([80, 14, 98, 21, 80, 28]), AppColors.red);
      case Pic.arcade:
        shape(Path()..addRRect(RRect.fromLTRBR(10, 60, 90, 90, const Radius.circular(12))), color);
        shape(poly([45, 34, 55, 34, 55, 64, 45, 64]), AppColors.ink);
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(50, 28), radius: 17)), AppColors.red);
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(25, 75), radius: 7)), AppColors.card);
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(75, 75), radius: 7)), AppColors.card);
      case Pic.learn:
        final cap = Path()
          ..moveTo(26, 46)
          ..lineTo(26, 72)
          ..quadraticBezierTo(50, 86, 74, 72)
          ..lineTo(74, 46)
          ..close();
        shape(cap, AppColors.ink);
        shape(poly([4, 38, 50, 16, 96, 38, 50, 60]), color);
        canvas.drawPath(
          Path()
            ..moveTo(50, 38)
            ..lineTo(86, 46)
            ..lineTo(86, 68),
          stroke,
        );
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(86, 72), radius: 7)), AppColors.yellow);
      case Pic.profile:
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(50, 32), radius: 18)), AppColors.card);
        shape(
          Path()
            ..moveTo(14, 90)
            ..quadraticBezierTo(14, 56, 50, 56)
            ..quadraticBezierTo(86, 56, 86, 90)
            ..close(),
          color,
        );
      case Pic.flame:
        final outer = Path()
          ..moveTo(50, 6)
          ..cubicTo(78, 34, 88, 52, 84, 68)
          ..cubicTo(80, 86, 64, 94, 50, 94)
          ..cubicTo(36, 94, 18, 86, 16, 66)
          ..cubicTo(14, 50, 28, 40, 34, 26)
          ..cubicTo(40, 38, 44, 40, 50, 6)
          ..close();
        shape(outer, color);
        final inner = Path()
          ..moveTo(50, 46)
          ..cubicTo(64, 60, 68, 72, 62, 82)
          ..cubicTo(56, 90, 44, 90, 38, 82)
          ..cubicTo(32, 72, 40, 62, 50, 46)
          ..close();
        shape(inner, AppColors.yellow);
      case Pic.reel:
        // Phone with a card on screen, the next card peeking below, and a swipe-up chevron.
        RRect r(double l, double t, double rt, double b, double rad) =>
            RRect.fromLTRBR(l, t, rt, b, Radius.circular(rad));
        shape(Path()..addRRect(r(22, 4, 78, 96, 13)), AppColors.card);
        shape(Path()..addRRect(r(30, 70, 70, 88, 6)), AppColors.teal);
        shape(Path()..addRRect(r(30, 14, 70, 62, 7)), color);
        canvas.drawLine(const Offset(44, 9), const Offset(56, 9), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(39, 45)
            ..lineTo(50, 33)
            ..lineTo(61, 45),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = AppColors.ink,
        );
    }
  }

  @override
  bool shouldRepaint(_PicPainter old) => old.pic != pic || old.color != color;
}

/// Round medal with ribbon tails and the level number in display type.
class LevelMedal extends StatelessWidget {
  const LevelMedal({super.key, required this.level, this.size = 60});
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Level $level',
    excludeSemantics: true,
    child: CustomPaint(size: Size(size, size * 1.12), painter: _MedalPainter(level)),
  );
}

class _MedalPainter extends CustomPainter {
  _MedalPainter(this.level);
  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final ink = Paint()..color = AppColors.ink;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = AppSpace.outline
      ..color = AppColors.ink;
    void shape(Path p, Color c) => canvas
      ..drawPath(p, Paint()..color = c)
      ..drawPath(p, stroke);

    // Ribbon tails behind the disc.
    for (final (dx, c) in [(-1.0, AppColors.green), (1.0, AppColors.red)]) {
      final x = w / 2 + dx * w * 0.2;
      shape(
        Path()
          ..moveTo(x - w * 0.12, w * 0.6)
          ..lineTo(x + w * 0.12, w * 0.6)
          ..lineTo(x + w * 0.12 + dx * w * 0.06, size.height - 1)
          ..lineTo(x + dx * w * 0.03, size.height - w * 0.1)
          ..lineTo(x - w * 0.12 + dx * w * 0.06, size.height - 1)
          ..close(),
        c,
      );
    }
    final c = Offset(w / 2, w * 0.44);
    final r = w * 0.42;
    canvas.drawCircle(c.translate(0, 3), r, ink); // hard shadow
    shape(Path()..addOval(Rect.fromCircle(center: c, radius: r)), AppColors.yellow);
    shape(Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.74)), AppColors.orange);
    // Notched ring: small ticks around the rim read as a struck medal.
    for (var i = 0; i < 16; i++) {
      final a = i * pi / 8;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r * 0.87, w * 0.018, ink);
    }
    final text = '$level';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Baloo2',
          fontWeight: FontWeight.w800,
          fontSize: r * (text.length > 2 ? 0.75 : 1.0),
          height: 1,
          color: AppColors.ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2 - r * 0.04));
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.level != level;
}

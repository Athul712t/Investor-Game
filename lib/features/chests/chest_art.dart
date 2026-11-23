import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'chest_logic.dart';

/// Wood, silver and gold paint jobs for the same chest shape.
({Color body, Color band}) chestColors(ChestType t) => switch (t) {
  ChestType.wood => (body: Color.lerp(AppColors.orange, AppColors.ink, 0.42)!, band: AppColors.yellow),
  ChestType.silver => (body: Color.lerp(AppColors.inkDim, AppColors.card, 0.55)!, band: AppColors.blue),
  ChestType.gold => (body: AppColors.yellow, band: AppColors.orange),
};

Color chestAccent(ChestType t) => switch (t) {
  ChestType.wood => AppColors.orange,
  ChestType.silver => AppColors.blue,
  ChestType.gold => AppColors.yellow,
};

Color _side(Color c) => Color.lerp(c, AppColors.ink, 0.3)!;

void _piece(Canvas canvas, Path p, Color fill, {double stroke = AppSpace.outline}) {
  canvas.drawPath(p, Paint()..color = fill);
  canvas.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink,
  );
}

Path _rr(double l, double t, double r, double b, [double rad = 4]) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

/// A closed chest, 140x120 design box, scaled to fit. [stack] draws up to three, each behind and above the last.
class ChestPicto extends CustomPainter {
  const ChestPicto(this.type, {this.stack = 1});
  final ChestType type;
  final int stack;

  @override
  void paint(Canvas canvas, Size size) {
    final c = chestColors(type);
    final n = stack.clamp(1, 3);
    // Design box is 140x120; stacked copies sit 18 further out, so shrink to leave room.
    final w = 140.0 + (n - 1) * 18, h = 120.0 + (n - 1) * 14;
    final s = size.width / w < size.height / h ? size.width / w : size.height / h;
    canvas
      ..translate((size.width - w * s) / 2, (size.height - h * s) / 2)
      ..scale(s);
    for (var i = n - 1; i >= 0; i--) {
      // Back copies are drawn first, higher and further right.
      canvas
        ..save()
        ..translate(i * 18.0, (n - 1 - i) * 14.0);
      _closed(canvas, c.body, c.band);
      canvas.restore();
    }
  }

  void _closed(Canvas canvas, Color body, Color band) {
    _piece(canvas, _rr(0, 44, 140, 120, 8), body);
    final plank = Paint()
      ..strokeWidth = 2
      ..color = _side(body);
    canvas.drawLine(const Offset(5, 72), const Offset(135, 72), plank);
    canvas.drawLine(const Offset(5, 96), const Offset(135, 96), plank);
    final lid = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          -4,
          0,
          144,
          50,
          topLeft: const Radius.circular(34),
          topRight: const Radius.circular(34),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
      );
    _piece(canvas, lid, body);
    canvas.save();
    canvas.clipPath(lid);
    for (final x in [16.0, 110.0]) {
      _piece(canvas, Path()..addRect(Rect.fromLTWH(x, -4, 14, 120)), band);
    }
    canvas.restore();
    canvas.drawPath(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSpace.outline
        ..color = AppColors.ink,
    );
    _piece(canvas, _rr(56, 36, 84, 70, 6), band);
    canvas.drawCircle(const Offset(70, 49), 4, Paint()..color = AppColors.ink);
    canvas.drawRect(const Rect.fromLTWH(68.5, 49, 3, 11), Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(ChestPicto old) => old.type != type || old.stack != stack;
}

/// The open chest body, 140x120: back rim, dark mouth and a heap of coins when [open].
class ChestBodyPainter extends CustomPainter {
  const ChestBodyPainter(this.type, {required this.open});
  final ChestType type;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final c = chestColors(type);
    if (open) {
      _piece(canvas, _rr(4, 0, 136, 50, 8), _side(c.body));
      _piece(canvas, _rr(12, 8, 128, 50, 4), AppColors.ink);
      for (final (x, y) in [(40.0, 32.0), (62.0, 27.0), (86.0, 27.0), (104.0, 33.0), (52.0, 42.0), (76.0, 40.0)]) {
        _piece(canvas, Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: 9)), AppColors.yellow, stroke: 2);
      }
    }
    _piece(canvas, _rr(0, 44, 140, 120, 8), c.body);
    final plank = Paint()
      ..strokeWidth = 2
      ..color = _side(c.body);
    canvas.drawLine(const Offset(5, 72), const Offset(135, 72), plank);
    canvas.drawLine(const Offset(5, 96), const Offset(135, 96), plank);
    _piece(canvas, _rr(16, 44, 30, 120, 2), c.band);
    _piece(canvas, _rr(110, 44, 124, 120, 2), c.band);
    _piece(canvas, _rr(56, 52, 84, 84, 6), c.band);
    canvas.drawCircle(const Offset(70, 64), 4, Paint()..color = AppColors.ink);
    canvas.drawRect(const Rect.fromLTWH(68.5, 64, 3, 11), Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(ChestBodyPainter old) => old.type != type || old.open != open;
}

/// The lid, 148x46. Past upright we see its plain inside.
class ChestLidPainter extends CustomPainter {
  const ChestLidPainter(this.type, {required this.inside});
  final ChestType type;
  final bool inside;

  @override
  void paint(Canvas canvas, Size size) {
    final c = chestColors(type);
    final lid = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          0,
          0,
          size.width,
          size.height,
          topLeft: const Radius.circular(34),
          topRight: const Radius.circular(34),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
      );
    if (inside) {
      _piece(canvas, lid, _side(c.body));
      return;
    }
    _piece(canvas, lid, c.body);
    canvas.save();
    canvas.clipPath(lid);
    for (final x in [20.0, 114.0]) {
      _piece(canvas, Path()..addRect(Rect.fromLTWH(x, -4, 14, size.height + 8)), c.band);
    }
    canvas.restore();
    canvas.drawPath(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSpace.outline
        ..color = AppColors.ink,
    );
    _piece(canvas, _rr(62, 28, 86, 50, 5), c.band);
  }

  @override
  bool shouldRepaint(ChestLidPainter old) => old.type != type || old.inside != inside;
}

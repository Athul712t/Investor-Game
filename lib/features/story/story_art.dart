import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

// Flat painted pieces for Story Mode: the pawn, board set pieces, character busts.
// Every shape is a solid fill with an ink outline; depth comes from hard offset shadows.

final _ink = Paint()..color = AppColors.ink;
Paint _stroke([double w = AppSpace.outline]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = AppColors.ink;

/// Fills [p] with an ink outline, after a hard ink shadow [shadow] px below.
void piece(Canvas canvas, Path p, Color fill, {double shadow = 0, double stroke = AppSpace.outline}) {
  if (shadow > 0) canvas.drawPath(p.shift(Offset(0, shadow)), _ink);
  canvas.drawPath(p, Paint()..color = fill);
  canvas.drawPath(p, _stroke(stroke));
}

Path _oval(Offset c, double w, double h) => Path()..addOval(Rect.fromCenter(center: c, width: w, height: h));
Path _rect(double l, double t, double r, double b, [double radius = 3]) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

/// Shade of [c] for the side faces of a piece.
Color side(Color c) => Color.lerp(c, AppColors.ink, 0.3)!;

final _bark = Color.lerp(AppColors.orange, AppColors.ink, 0.5)!;

/// A board-game pawn standing on a round base. Paints into a 36x52 box.
class PawnPainter extends CustomPainter {
  const PawnPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 36, size.height / 52);
    // Base: a short drum.
    piece(canvas, _oval(const Offset(18, 46), 32, 11), side(color));
    canvas.drawRect(const Rect.fromLTRB(2, 41, 34, 46), Paint()..color = side(color));
    canvas.drawLine(const Offset(2, 41), const Offset(2, 46), _stroke());
    canvas.drawLine(const Offset(34, 41), const Offset(34, 46), _stroke());
    piece(canvas, _oval(const Offset(18, 41), 32, 11), color);
    // Body: flared cone up to the collar.
    final body = Path()
      ..moveTo(7, 41)
      ..quadraticBezierTo(14, 34, 13, 22)
      ..lineTo(23, 22)
      ..quadraticBezierTo(22, 34, 29, 41)
      ..close();
    piece(canvas, body, color);
    piece(canvas, _oval(const Offset(18, 22), 18, 6), color);
    piece(canvas, _oval(const Offset(18, 12), 19, 19), color);
    // Flat highlight, no gradient.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(14, 8.5), width: 5, height: 4),
      Paint()..color = AppColors.card,
    );
    canvas.drawLine(
      const Offset(10.5, 29),
      const Offset(11.5, 37),
      _stroke(2.5)..color = Color.lerp(color, AppColors.card, 0.55)!,
    );
  }

  @override
  bool shouldRepaint(PawnPainter old) => old.color != color;
}

enum SetPiece { tree, stall, bank, bush }

/// Small scenery standees beside the board path. Paints into a 64x64 box.
class SetPiecePainter extends CustomPainter {
  const SetPiecePainter(this.kind);
  final SetPiece kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    // Every standee sits on a flat base.
    piece(canvas, _oval(const Offset(32, 57), 58, 12), AppColors.track, shadow: 3);
    switch (kind) {
      case SetPiece.tree:
        piece(canvas, _rect(28, 34, 36, 58, 2), _bark);
        final crown = Path.combine(
          PathOperation.union,
          Path.combine(PathOperation.union, _oval(const Offset(32, 18), 30, 28), _oval(const Offset(21, 32), 24, 20)),
          _oval(const Offset(43, 32), 24, 20),
        );
        piece(canvas, crown, AppColors.green);
        canvas.drawArc(
          const Rect.fromLTWH(22, 9, 14, 12),
          pi * 1.05,
          pi * 0.5,
          false,
          _stroke(2)..color = AppColors.card,
        );
      case SetPiece.bush:
        final bush = Path.combine(
          PathOperation.union,
          Path.combine(PathOperation.union, _oval(const Offset(22, 46), 26, 22), _oval(const Offset(42, 46), 26, 22)),
          _oval(const Offset(32, 38), 24, 22),
        );
        piece(canvas, bush, side(AppColors.green));
        for (final o in const [Offset(24, 42), Offset(38, 36), Offset(42, 48)]) {
          piece(canvas, _oval(o, 6, 6), AppColors.red, stroke: 1.5);
        }
      case SetPiece.stall:
        piece(canvas, _rect(10, 20, 13, 54, 1), _bark);
        piece(canvas, _rect(51, 20, 54, 54, 1), _bark);
        piece(canvas, _rect(6, 38, 58, 56, 3), AppColors.orange);
        for (final (o, c) in const [
          (Offset(18, 36), AppColors.green),
          (Offset(27, 35), AppColors.yellow),
          (Offset(36, 36), AppColors.red),
          (Offset(45, 35), AppColors.green),
        ]) {
          piece(canvas, _oval(o, 9, 9), c, stroke: 1.5);
        }
        // Striped awning with a scalloped edge.
        final awning = Path()
          ..moveTo(4, 22)
          ..lineTo(12, 8)
          ..lineTo(52, 8)
          ..lineTo(60, 22);
        for (var i = 0; i < 4; i++) {
          final x = 60 - i * 14.0;
          awning.arcToPoint(Offset(x - 14, 22), radius: const Radius.circular(7));
        }
        awning.close();
        canvas.drawPath(awning.shift(const Offset(0, 3)), _ink);
        canvas.drawPath(awning, Paint()..color = AppColors.card);
        canvas.save();
        canvas.clipPath(awning);
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(Rect.fromLTWH(4 + i * 14.0, 0, 7, 32), Paint()..color = AppColors.red);
        }
        canvas.restore();
        canvas.drawPath(awning, _stroke());
      case SetPiece.bank:
        piece(canvas, _rect(6, 48, 58, 56, 2), AppColors.paperDeep);
        piece(canvas, _rect(10, 24, 54, 49, 1), AppColors.card);
        for (var i = 0; i < 4; i++) {
          final x = 14.0 + i * 10.5;
          canvas.drawRect(Rect.fromLTWH(x, 27, 6, 20), Paint()..color = AppColors.paperDeep);
          canvas.drawRect(Rect.fromLTWH(x, 27, 6, 20), _stroke(1.5));
        }
        final roof = Path()
          ..moveTo(4, 25)
          ..lineTo(32, 6)
          ..lineTo(60, 25)
          ..close();
        piece(canvas, roof, AppColors.teal, shadow: 2);
        piece(canvas, _oval(const Offset(32, 18), 9, 9), AppColors.yellow, stroke: 1.5);
    }
  }

  @override
  bool shouldRepaint(SetPiecePainter old) => old.kind != kind;
}

/// Who a [BustPainter] draws.
enum Cast { asha, kabir, you }

/// A paper-cutout character from the chest up. Paints into a 140x150 box.
/// [talking] opens the mouth (toggled while the line types out).
class BustPainter extends CustomPainter {
  const BustPainter(this.who, this.color, {this.talking = false});
  final Cast who;
  final Color color;
  final bool talking;

  static final _skin = {
    Cast.asha: Color.lerp(AppColors.orange, AppColors.ink, 0.38)!,
    Cast.kabir: Color.lerp(AppColors.orange, AppColors.paperDeep, 0.45)!,
    Cast.you: Color.lerp(AppColors.orange, AppColors.card, 0.42)!,
  };
  static final _hair = {
    Cast.asha: AppColors.ink,
    Cast.kabir: Color.lerp(AppColors.ink, AppColors.orange, 0.35)!,
    Cast.you: Color.lerp(AppColors.ink, AppColors.red, 0.3)!,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 140, size.height / 150);
    final skin = _skin[who]!, hair = _hair[who]!;

    // Asha's long hair falls behind her shoulders.
    if (who == Cast.asha) piece(canvas, _rect(36, 40, 104, 118, 26), hair);

    // Shoulders and neck.
    const round = Radius.circular(44);
    piece(
      canvas,
      Path()..addRRect(RRect.fromLTRBAndCorners(14, 108, 126, 149, topLeft: round, topRight: round)),
      color,
    );
    piece(canvas, _rect(58, 88, 82, 116, 6), skin);
    switch (who) {
      case Cast.asha: // blazer lapels over a white shirt
        final shirt = Path()
          ..moveTo(54, 109)
          ..lineTo(70, 136)
          ..lineTo(86, 109)
          ..close();
        piece(canvas, shirt, AppColors.card);
        final lapels = Path()
          ..moveTo(50, 110)
          ..lineTo(70, 140)
          ..lineTo(54, 149)
          ..moveTo(90, 110)
          ..lineTo(70, 140)
          ..lineTo(86, 149);
        canvas.drawPath(lapels, _stroke(3));
      case Cast.kabir: // round-neck tee with a stripe
        piece(canvas, _oval(const Offset(70, 110), 30, 14), skin);
        canvas.drawLine(const Offset(22, 134), const Offset(118, 134), _stroke(7)..color = AppColors.yellow);
        canvas.drawLine(const Offset(20, 130), const Offset(120, 130), _stroke(2));
        canvas.drawLine(const Offset(17, 138), const Offset(123, 138), _stroke(2));
      case Cast.you: // hoodie with drawstrings
        piece(canvas, _rect(44, 100, 96, 118, 9), side(color));
        canvas.drawLine(const Offset(62, 116), const Offset(60, 138), _stroke(3));
        canvas.drawLine(const Offset(78, 116), const Offset(80, 138), _stroke(3));
    }

    // Head with ears.
    piece(canvas, _oval(const Offset(38, 64), 14, 18), skin);
    piece(canvas, _oval(const Offset(102, 64), 14, 18), skin);
    piece(canvas, _oval(const Offset(70, 60), 64, 72), skin);

    // Hair on top.
    switch (who) {
      case Cast.asha:
        piece(canvas, _oval(const Offset(70, 18), 30, 24), hair); // bun
        final top = Path()
          ..moveTo(37, 62)
          ..cubicTo(34, 18, 106, 18, 103, 62)
          ..quadraticBezierTo(90, 40, 66, 34)
          ..quadraticBezierTo(52, 44, 37, 62)
          ..close();
        piece(canvas, top, hair);
        piece(canvas, _oval(const Offset(38, 78), 6, 6), AppColors.yellow, stroke: 1.5);
        piece(canvas, _oval(const Offset(102, 78), 6, 6), AppColors.yellow, stroke: 1.5);
      case Cast.kabir:
        final spikes = Path()..moveTo(37, 58);
        const tips = [(42.0, 18.0), (54.0, 30.0), (60.0, 10.0), (72.0, 28.0), (82.0, 8.0), (90.0, 30.0), (104.0, 20.0)];
        for (final (i, (x, y)) in tips.indexed) {
          spikes.lineTo(x, y);
          if (i < tips.length - 1) spikes.lineTo(x + 6, 36);
        }
        spikes
          ..lineTo(103, 58)
          ..quadraticBezierTo(70, 38, 37, 58)
          ..close();
        piece(canvas, spikes, hair);
      case Cast.you:
        final top = Path()
          ..moveTo(37, 58)
          ..cubicTo(32, 20, 108, 20, 103, 58)
          ..quadraticBezierTo(96, 44, 84, 42)
          ..quadraticBezierTo(62, 50, 46, 40)
          ..quadraticBezierTo(42, 48, 37, 58)
          ..close();
        piece(canvas, top, hair);
    }

    // Face.
    final blush = Paint()..color = Color.lerp(AppColors.red, skin, 0.55)!;
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 76), width: 12, height: 7), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(90, 76), width: 12, height: 7), blush);
    if (who == Cast.kabir) {
      // Sunglasses.
      piece(canvas, _rect(44, 56, 66, 70, 5), AppColors.ink);
      piece(canvas, _rect(74, 56, 96, 70, 5), AppColors.ink);
      canvas.drawLine(const Offset(66, 60), const Offset(74, 60), _stroke(3));
      canvas.drawLine(const Offset(48, 60), const Offset(54, 60), _stroke(2)..color = AppColors.card);
      canvas.drawLine(const Offset(78, 60), const Offset(84, 60), _stroke(2)..color = AppColors.card);
    } else {
      canvas.drawCircle(const Offset(57, 64), 3.6, _ink);
      canvas.drawCircle(const Offset(83, 64), 3.6, _ink);
      if (who == Cast.asha) {
        // Round glasses.
        canvas.drawCircle(const Offset(57, 64), 10, _stroke(2.5));
        canvas.drawCircle(const Offset(83, 64), 10, _stroke(2.5));
        canvas.drawLine(const Offset(67, 63), const Offset(73, 63), _stroke(2.5));
      } else {
        canvas.drawArc(const Rect.fromLTWH(50, 52, 14, 8), pi * 1.15, pi * 0.7, false, _stroke(2.5));
        canvas.drawArc(const Rect.fromLTWH(76, 52, 14, 8), pi * 1.15, pi * 0.7, false, _stroke(2.5));
      }
    }
    if (talking) {
      final mouth = _oval(const Offset(70, 83), 16, 12);
      piece(canvas, mouth, AppColors.ink);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(70, 86), width: 9, height: 4),
        Paint()..color = AppColors.red,
      );
    } else {
      final w = who == Cast.kabir ? 26.0 : 18.0;
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(70, 78), width: w, height: 12),
        0.15 * pi,
        0.7 * pi,
        false,
        _stroke(3),
      );
    }
  }

  @override
  bool shouldRepaint(BustPainter old) => old.who != who || old.color != color || old.talking != talking;
}

/// Title ribbon: a solid band with notched, folded tails peeking out at both ends.
class Ribbon extends StatelessWidget {
  const Ribbon({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(10, 4, 10, 6),
  });
  final Color color;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -10,
          top: 10,
          bottom: -6,
          width: 26,
          child: CustomPaint(painter: _TailPainter(side(color), false)),
        ),
        Positioned(
          right: -10,
          top: 10,
          bottom: -6,
          width: 26,
          child: CustomPaint(painter: _TailPainter(side(color), true)),
        ),
        Container(
          padding: padding,
          decoration: pieceDecoration(fill: color, radius: 6, depth: 3),
          child: child,
        ),
      ],
    ),
  );
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color, this.right);
  final Color color;
  final bool right;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (right) {
      canvas
        ..translate(w, 0)
        ..scale(-1, 1);
    }
    final notch = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(9, h / 2)
      ..close();
    piece(canvas, notch, color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color || old.right != right;
}

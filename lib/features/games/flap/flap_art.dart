import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';

import '../_shared/arcade_colors.dart';
import 'flap_rules.dart';

/// Painting helpers for Candle Hop: flat fills, thick ink outlines, a visible side face.

const _ink = ArcadeColors.ink;
const white = Color(0xFFFFFFFF);

// Sky palettes: seven flat bands from top to the ground, one set per time of day.
const skyDay = [
  Color(0xFF4FB3F0),
  Color(0xFF69C2F4),
  Color(0xFF84D0F7),
  Color(0xFF9FDCF9),
  Color(0xFFBAE6FA),
  Color(0xFFD3F0FB),
  Color(0xFFE8F8FC),
];
const skySunset = [
  Color(0xFF2E6A8E),
  Color(0xFF4A8497),
  Color(0xFFF2B35E),
  Color(0xFFF59A4C),
  Color(0xFFF2804A),
  Color(0xFFE8644A),
  Color(0xFFD9524A),
];
const skyNight = [
  Color(0xFF0B1630),
  Color(0xFF0F1D3D),
  Color(0xFF142749),
  Color(0xFF19305A),
  Color(0xFF1F3A6B),
  Color(0xFF264578),
  Color(0xFF2D5086),
];
const cloudColors = [Color(0xFFFFFFFF), Color(0xFFFFD9B0), Color(0xFF5C7099)];
const sunColors = [Color(0xFFFFD84D), Color(0xFFFF7A3C), Color(0xFFE9EEF7)];
const sunY = [150.0, 300.0, 140.0];

Color shade(Color c, double k) => Color.lerp(c, k < 0 ? _ink : white, k.abs())!;

Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(double w, [Color c = _ink]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..color = c;

/// Solid rect with outline, right side face and top face (a chunky block seen from above-right).
void block(Canvas c, Rect r, Color col, {double depth = 8, double outline = 3}) {
  final side = Path()
    ..moveTo(r.right, r.top)
    ..lineTo(r.right + depth, r.top - depth)
    ..lineTo(r.right + depth, r.bottom - depth)
    ..lineTo(r.right, r.bottom)
    ..close();
  final top = Path()
    ..moveTo(r.left, r.top)
    ..lineTo(r.left + depth, r.top - depth)
    ..lineTo(r.right + depth, r.top - depth)
    ..lineTo(r.right, r.top)
    ..close();
  c.drawPath(side, _fill(shade(col, -0.3)));
  c.drawPath(top, _fill(shade(col, 0.25)));
  c.drawRect(r, _fill(col));
  if (r.width > 20) {
    c.drawRect(Rect.fromLTWH(r.left + 7, r.top + 6, 7, max(0, r.height - 12)), _fill(white.withValues(alpha: 0.35)));
  }
  c.drawPath(side, _stroke(outline));
  c.drawPath(top, _stroke(outline));
  c.drawRect(r, _stroke(outline));
}

void drawCandlePair(Canvas c, CandlePair p, double ground) {
  final gold = p.golden;
  final top = gold ? ArcadeColors.amber : (p.greenTop ? ArcadeColors.mint : ArcadeColors.coral);
  final bot = gold ? ArcadeColors.amber : (p.greenBottom ? ArcadeColors.mint : ArcadeColors.coral);
  final r = p.rects(ground);
  block(c, r[0], shade(top, -0.18), depth: 4, outline: 2.5);
  block(c, r[2], shade(bot, -0.18), depth: 4, outline: 2.5);
  block(c, r[1], top);
  block(c, r[3], bot);
}

/// Flat outlined cloud, drawn at unit size around (0,0) and scaled by the caller.
final Path cloudPath = Path.combine(
  PathOperation.union,
  Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: const Offset(-22, 2), radius: 16)),
    Path()..addOval(Rect.fromCircle(center: const Offset(0, -8), radius: 22)),
  ),
  Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: const Offset(24, 0), radius: 17)),
    Path()..addRRect(RRect.fromLTRBR(-34, 0, 38, 17, const Radius.circular(8))),
  ),
);

void drawCloud(Canvas c, double x, double y, double s, Color col) {
  c.save();
  c.translate(x, y);
  c.scale(s);
  c.drawPath(cloudPath, _fill(col));
  c.drawPath(cloudPath, _stroke(2.5 / s));
  c.restore();
}

/// Rocket pointing right, centred on (0,0), about 44 x 24. [flame] 0..1 is the thrust flame, [t] drives the flicker.
void drawRocket(Canvas c, {required double flame, required double t, bool tumble = false}) {
  final f = 6 + 12 * flame + 2.5 * sin(t * 60);
  final outer = Path()
    ..moveTo(-16, -5)
    ..lineTo(-16 - f, 0)
    ..lineTo(-16, 5)
    ..close();
  c.drawPath(outer, _fill(const Color(0xFFFF8A2B)));
  c.drawPath(outer, _stroke(2.5));
  final inner = Path()
    ..moveTo(-16, -2.5)
    ..lineTo(-16 - f * 0.55, 0)
    ..lineTo(-16, 2.5)
    ..close();
  c.drawPath(inner, _fill(ArcadeColors.amber));

  final fin = Path()
    ..moveTo(-14, -8)
    ..lineTo(-22, -17)
    ..lineTo(-6, -8)
    ..close();
  final fin2 = Path()
    ..moveTo(-14, 8)
    ..lineTo(-22, 17)
    ..lineTo(-6, 8)
    ..close();
  for (final p in [fin, fin2]) {
    c.drawPath(p, _fill(ArcadeColors.coral));
    c.drawPath(p, _stroke(2.5));
  }

  final body = Path()
    ..moveTo(-18, -9)
    ..lineTo(6, -10)
    ..quadraticBezierTo(24, -8, 24, 0)
    ..quadraticBezierTo(24, 8, 6, 10)
    ..lineTo(-18, 9)
    ..close();
  c.drawPath(body, _fill(const Color(0xFFFFF3DC)));
  final nose = Path()
    ..moveTo(10, -9.6)
    ..quadraticBezierTo(24, -8, 24, 0)
    ..quadraticBezierTo(24, 8, 10, 9.6)
    ..close();
  c.drawPath(nose, _fill(ArcadeColors.coral));
  c.drawRect(Rect.fromLTWH(-16, 4.5, 24, 3), _fill(shade(const Color(0xFFFFF3DC), -0.12)));
  c.drawPath(body, _stroke(2.5));
  c.drawLine(const Offset(10, -9.6), const Offset(10, 9.6), _stroke(2));
  c.drawCircle(const Offset(-1, -1), 5.2, _fill(ArcadeColors.sky));
  c.drawCircle(const Offset(-1, -1), 5.2, _stroke(2.2));
  c.drawCircle(const Offset(-2.6, -2.8), 1.5, _fill(white));
}

void drawCoin(Canvas c, double x, double y, double r, double t, Color col) {
  final sx = max(0.25, cos(t).abs());
  c.save();
  c.translate(x, y);
  c.scale(sx, 1);
  c.drawCircle(Offset(r * 0.18, r * 0.18), r, _fill(shade(col, -0.35)));
  c.drawCircle(Offset.zero, r, _fill(col));
  c.drawCircle(Offset.zero, r * 0.62, _stroke(max(1.6, r * 0.14), shade(col, -0.3)));
  c.drawCircle(Offset.zero, r, _stroke(2.5));
  c.restore();
}

void drawBolt(Canvas c, double x, double y, double r, double t) {
  final ring = r + 6 + 3 * sin(t * 6);
  c.drawCircle(Offset(x, y), ring, _stroke(3, ArcadeColors.amber));
  c.drawCircle(Offset(x, y), r, _fill(ArcadeColors.amber));
  c.drawCircle(Offset(x, y), r, _stroke(2.8));
  final s = r / 14;
  final bolt = Path()
    ..moveTo(x + 3 * s, y - 10 * s)
    ..lineTo(x - 6 * s, y + 2 * s)
    ..lineTo(x - 0.5 * s, y + 2 * s)
    ..lineTo(x - 3 * s, y + 10 * s)
    ..lineTo(x + 6 * s, y - 2 * s)
    ..lineTo(x + 0.5 * s, y - 2 * s)
    ..close();
  c.drawPath(bolt, _fill(white));
  c.drawPath(bolt, _stroke(1.8));
}

/// Text with a thick ink outline, centred on [at].
void outlinedText(Canvas c, String s, Offset at, double fs, Color col, {double alpha = 1}) {
  TextPainter mk(Paint p) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'Fredoka', fontSize: fs, fontWeight: FontWeight.w700, foreground: p),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final o = mk(_stroke(fs * 0.22, _ink.withValues(alpha: alpha)));
  final f = mk(_fill(col.withValues(alpha: alpha)));
  final pos = at - Offset(f.width / 2, f.height / 2);
  o.paint(c, pos);
  f.paint(c, pos);
}

/// Small solid pill with an outline, used for timers.
void pill(Canvas c, Rect r, Color col, double fill) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
  c.drawRRect(rr.shift(const Offset(0, 3)), _fill(_ink));
  c.drawRRect(rr, _fill(const Color(0xFFFFF3DC)));
  c.save();
  c.clipRRect(rr);
  c.drawRect(Rect.fromLTWH(r.left, r.top, r.width * fill, r.height), _fill(col));
  c.restore();
  c.drawRRect(rr, _stroke(2.5));
}

void triangle(Canvas c, double x, double y, double s, bool up, Color col) {
  final d = up ? -1 : 1;
  final p = Path()
    ..moveTo(x, y + d * s)
    ..lineTo(x - s, y - d * s)
    ..lineTo(x + s, y - d * s)
    ..close();
  c.drawPath(p, _fill(col));
}

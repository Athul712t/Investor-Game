import '../_shared/arcade_colors.dart';

import 'dart:math';

import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../core/sfx.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'merge_board.dart';

const _slideT = 0.12, _popT = 0.3;

/// Pieces get more valuable by shape: coins, bars, stacked bars, gems, a crown.
enum _Shape { coin, bar, bars, gem, crown }

const _looks = <(Color, _Shape)>[
  (Color(0xFFD08A5A), _Shape.coin), // copper
  (Color(0xFFC9D2E0), _Shape.coin), // silver
  (Color(0xFFF2B63C), _Shape.coin), // gold
  (Color(0xFF2EE6A6), _Shape.coin), // emerald coin
  (Color(0xFFF2B63C), _Shape.bar),
  (Color(0xFFFFD66B), _Shape.bar),
  (Color(0xFFDCE6F5), _Shape.bar), // platinum
  (Color(0xFFF2B63C), _Shape.bars),
  (Color(0xFFDCE6F5), _Shape.bars),
  (Color(0xFFFF5C6C), _Shape.gem), // ruby
  (Color(0xFF4CC9F0), _Shape.gem), // sapphire
  (Color(0xFFFFD66B), _Shape.crown),
];

class _Wave {
  _Wave(this.at);
  final Offset at;
  double age = -0.06;
}

class _Particle {
  _Particle(this.pos, this.vel, this.color, this.size);
  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  double life = 0.6;
}

/// Coin Merge: 2048-style swipe puzzle. All drawing is done in [render].
class MergeGame extends ArcadeGame with DragCallbacks, KeyboardEvents {
  MergeGame(super.config) : _board = MergeBoard(rng: config.seed != null ? Random(config.seed) : Random());

  final MergeBoard _board;

  @override
  List<PowerupType> get boosts => const [PowerupType.magnet, PowerupType.doubleScore, PowerupType.extraLife];

  // Animation state of the last move.
  MoveResult _last = const MoveResult();
  double _t = 99; // seconds since the last move
  final _particles = <_Particle>[];
  final _waves = <_Wave>[];
  final _rng = Random();
  final _seenTier = <int>{};
  int _doubleMoves = 0;
  double _overIn = -1;
  double _bannerT = 99;
  String _banner = '';
  Offset _drag = Offset.zero;
  bool _dragDone = false;

  @override
  Future<void> onLoad() async {
    _board.spawn();
    _board.spawn();
  }

  // ---- input ----
  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _drag = Offset.zero;
    _dragDone = false;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragDone) return;
    _drag += Offset(event.canvasDelta.x, event.canvasDelta.y);
    if (_drag.distance < 24) return;
    _dragDone = true;
    _move(
      _drag.dx.abs() > _drag.dy.abs()
          ? (_drag.dx > 0 ? MergeDir.right : MergeDir.left)
          : (_drag.dy > 0 ? MergeDir.down : MergeDir.up),
    );
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final d = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => MergeDir.up,
      LogicalKeyboardKey.arrowDown => MergeDir.down,
      LogicalKeyboardKey.arrowLeft => MergeDir.left,
      LogicalKeyboardKey.arrowRight => MergeDir.right,
      _ => null,
    };
    if (d == null) return KeyEventResult.ignored;
    _move(d);
    return KeyEventResult.handled;
  }

  // ---- rules ----
  void _move(MergeDir d) {
    if (paused || isOver || _overIn >= 0) return; // keys still arrive while the host shows a card
    final r = _board.move(d);
    if (!r.changed) return;
    Sound.play(Sfx.swipe, volume: 0.7);
    _last = r;
    _t = 0;
    var needBoost = false;
    if (r.merges.isNotEmpty) Sound.play(r.merges.values.any((v) => v >= 64) ? Sfx.perfect : Sfx.merge);
    final mult = _doubleMoves > 0 ? 2 : 1;
    if (_doubleMoves > 0) _doubleMoves--;
    r.merges.forEach((cell, v) {
      score.value += v * mult;
      _waves.add(_Wave(_cellRect(cell).center));
      if (v >= 16) coins.value++;
      if (v >= 64) {
        _burst(cell, v);
        Haptics.medium();
      }
      if (v >= 32 && _seenTier.add(v)) needBoost = true;
    });
    if (!_board.canMove) _overIn = 0.5;
    if (needBoost) requestBoost();
  }

  @override
  void applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.magnet:
        for (final c in _board.removeLowest(2)) {
          _burst(c, 8);
        }
        _show('🧲 Magnet');
      case PowerupType.doubleScore:
        _doubleMoves = 10;
        _show('✖️ 2x score, 10 moves');
      case PowerupType.extraLife:
        final c = _board.upgradeLowest(2);
        if (c >= 0) _burst(c, 32);
        _show('❤️ Tile upgraded');
      default:
        return;
    }
    _settle();
  }

  @override
  void revive() {
    for (final c in _board.removeLowest(4)) {
      _burst(c, 8);
    }
    _overIn = -1;
    _show('💫 Fresh start');
    _settle();
  }

  void _settle() {
    _last = const MoveResult();
    _t = 99;
  }

  void _show(String s) {
    _banner = s;
    _bannerT = 0;
  }

  // ---- layout ----
  // The host covers the bottom ~170px with the quiz chip, so the board and its hint live above that.
  static const _chipBand = 170.0, _frame = 12.0;
  Rect get _boardRect {
    final availH = size.y - 150 - _chipBand;
    final s = max(120.0, min(min(size.x - 32 - _frame * 2, availH), 480.0));
    return Rect.fromLTWH((size.x - s) / 2, 150 + max(0.0, availH - s) * 0.25, s, s);
  }

  static const _gap = 8.0;
  double get _cell => (_boardRect.width - _gap * 5) / 4;
  Rect _cellRect(int i) {
    final r = _boardRect, c = _cell;
    final x = r.left + _gap + (i % 4) * (c + _gap);
    final y = r.top + _gap + (i ~/ 4) * (c + _gap);
    return Rect.fromLTWH(x, y, c, c);
  }

  void _burst(int cell, int value) {
    final c = _cellRect(cell).center;
    final col = _looks[(MergeBoard.tierOf(value) - 1).clamp(0, 11)].$1;
    for (var i = 0; i < 18; i++) {
      final a = _rng.nextDouble() * 2 * pi, v = 80 + _rng.nextDouble() * 200;
      _particles.add(
        _Particle(c, Offset(cos(a), sin(a)) * v, i.isEven ? col : ArcadeColors.amber, 3 + _rng.nextDouble() * 4),
      );
    }
  }

  // ---- update ----
  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _bannerT += dt;
    if (_overIn >= 0) {
      _overIn -= dt;
      if (_overIn < 0) {
        _overIn = -1;
        gameOver();
      }
    }
    for (final p in _particles) {
      p.life -= dt;
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx * 0.94, p.vel.dy * 0.94 + 260 * dt);
    }
    _particles.removeWhere((p) => p.life <= 0);
    for (final w in _waves) {
      w.age += dt;
    }
    _waves.removeWhere((w) => w.age > 0.4);
  }

  // ---- drawing ----
  static const _wood = Color(0xFF5A3A26), _woodDark = Color(0xFF3A2418), _felt = Color(0xFF16352F);
  static const _white = Color(0xFFFFFFFF);
  static Color _dk(Color c, double t) => Color.lerp(c, ArcadeColors.ink, t)!;
  static Color _lt(Color c, double t) => Color.lerp(c, _white, t)!;

  final _tp = <String, TextPainter>{};

  /// Cached. Emoji only appear in the banner, which is short-lived.
  TextPainter _text(String s, double size, Color color) =>
      _tp['$s|${size.round()}|${color.toARGB32()}'] ??= TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, color: color, fontFamily: 'Fredoka', fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _paintText(Canvas canvas, TextPainter tp, Offset center) =>
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

  /// White text with an ink outline: readable on every metal.
  void _label(Canvas c, String s, Offset at, double fs) {
    if (s.isEmpty) return;
    final tp = _tp['o|$s|${fs.round()}'] ??= TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: fs,
          fontFamily: 'Fredoka',
          fontWeight: FontWeight.w800,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fs * 0.2
            ..strokeJoin = StrokeJoin.round
            ..color = ArcadeColors.ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintText(c, tp, at);
    _paintText(c, _text(s, fs, _white), at);
  }

  static Path _poly(List<Offset> p) => Path()..addPolygon(p, true);

  void _outline(Canvas c, Path p, double w) {
    final ink = Paint()
      ..color = ArcadeColors.ink
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 2;
    c.drawPath(p, ink..style = PaintingStyle.stroke);
    c.drawPath(p, ink..style = PaintingStyle.fill);
  }

  /// A slab with a sloped front, a top face and a thick underside. [top] is the y of the top face.
  void _bar(Canvas c, double w, double top, double t, double h, double th, Color col, String label, double fs) {
    final i = w * 0.09, j = w * 0.06, a = w / 2;
    final fy0 = top + t, fy1 = fy0 + h;
    final topFace = _poly([Offset(-a + i + j, top), Offset(a - i - j, top), Offset(a - i, fy0), Offset(-a + i, fy0)]);
    final front = _poly([Offset(-a + i, fy0), Offset(a - i, fy0), Offset(a, fy1), Offset(-a, fy1)]);
    final base = _poly([Offset(-a, fy1), Offset(a, fy1), Offset(a, fy1 + th), Offset(-a, fy1 + th)]);
    _outline(c, Path.combine(PathOperation.union, Path.combine(PathOperation.union, topFace, front), base), 2.2);
    c.drawPath(base, Paint()..color = _dk(col, 0.45));
    c.drawPath(front, Paint()..color = col);
    c.drawPath(topFace, Paint()..color = _lt(col, 0.4));
    c.drawLine(
      Offset(-a + i + 2, fy0 + 1.5),
      Offset(a - i - 2, fy0 + 1.5),
      Paint()
        ..color = _lt(col, 0.7)
        ..strokeWidth = 2,
    );
    _label(c, label, Offset(0, fy0 + h * 0.5), fs);
  }

  void _drawPiece(Canvas c, Offset center, double s, int tier, String label, {double sx = 1, double sy = 1}) {
    final (col, shape) = _looks[(tier - 1).clamp(0, 11)];
    final n = label.length;
    c.save();
    c.translate(center.dx, center.dy + s * 0.04);
    c.scale(sx, sy);
    c.drawOval(
      Rect.fromCenter(center: Offset(0, s * 0.4), width: s * 0.95, height: s * 0.2),
      Paint()..color = ArcadeColors.ink.withValues(alpha: 0.4),
    );
    switch (shape) {
      case _Shape.coin:
        final r = s * 0.44, th = s * 0.11, cy = -th / 2;
        final sil = Path()
          ..addOval(Rect.fromCircle(center: Offset(0, cy + th), radius: r))
          ..addOval(Rect.fromCircle(center: Offset(0, cy), radius: r))
          ..addRect(Rect.fromLTRB(-r, cy, r, cy + th));
        _outline(c, sil, 2.2);
        c.drawPath(sil, Paint()..color = _dk(col, 0.4));
        c.drawCircle(Offset(0, cy), r, Paint()..color = col);
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08
          ..color = _dk(col, 0.25);
        c.drawCircle(Offset(0, cy), r * 0.8, ring);
        c.drawArc(
          Rect.fromCircle(center: Offset(0, cy), radius: r * 0.9),
          pi * 1.05,
          pi * 0.4,
          false,
          ring
            ..strokeCap = StrokeCap.round
            ..color = _lt(col, 0.7),
        );
        _label(c, label, Offset(0, cy), r * (n <= 2 ? 0.95 : (n == 3 ? 0.78 : 0.62)));
      case _Shape.bar:
        _bar(c, s * 0.92, -s * 0.36, s * 0.15, s * 0.46, s * 0.1, col, label, s * (n <= 3 ? 0.3 : 0.25));
      case _Shape.bars:
        _bar(c, s * 0.92, -s * 0.02, s * 0.1, s * 0.3, s * 0.08, col, label, s * 0.21);
        _bar(c, s * 0.58, -s * 0.4, s * 0.1, s * 0.26, s * 0.04, _lt(col, 0.12), '', 0);
      case _Shape.gem:
        final w = s * 0.92, a = w / 2, yT = -s * 0.36, yG = yT + s * 0.28, yB = s * 0.34, th = s * 0.07, tbl = w * 0.28;
        final crown = _poly([Offset(-tbl, yT), Offset(tbl, yT), Offset(a, yG), Offset(-a, yG)]);
        final pav = _poly([Offset(-a, yG), Offset(a, yG), Offset(0, yB)]);
        final shadow = pav.shift(Offset(0, th));
        _outline(c, Path.combine(PathOperation.union, Path.combine(PathOperation.union, crown, pav), shadow), 2.2);
        c.drawPath(shadow, Paint()..color = _dk(col, 0.5));
        c.drawPath(pav, Paint()..color = _dk(col, 0.12));
        c.drawPath(crown, Paint()..color = _lt(col, 0.12));
        c.drawPath(_poly([Offset(-tbl, yT), Offset(-a, yG), Offset(-w * 0.18, yG)]), Paint()..color = _lt(col, 0.5));
        c.drawPath(_poly([Offset(w * 0.18, yG), Offset(a, yG), Offset(tbl, yT)]), Paint()..color = _dk(col, 0.2));
        final facet = Paint()
          ..color = _dk(col, 0.45)
          ..strokeWidth = 1.5;
        c.drawLine(Offset(-w * 0.18, yG), Offset(0, yB), facet);
        c.drawLine(Offset(w * 0.18, yG), Offset(0, yB), facet);
        c.drawLine(Offset(-a, yG), Offset(a, yG), facet);
        _label(c, label, Offset(0, yG + s * 0.02), s * (n <= 4 ? 0.24 : 0.2));
      case _Shape.crown:
        final a = s * 0.46, h = s * 0.66, top = -h / 2 - s * 0.02, th = s * 0.08;
        Offset q(double x, double y) => Offset(x * a, top + y * h);
        final body = _poly([q(-1, 1), q(-1, 0.2), q(-0.5, 0.55), q(0, 0), q(0.5, 0.55), q(1, 0.2), q(1, 1)]);
        final sil = Path.combine(PathOperation.union, body, body.shift(Offset(0, th)));
        _outline(c, sil, 2.2);
        c.drawPath(sil, Paint()..color = _dk(col, 0.45));
        c.drawPath(body, Paint()..color = col);
        c.drawPath(_poly([q(-1, 0.6), q(1, 0.6), q(1, 1), q(-1, 1)]), Paint()..color = _dk(col, 0.18));
        c.drawLine(q(-1, 0.6), q(1, 0.6), Paint()..color = _lt(col, 0.6));
        for (final p in [q(-1, 0.2), q(0, 0), q(1, 0.2)]) {
          c.drawCircle(p, s * 0.07, Paint()..color = const Color(0xFFFF5C6C));
          c.drawCircle(
            p,
            s * 0.07,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = ArcadeColors.ink,
          );
        }
        _label(c, label, q(0, 0.8), s * 0.2);
    }
    c.restore();
  }

  void _drawTile(Canvas canvas, Rect rect, int value, double sx, double sy) =>
      _drawPiece(canvas, rect.center, rect.width * 0.88, MergeBoard.tierOf(value), '₹$value', sx: sx, sy: sy);

  Paint _stroke(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = c;

  void _drawVault(Canvas canvas, Rect br) {
    final w = size.x, h = size.y;
    canvas.drawRect(
      Offset.zero & Size(w, h),
      Paint()..color = Color.lerp(ArcadeColors.surface, ArcadeColors.ink, 0.35)!,
    );
    // Brick wall.
    final mortar = Paint()
      ..color = ArcadeColors.ink.withValues(alpha: 0.55)
      ..strokeWidth = 2;
    const bh = 30.0, bw = 70.0;
    for (var row = 0, y = 0.0; y < h; row++, y += bh) {
      canvas.drawLine(Offset(0, y), Offset(w, y), mortar);
      for (var x = (row.isOdd ? -bw / 2 : 0.0); x < w; x += bw) {
        canvas.drawLine(Offset(x, y), Offset(x, y + bh), mortar);
        if (sin(row * 7.1 + x * 0.13) > 0.5) {
          canvas.drawRect(
            Rect.fromLTWH(x + 1, y + 1, bw - 2, bh - 2),
            Paint()..color = ArcadeColors.surfaceHi.withValues(alpha: 0.35),
          );
        }
      }
    }
    // Vault door behind the tray.
    final c = br.center.translate(0, -br.height * 0.1);
    final r = w * 0.78;
    final steel = Color.lerp(ArcadeColors.surfaceHi, ArcadeColors.line, 0.6)!;
    canvas.drawCircle(c.translate(0, 8), r, Paint()..color = ArcadeColors.ink);
    canvas.drawCircle(c, r, Paint()..color = steel);
    canvas.drawCircle(c, r, _stroke(5, ArcadeColors.ink));
    canvas.drawCircle(c, r * 0.86, Paint()..color = _dk(steel, 0.25));
    canvas.drawCircle(c, r * 0.86, _stroke(3, ArcadeColors.ink));
    for (var i = 0; i < 16; i++) {
      final a = i * pi / 8, p = c + Offset(cos(a), sin(a)) * r * 0.93;
      canvas.drawCircle(p, 6, Paint()..color = _lt(steel, 0.35));
      canvas.drawCircle(p, 6, _stroke(2, ArcadeColors.ink));
    }
    // Table top.
    final ty = br.top + br.height * 0.55;
    final table = Rect.fromLTRB(-4, ty, w + 4, h + 4);
    canvas.drawRect(table, Paint()..color = _wood);
    for (var y = ty + 40; y < h; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(w, y), _stroke(2, _woodDark));
    }
    canvas.drawRect(table, _stroke(4, ArcadeColors.ink));
    canvas.drawRect(Rect.fromLTWH(0, ty + 2, w, 5), Paint()..color = _lt(_wood, 0.25));
    // Loose coin stacks on the table, below the tray.
    final sy = br.bottom + _frame + 56;
    for (final (x, n) in [(w * 0.2, 4), (w * 0.8, 6)]) {
      for (var k = 0; k < n; k++) {
        final p = Offset(x, sy - k * 8.0);
        final col = k.isEven ? _looks[2].$1 : _looks[1].$1;
        canvas.drawOval(
          Rect.fromCenter(center: p.translate(0, 6), width: 55, height: 19),
          Paint()..color = ArcadeColors.ink,
        );
        canvas.drawOval(
          Rect.fromCenter(center: p.translate(0, 5), width: 52, height: 16),
          Paint()..color = _dk(col, 0.4),
        );
        canvas.drawOval(Rect.fromCenter(center: p, width: 52, height: 16), Paint()..color = col);
      }
    }
  }

  void _drawTray(Canvas canvas, Rect br) {
    final frame = RRect.fromRectAndRadius(br.inflate(_frame), const Radius.circular(22));
    final bed = RRect.fromRectAndRadius(br, const Radius.circular(14));
    canvas.drawRRect(frame.shift(const Offset(0, 8)), Paint()..color = ArcadeColors.ink);
    canvas.drawRRect(frame, Paint()..color = _wood);
    canvas.drawRRect(frame.deflate(2), _stroke(3, _lt(_wood, 0.2)));
    canvas.drawRRect(frame, _stroke(4, ArcadeColors.ink));
    // Inset bed: dark rim on the top and left edges where the frame casts a shadow.
    canvas.drawRRect(bed, Paint()..color = _felt);
    canvas.save();
    canvas.clipRRect(bed);
    canvas.drawRect(Rect.fromLTWH(br.left, br.top, br.width, 7), Paint()..color = _dk(_felt, 0.55));
    canvas.drawRect(Rect.fromLTWH(br.left, br.top, 5, br.height), Paint()..color = _dk(_felt, 0.4));
    canvas.restore();
    canvas.drawRRect(bed, _stroke(3, ArcadeColors.ink));
    for (var i = 0; i < 16; i++) {
      final r = _cellRect(i);
      final rad = Radius.circular(_cell * 0.2);
      final rr = RRect.fromRectAndRadius(r, rad);
      canvas.drawRRect(rr, Paint()..color = _dk(_felt, 0.45));
      canvas.drawRRect(rr.deflate(1), _stroke(2, _lt(_felt, 0.12)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.18), rad),
        Paint()..color = _dk(_felt, 0.7),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0) return;
    final br = _boardRect;
    _drawVault(canvas, br);
    _drawTray(canvas, br);

    if (_t < _slideT) {
      final e = Curves.easeOut.transform(_t / _slideT);
      for (final s in _last.slides) {
        _drawTile(canvas, Rect.lerp(_cellRect(s.from), _cellRect(s.to), e)!, s.value, 1, 1);
      }
    } else {
      final pt = (_t - _slideT) / _popT;
      for (var i = 0; i < 16; i++) {
        final v = _board.cells[i];
        if (v == 0) continue;
        var sx = 1.0, sy = 1.0;
        if (pt < 1) {
          if (_last.merges.containsKey(i)) {
            // Pump up, then squash and stretch back to rest.
            final pop = 1 + 0.16 * sin(pt * pi), k = (1 - pt) * sin(pt * pi * 3) * 0.24;
            sx = pop * (1 + k);
            sy = pop * (1 - k);
          } else if (i == _last.spawnCell) {
            sx = sy = Curves.easeOutBack.transform(pt).clamp(0.0, 1.3);
          }
        }
        _drawTile(canvas, _cellRect(i), v, sx, sy);
      }
    }

    for (final w in _waves) {
      if (w.age < 0) continue;
      final k = Curves.easeOut.transform(w.age / 0.4);
      canvas.drawCircle(
        w.at,
        _cell * (0.4 + 0.6 * k),
        _stroke(4 * (1 - k) + 0.5, ArcadeColors.amber.withValues(alpha: 1 - k)),
      );
    }
    for (final p in _particles) {
      final paint = Paint()..color = p.color.withValues(alpha: (p.life / 0.4).clamp(0.0, 1.0));
      canvas.drawCircle(p.pos, p.size * (p.life / 0.6).clamp(0.2, 1.0), paint);
    }
    _drawHint(canvas, br);
    _drawBanner(canvas, br);
  }

  /// Above the tray, so the quiz chip never covers it.
  void _drawHint(Canvas canvas, Rect br) {
    final next = max(_board.highest, 1) * 2;
    final label = _doubleMoves > 0 ? 'Next goal ₹$next   2x: $_doubleMoves' : 'Next goal ₹$next';
    final tp = _text(label, 17, ArcadeColors.text);
    final y = br.top - _frame - 30;
    final x0 = (size.x - (44 + tp.width)) / 2;
    _drawPiece(canvas, Offset(x0 + 17, y), 34, MergeBoard.tierOf(next), '');
    tp.paint(canvas, Offset(x0 + 44, y - tp.height / 2));
  }

  void _drawBanner(Canvas canvas, Rect br) {
    if (_bannerT > 1.4) return;
    final a = (_bannerT < 0.15 ? _bannerT / 0.15 : 1 - ((_bannerT - 0.9) / 0.5).clamp(0.0, 1.0)).toDouble();
    final tp = _text(_banner, 24, ArcadeColors.text);
    final c = br.center.translate(0, -_bannerT * 20);
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: tp.width + 40, height: tp.height + 20),
      const Radius.circular(24),
    );
    canvas.drawRRect(pill, Paint()..color = ArcadeColors.surfaceHi.withValues(alpha: 0.95 * a));
    canvas.drawRRect(pill, _stroke(2, ArcadeColors.amber.withValues(alpha: a)));
    canvas.saveLayer(null, Paint()..color = ArcadeColors.text.withValues(alpha: a));
    _paintText(canvas, tp, c);
    canvas.restore();
  }
}

import '../_shared/arcade_colors.dart';

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'stack_math.dart';

const _palette = [ArcadeColors.mint, ArcadeColors.sky, ArcadeColors.violet, ArcadeColors.amber, ArcadeColors.coral];
const _blockH = 0.075; // block height in units (1 unit = min(width, 0.6 * height))
const _startW = 0.6;
const _perfectTol = 0.014;
const _depth = 0.38; // 2.5D depth as a fraction of block height

class _Piece {
  _Piece(this.x, this.y, this.w, this.vx, this.vy, this.vr, this.color);
  double x, y, w, vx, vy, vr, rot = 0; // x centre, y = top of the piece (world units)
  final Color color;
}

class _Ring {
  _Ring(this.x, this.y, this.w, this.color);
  final double x, y, w;
  final Color color;
  double age = 0;
}

class _Pop {
  _Pop(this.text, this.x, this.y, this.color, this.big);
  final String text;
  final double x, y;
  final Color color;
  final bool big;
  double age = 0;
}

class _Block {
  _Block(this.x, this.w, this.color);
  final double x, w;
  final Color color;
}

/// Sky Stack: tap to drop the sliding block, keep the overlap, build the tower.
class StackGame extends ArcadeGame with TapCallbacks, KeyboardEvents {
  StackGame(super.config);

  @override
  List<PowerupType> get boosts => const [PowerupType.slowMo, PowerupType.extraLife, PowerupType.doubleScore];

  late final Random _rng = Random(config.seed ?? DateTime.now().microsecondsSinceEpoch);
  final _tower = <_Block>[];
  final _pieces = <_Piece>[];
  final _rings = <_Ring>[];
  final _pops = <_Pop>[];
  late final List<List<double>> _dust = List.generate(
    36,
    (_) => [_rng.nextDouble(), _rng.nextDouble(), 0.6 + _rng.nextDouble() * 1.8, 0.01 + _rng.nextDouble() * 0.03],
  );
  late final List<List<double>> _stars = List.generate(
    70,
    (_) => [_rng.nextDouble(), _rng.nextDouble() * 0.9, 0.5 + _rng.nextDouble() * 1.3, _rng.nextDouble() * 6.28],
  );
  late final List<List<double>> _city = _makeCity();

  double _t = 0, _cam = 0, _kick = 0, _flash = 0, _deadTimer = -1, _cooldown = 0;
  double _mx = 0, _dir = 1, _w = _startW;
  int _streak = 0, _slowLeft = 0, _doubleLeft = 0;

  double get _u => min(size.x, size.y * 0.6);
  double get _groundY => size.y * 0.85;

  @override
  Future<void> onLoad() async {
    _tower
      ..clear()
      ..add(_Block(0, _startW, _palette[0]));
    _dir = _rng.nextBool() ? 1 : -1;
    _mx = -_dir * _range;
  }

  List<List<double>> _makeCity() {
    final r = Random(7);
    var x = -0.02;
    final out = <List<double>>[];
    while (x < 1.02) {
      final w = 0.05 + r.nextDouble() * 0.07;
      out.add([x, w, 0.05 + r.nextDouble() * 0.17, r.nextDouble()]);
      x += w + 0.004;
    }
    return out;
  }

  // Half-distance the sliding block travels from the centre line, a bit past the screen edge.
  double get _range => max(0.3, size.x / 2 / _u - _w * 0.4);

  double get _speed {
    final n = _tower.length - 1;
    final base = (0.8 + 0.02 * n).clamp(0.8, 1.5) * (0.85 + 0.075 * config.difficulty);
    return base * (_slowLeft > 0 ? 0.5 : 1);
  }

  @override
  void update(double dt) {
    super.update(dt);
    dt = dt.clamp(0, 0.05);
    _t += dt;
    _cooldown -= dt;
    _kick *= exp(-dt * 12);
    _flash = max(0, _flash - dt * 3);

    if (_deadTimer >= 0) {
      _deadTimer -= dt;
      if (_deadTimer < 0) gameOver();
    } else if (!isOver) {
      _mx += _dir * _speed * dt;
      final r = _range;
      if (_mx > r) {
        _mx = r;
        _dir = -1;
      } else if (_mx < -r) {
        _mx = -r;
        _dir = 1;
      }
    }

    final target = max(0.0, (_tower.length * _blockH) * _u - size.y * 0.35);
    _cam += (target - _cam) * min(1, dt * 4);

    for (final p in _pieces) {
      p.vy -= 2.6 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
    }
    _pieces.removeWhere((p) => _groundY + _cam - p.y * _u > size.y + _u);
    for (final r in _rings) {
      r.age += dt;
    }
    _rings.removeWhere((r) => r.age > 0.55);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age > 1.1);
  }

  @override
  void onTapDown(TapDownEvent event) => drop();

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      drop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _haptic(Future<void> Function() f) => f().catchError((_) {});

  void drop() {
    if (isOver || paused || _deadTimer >= 0 || _cooldown > 0 || size.x == 0) return;
    _cooldown = 0.08;
    final top = _tower.last;
    final level = _tower.length;
    final res = sliceBlock(prevCenter: top.x, prevWidth: top.w, center: _mx, width: _w, tolerance: _perfectTol);
    final color = _palette[level % _palette.length];
    final topY = (level + 1) * _blockH;
    if (_slowLeft > 0) _slowLeft--;

    if (res.miss) {
      _streak = 0;
      _pieces.add(_Piece(_mx, topY, _w, _dir * 0.2, 0.2, _dir * 1.5, color));
      _haptic(HapticFeedback.heavyImpact);
      _deadTimer = 0.7;
      return;
    }

    if (res.cutWidth > 0) {
      final side = res.cutCenter < res.center ? -1 : 1;
      _pieces.add(_Piece(res.cutCenter, topY, res.cutWidth, side * 0.25, 0.25, side * 2.2, color));
    }
    _tower.add(_Block(res.center, res.width, color));
    _w = res.width;
    _kick = 7;

    final placed = _tower.length - 1;
    score.value += _doubleLeft > 0 ? 2 : 1;
    if (_doubleLeft > 0) _doubleLeft--;

    if (res.perfect) {
      _streak++;
      coins.value++;
      _flash = 1;
      _rings.add(_Ring(res.center, topY, res.width, color));
      _pops.add(_Pop(_streak > 1 ? 'Perfect x$_streak' : 'Perfect', res.center, topY, ArcadeColors.text, true));
      _haptic(HapticFeedback.lightImpact);
      if (_streak % 3 == 0) {
        _w = min(_startW, _w + 0.06);
        _pops.add(_Pop('Block grows!', res.center, topY - 0.11, ArcadeColors.mint, false));
      }
    } else {
      _streak = 0;
      _haptic(HapticFeedback.selectionClick);
    }
    if (placed % 5 == 0) {
      coins.value++;
      _pops.add(_Pop('+1 coin', res.center, topY - (res.perfect ? 0.22 : 0.08), ArcadeColors.amber, false));
    }

    _dir = _rng.nextBool() ? 1 : -1;
    _mx = -_dir * _range;
    if (placed % 8 == 0) requestBoost();
  }

  @override
  void applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.slowMo:
        _slowLeft = 5;
      case PowerupType.extraLife:
        _w = _startW;
        _pops.add(_Pop('Full width', _tower.last.x, (_tower.length + 1) * _blockH, ArcadeColors.coral, false));
      case PowerupType.doubleScore:
        _doubleLeft = 8;
      default:
        break;
    }
  }

  @override
  void revive() {
    _w = _startW * 0.6;
    _streak = 0;
    _deadTimer = -1;
    _dir = _rng.nextBool() ? 1 : -1;
    _mx = -_dir * _range;
  }

  // ---------------------------------------------------------------- rendering

  // Blend toward ink (dl < 0) or white (dl > 0): keeps the palette hue, unlike a lightness shift.
  Color _shade(Color c, double dl) =>
      Color.lerp(c, dl < 0 ? ArcadeColors.ink : const Color(0xFFFFFFFF), dl.abs() * (dl < 0 ? 2.2 : 1.8))!;

  void _text(Canvas c, String s, Offset at, double fs, Color col, {double alpha = 1}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: fs,
          fontWeight: FontWeight.w700,
          color: col.withValues(alpha: alpha),
          shadows: [Shadow(color: ArcadeColors.ink.withValues(alpha: 0.6 * alpha), blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  /// A 2.5D block: front face with gradient, lighter top edge, top face and right side face.
  void _block(Canvas c, double cx, double top, double w, double h, Color col, {double alpha = 1}) {
    final d = h * _depth;
    final l = cx - w / 2, r = cx + w / 2, b = top + h;
    final side = Path()
      ..moveTo(r, top)
      ..lineTo(r + d, top - d)
      ..lineTo(r + d, b - d)
      ..lineTo(r, b)
      ..close();
    final topFace = Path()
      ..moveTo(l, top)
      ..lineTo(l + d, top - d)
      ..lineTo(r + d, top - d)
      ..lineTo(r, top)
      ..close();
    final front = Rect.fromLTRB(l, top, r, b);
    c.drawPath(side, Paint()..color = _shade(col, -0.22).withValues(alpha: alpha));
    c.drawPath(topFace, Paint()..color = _shade(col, 0.2).withValues(alpha: alpha));
    c.drawRect(
      front,
      Paint()
        ..shader = ui.Gradient.linear(front.topCenter, front.bottomCenter, [
          _shade(col, 0.1).withValues(alpha: alpha),
          _shade(col, -0.08).withValues(alpha: alpha),
        ]),
    );
    c.drawRect(
      Rect.fromLTWH(l, top, w, max(1.5, h * 0.09)),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.38 * alpha),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x == 0 || _tower.isEmpty) return;
    final u = _u, w = size.x, h = size.y, cx = w / 2;
    final hgt = (_cam / (u * 3.5)).clamp(0.0, 1.0);

    // Sky gradient shifts from city dusk to deep space with height.
    final top = Color.lerp(Color.lerp(ArcadeColors.ink, ArcadeColors.violet, 0.4), ArcadeColors.ink, hgt)!;
    final mid = Color.lerp(Color.lerp(ArcadeColors.ink, ArcadeColors.violet, 0.45), ArcadeColors.surface, hgt)!;
    final bot = Color.lerp(
      Color.lerp(ArcadeColors.ink, ArcadeColors.coral, 0.5),
      Color.lerp(ArcadeColors.ink, ArcadeColors.violet, 0.22),
      hgt,
    )!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [top, mid, bot], [0, 0.55, 1]),
    );

    final starA = ((hgt - 0.1) / 0.5).clamp(0.0, 1.0) * 0.9 + 0.1;
    for (final s in _stars) {
      final a = starA * (0.45 + 0.55 * sin(_t * 1.6 + s[3]));
      canvas.drawCircle(
        Offset(s[0] * w, s[1] * h),
        s[2],
        Paint()..color = ArcadeColors.text.withValues(alpha: a.clamp(0.0, 1.0) * 0.8),
      );
    }

    // Faint skyline, parallax against the camera, fades out as we climb.
    final cityA = (1 - _cam / (h * 1.1)).clamp(0.0, 1.0);
    if (cityA > 0) {
      final base = _groundY + _cam * 0.25;
      final cityCol = Color.lerp(bot, ArcadeColors.ink, 0.65)!.withValues(alpha: cityA);
      for (final b in _city) {
        final bh = b[2] * h, bx = b[0] * w, bw = b[1] * w;
        canvas.drawRect(Rect.fromLTWH(bx, base - bh, bw, bh + h), Paint()..color = cityCol);
        for (var wy = base - bh + 8; wy < base - 6; wy += 11) {
          for (var wx = bx + 5; wx < bx + bw - 5; wx += 9) {
            if (sin(wx * 12.9 + wy * 78.2 + b[3] * 40) > 0.55) {
              canvas.drawRect(
                Rect.fromLTWH(wx, wy, 3, 4),
                Paint()..color = ArcadeColors.amber.withValues(alpha: 0.35 * cityA),
              );
            }
          }
        }
      }
    }

    for (final p in _dust) {
      final y = ((p[1] - _t * p[3]) % 1 + 1) % 1;
      canvas.drawCircle(
        Offset(p[0] * w + sin(_t * 0.5 + p[1] * 9) * 8, y * h),
        p[2],
        Paint()..color = ArcadeColors.text.withValues(alpha: 0.12),
      );
    }

    final gy = _groundY + _cam + _kick;
    double sy(double wy) => gy - wy * u;

    if (gy < h) {
      canvas.drawRect(
        Rect.fromLTWH(0, gy, w, h - gy + 4),
        Paint()..color = Color.lerp(ArcadeColors.ink, ArcadeColors.surface, 0.7)!,
      );
      canvas.drawRect(Rect.fromLTWH(0, gy, w, 3), Paint()..color = ArcadeColors.line);
    }

    final bh = _blockH * u;
    for (var i = 0; i < _tower.length; i++) {
      final b = _tower[i];
      final t = sy((i + 1) * _blockH);
      if (t > h + bh || t < -bh * 2) continue;
      _block(canvas, cx + b.x * u, t, b.w * u, bh, b.color);
    }

    if (_flash > 0 && _tower.length > 1) {
      final b = _tower.last;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx + b.x * u, sy(_tower.length * _blockH) + bh / 2), width: b.w * u, height: bh),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7 * _flash),
      );
    }

    for (final p in _pieces) {
      canvas.save();
      canvas.translate(cx + p.x * u, sy(p.y) + bh / 2);
      canvas.rotate(p.rot);
      _block(canvas, 0, -bh / 2, p.w * u, bh, p.color, alpha: 0.9);
      canvas.restore();
    }

    if (_deadTimer < 0 && !isOver) {
      final level = _tower.length;
      _block(canvas, cx + _mx * u, sy((level + 1) * _blockH), _w * u, bh, _palette[level % _palette.length]);
    }

    for (final r in _rings) {
      final k = Curves.easeOutCubic.transform(r.age / 0.55);
      final rect = Rect.fromCenter(
        center: Offset(cx + r.x * u, sy(r.y) + bh / 2),
        width: r.w * u,
        height: bh,
      ).inflate(4 + k * u * 0.1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(8 + k * 10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - k) + 0.5
          ..color = _shade(r.color, 0.25).withValues(alpha: 1 - k),
      );
    }

    for (final p in _pops) {
      final k = p.age / 1.1;
      final pop = p.big ? 1 + 0.25 * sin(min(1, p.age * 6) * pi) : 1.0;
      final at = Offset(cx + p.x * u, sy(p.y) - bh * 1.4 - k * u * 0.14);
      final alpha = (1 - max(0.0, (k - 0.55) / 0.45)).clamp(0.0, 1.0).toDouble();
      _text(canvas, p.text, at, (p.big ? 26 : 16) * pop, p.color, alpha: alpha);
    }

    _chips(canvas);
  }

  /// Active powerup and streak state, below the host HUD.
  void _chips(Canvas canvas) {
    final chips = <(String, Color)>[
      if (_slowLeft > 0) ('🐢 Slow-mo  $_slowLeft', ArcadeColors.sky),
      if (_doubleLeft > 0) ('✖️ 2x  $_doubleLeft', ArcadeColors.amber),
      if (_streak >= 2) ('🔥 Streak $_streak', ArcadeColors.mint),
    ];
    var y = 104.0;
    for (final (s, col) in chips) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ArcadeColors.text,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH((size.x - tp.width) / 2 - 12, y, tp.width + 24, 28),
        const Radius.circular(14),
      );
      canvas.drawRRect(rect, Paint()..color = ArcadeColors.ink.withValues(alpha: 0.55));
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = col.withValues(alpha: 0.8),
      );
      tp.paint(canvas, Offset((size.x - tp.width) / 2, y + (28 - tp.height) / 2));
      y += 34;
    }
  }
}

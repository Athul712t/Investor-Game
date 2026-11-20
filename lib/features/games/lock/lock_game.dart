import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter/painting.dart' show FontWeight, TextPainter, TextSpan, TextStyle, TextDirection;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../core/sfx.dart';
import '../../../core/theme.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'lock_rules.dart';

const _ink = AppColors.ink;
const _bg = Color(0xFF1B3358);
const _bgPattern = Color(0xFF203B65);
const _ringDark = Color(0xFF1F63C2);
const _ring = AppColors.blue;
const _ringLight = Color(0xFF7DB7FF);
const _paper = AppColors.paper;
const _gold = Color(0xFFFFC530);
const _red = Color(0xFFFF5348);
const _green = Color(0xFF1FB86B);

const _maxSparks = 80;
const _maxPops = 6;
const _popLife = 0.9;

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color);
  double x, y, vx, vy, age = 0;
  final double life, size;
  final Color color;
}

class _Pop {
  _Pop(this.text, this.x, this.y, this.color, this.size);
  final String text;
  final double x, y, size;
  final Color color;
  double age = 0;
}

/// Pop the Lock: tap when the pin crosses the glowing dot.
class LockGame extends ArcadeGame with TapCallbacks, KeyboardEvents {
  LockGame(super.config);

  @override
  List<PowerupType> get boosts => const [PowerupType.slowMo, PowerupType.extraLife, PowerupType.doubleScore];

  late final Random _rng = Random(config.seed ?? DateTime.now().microsecondsSinceEpoch);
  final _sparks = <_Spark>[];
  final _pops = <_Pop>[];
  final _tpCache = <String, TextPainter>{};

  double _pin = 270, _dot = 0;
  int _dir = 1, _lives = lockStartLives, _popCount = 0, _combo = 0;
  bool _bolt = false;
  double _timeLeft = lockRunSeconds, _slowT = 0, _dblT = 0, _reviveSlow = 0;
  double _pulse = 0, _shake = 0, _flash = 0, _t = 0, _dotBorn = 0;

  // Paints created once.
  final _fillP = Paint();
  final _strokeP = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final _flashP = Paint();

  Offset _c = Offset.zero;
  double _r = 100;
  final _heart = Path()
    ..moveTo(0, 5)
    ..cubicTo(-9, -1, -6, -8, 0, -4)
    ..cubicTo(6, -8, 9, -1, 0, 5)
    ..close();
  final _keyhole = Path();

  double get _k => (size.x / 390).clamp(0.8, 1.3);

  @override
  Future<void> onLoad() async {
    _dot = pickDotAngle(_rng, _pin, _dir);
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

  void _layout() {
    if (size.x <= 0) return;
    const top = 90.0;
    final bottom = size.y - 190;
    _r = max(40.0, min(size.x * 0.32, (bottom - top) * 0.34));
    _c = Offset(size.x / 2, top + 40 + (bottom - top - 40) * 0.5);
    final k = _k;
    _keyhole
      ..reset()
      ..addOval(Rect.fromCircle(center: _c.translate(0, -8 * k), radius: 15 * k))
      ..moveTo(_c.dx - 8 * k, _c.dy)
      ..lineTo(_c.dx + 8 * k, _c.dy)
      ..lineTo(_c.dx + 12 * k, _c.dy + 34 * k)
      ..lineTo(_c.dx - 12 * k, _c.dy + 34 * k)
      ..close();
  }

  // ------------------------------------------------------------------ input

  @override
  void onTapDown(TapDownEvent event) => tap();

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      tap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void tap() {
    if (isOver || paused) return;
    if (dotHit(_pin, _dot, dotHalfWidth(_popCount))) {
      _pop();
    } else {
      _miss();
    }
  }

  void _pop() {
    final perfect = isPerfect(_pin, _dot);
    final pts = popPoints(perfect: perfect, combo: _combo, doubled: _dblT > 0);
    final at = _polar(_dot);
    final wasBolt = _bolt;
    score.value += pts;
    _combo++;
    _popCount++;
    _dir = -_dir;
    _pulse = 1;
    Haptics.light();
    Sound.play(Sfx.tick);
    if (perfect) {
      coins.value += 1;
      Sound.play(Sfx.perfect);
      Sound.play(Sfx.coin);
    }
    _burst(at, perfect ? 16 : 9, perfect ? _gold : _ringLight);
    _popup(perfect ? 'Perfect +$pts' : '+$pts', at.dx, at.dy - 20 * _k, perfect ? _gold : _paper, perfect ? 24 : 20);
    if (comboMult(_combo) > comboMult(_combo - 1)) {
      _popup('x${comboMult(_combo)} combo', _c.dx, _c.dy + _r * 0.55, _green, 22);
    }
    _newDot();
    if (wasBolt) requestBoost();
  }

  void _miss() {
    _combo = 0;
    _lives--;
    _shake = 1;
    _flash = 1;
    Haptics.heavy();
    Sound.play(Sfx.crash);
    _popup('Miss', _c.dx, _c.dy - _r * 0.55, _red, 24);
    _newDot();
    if (runEnded(timeLeft: _timeLeft, lives: _lives)) gameOver();
  }

  void _newDot() {
    _bolt = nextIsBolt(_popCount);
    _dot = pickDotAngle(_rng, _pin, _dir);
    _dotBorn = _t;
  }

  // ------------------------------------------------------------------ update

  @override
  void update(double dt) {
    super.update(dt);
    if (isOver) return;
    dt = min(dt, 1 / 30);
    _t += dt;
    _timeLeft -= dt;
    _slowT = max(0, _slowT - dt);
    _dblT = max(0, _dblT - dt);
    _reviveSlow = max(0, _reviveSlow - dt);
    _pulse = max(0, _pulse - dt * 4);
    _shake = max(0, _shake - dt * 3.5);
    _flash = max(0, _flash - dt * 3);
    final slow = (_slowT > 0 ? 0.5 : 1.0) * (_reviveSlow > 0 ? 0.6 : 1.0);
    _pin = wrap360(_pin + _dir * pinSpeed(_popCount) * slow * dt);
    if (dotPassed(_pin, _dot, _dir, dotHalfWidth(_popCount))) _miss();
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.age += dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 300 * dt;
      if (s.age >= s.life) _sparks.removeAt(i);
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      _pops[i].age += dt;
      if (_pops[i].age >= _popLife) _pops.removeAt(i);
    }
    if (!isOver && _timeLeft <= 0) {
      Sound.play(Sfx.lose);
      gameOver();
    }
  }

  Offset _polar(double deg, [double? rad]) {
    final a = deg * pi / 180, r = rad ?? _r;
    return Offset(_c.dx + cos(a) * r, _c.dy + sin(a) * r);
  }

  void _burst(Offset at, int n, Color color) {
    for (var i = 0; i < n; i++) {
      if (_sparks.length >= _maxSparks) _sparks.removeAt(0);
      final a = _rng.nextDouble() * 2 * pi, v = 80 + _rng.nextDouble() * 200;
      _sparks.add(
        _Spark(
          at.dx,
          at.dy,
          cos(a) * v,
          sin(a) * v - 60,
          0.4 + _rng.nextDouble() * 0.3,
          4 + _rng.nextDouble() * 5,
          i.isEven ? color : _paper,
        ),
      );
    }
  }

  void _popup(String text, double x, double y, Color c, double size) {
    if (_pops.length >= _maxPops) _pops.removeAt(0);
    _pops.add(_Pop(text, x, y, c, size));
  }

  // ------------------------------------------------------------------ powerups

  @override
  void applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.slowMo:
        _slowT = 6;
      case PowerupType.extraLife:
        _lives = min(lockMaxLives, _lives + 1);
      case PowerupType.doubleScore:
        _dblT = 8;
      default:
        return;
    }
    Sound.play(Sfx.powerup);
  }

  @override
  void revive() {
    _lives = min(lockMaxLives, max(1, _lives + 1));
    _timeLeft += 8;
    _reviveSlow = 3;
    _combo = 0;
    _newDot();
  }

  // ------------------------------------------------------------------ render

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x, h = size.y;
    _fillP.color = _bg;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _fillP);
    _strokeP
      ..strokeWidth = 14
      ..color = _bgPattern;
    for (var x = -h; x < w; x += 56) {
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), _strokeP);
    }
    canvas.save();
    if (_shake > 0) {
      canvas.translate(sin(_t * 90) * 7 * _shake * _shake, cos(_t * 77) * 5 * _shake * _shake);
    }
    _renderLock(canvas);
    _renderFx(canvas);
    canvas.restore();
    if (_flash > 0) {
      _flashP.color = _red.withValues(alpha: 0.35 * _flash);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _flashP);
    }
    _renderHud(canvas);
  }

  void _renderLock(Canvas canvas) {
    final k = _k;
    final rr = _r * (1 + 0.05 * _pulse);
    final band = 30 * k;
    final outer = rr + band / 2;
    // hard offset shadow, ink outline, blue band, ink inner outline, paper face
    _fillP.color = _ink;
    canvas.drawCircle(_c.translate(0, 8 * k), outer + 4, _fillP);
    canvas.drawCircle(_c, outer + 4, _fillP);
    _fillP.color = _ring;
    canvas.drawCircle(_c, outer, _fillP);
    _fillP.color = _ink;
    canvas.drawCircle(_c, rr - band / 2 + 4, _fillP);
    _fillP.color = _paper;
    canvas.drawCircle(_c, rr - band / 2, _fillP);
    _strokeP
      ..strokeWidth = 5
      ..color = _ringLight;
    canvas.drawArc(Rect.fromCircle(center: _c, radius: outer - 5), pi * 1.05, pi * 0.4, false, _strokeP);
    _strokeP.color = _ringDark;
    canvas.drawArc(Rect.fromCircle(center: _c, radius: rr - band / 2 + 6), pi * 0.1, pi * 0.5, false, _strokeP);
    _fillP.color = _ink;
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(_polar(i * 30.0 + 15, rr), 2.5, _fillP);
    }
    canvas.drawPath(_keyhole, _fillP);
    _text(canvas, '${score.value}', _c.translate(0, -rr * 0.55), 26 * k, _ink, outline: false);

    // hit window arc
    final hw = dotHalfWidth(_popCount);
    final dotColor = _bolt ? _green : _gold;
    _strokeP
      ..strokeWidth = 5
      ..color = _ink;
    final arc = Rect.fromCircle(center: _c, radius: outer + 12);
    canvas.drawArc(arc, (_dot - hw) * pi / 180, hw * 2 * pi / 180, false, _strokeP..strokeWidth = 11);
    _strokeP
      ..strokeWidth = 5
      ..color = dotColor;
    canvas.drawArc(arc, (_dot - hw) * pi / 180, hw * 2 * pi / 180, false, _strokeP);

    // the dot: a glowing coin
    final at = _polar(_dot, rr);
    final born = ((_t - _dotBorn) / 0.2).clamp(0.0, 1.0);
    final beat = 0.5 + 0.5 * sin(_t * 8);
    final dr = (band * 0.62) * (0.6 + 0.4 * born) + 2 * beat;
    _fillP.color = _ink;
    canvas.drawCircle(at, dr + 4, _fillP);
    _fillP.color = dotColor;
    canvas.drawCircle(at, dr, _fillP);
    _fillP.color = _paper;
    canvas.drawCircle(at.translate(-dr * 0.35, -dr * 0.35), dr * 0.22, _fillP);
    if (_bolt) _text(canvas, '⚡', at, dr * 1.2, _ink, outline: false);

    // the pin: outlined needle
    final tip = _polar(_pin, outer + 8 * k);
    final base = _polar(_pin, rr - band / 2 - 14 * k);
    _strokeP
      ..strokeWidth = 13 * k
      ..color = _ink;
    canvas.drawLine(base, tip, _strokeP);
    _strokeP
      ..strokeWidth = 6 * k
      ..color = _red;
    canvas.drawLine(base, tip, _strokeP);
    _fillP.color = _ink;
    canvas.drawCircle(base, 10 * k, _fillP);
    _fillP.color = _paper;
    canvas.drawCircle(base, 5 * k, _fillP);
  }

  void _renderFx(Canvas canvas) {
    for (final s in _sparks) {
      final f = 1 - s.age / s.life;
      _fillP.color = _ink;
      final d = s.size * f + 1;
      canvas.drawRect(Rect.fromCenter(center: Offset(s.x, s.y), width: d + 3, height: d + 3), _fillP);
      _fillP.color = s.color;
      canvas.drawRect(Rect.fromCenter(center: Offset(s.x, s.y), width: d, height: d), _fillP);
    }
    for (final p in _pops) {
      final f = p.age / _popLife;
      final sc = f < 0.15 ? 0.6 + f / 0.15 * 0.5 : 1.1 - (f - 0.15) * 0.1;
      _text(canvas, p.text, Offset(p.x, p.y - 40 * f), p.size * sc * _k, p.color);
    }
  }

  void _renderHud(Canvas canvas) {
    final k = _k;
    // time bar under the host HUD, hearts under it
    final barW = size.x - 48, y = 98.0, bh = 12 * k;
    final frac = (_timeLeft / lockRunSeconds).clamp(0.0, 1.0);
    RRect bar(double w) => RRect.fromRectAndRadius(Rect.fromLTWH(24, y, w, bh), const Radius.circular(8));
    _fillP.color = _ink;
    canvas.drawRRect(bar(barW).inflate(3), _fillP);
    _fillP.color = _ringDark;
    canvas.drawRRect(bar(barW), _fillP);
    if (frac > 0) {
      _fillP.color = frac < 0.2 ? _red : _gold;
      canvas.drawRRect(bar(max(bh, barW * frac)), _fillP);
    }
    for (var i = 0; i < _lives; i++) {
      canvas.save();
      canvas.translate(36 + i * 28 * k, y + 34 * k);
      canvas.scale(1.6 * k);
      _fillP.color = _red;
      canvas.drawPath(_heart, _fillP);
      _strokeP
        ..strokeWidth = 1.6
        ..color = _ink;
      canvas.drawPath(_heart, _strokeP);
      canvas.restore();
    }
    var ty = y + 24 * k;
    final right = size.x - 24;
    if (_combo >= 3) {
      _textRight(canvas, 'x${comboMult(_combo)} combo', right, ty, 16 * k, _green);
      ty += 20 * k;
    }
    if (_slowT > 0) {
      _textRight(canvas, 'Slow ${_slowT.ceil()}s', right, ty, 15 * k, _ringLight);
      ty += 20 * k;
    }
    if (_dblT > 0) _textRight(canvas, '2x ${_dblT.ceil()}s', right, ty, 15 * k, _gold);
  }

  TextPainter _tp(String s, double fs, Color c, {bool stroke = false}) {
    final key = '$s|${fs.round()}|${c.toARGB32()}|$stroke';
    if (_tpCache.length > 200) _tpCache.clear();
    return _tpCache.putIfAbsent(key, () {
      final style = TextStyle(
        fontFamily: 'Fredoka',
        fontSize: fs,
        fontWeight: FontWeight.w700,
        height: 1,
        color: stroke ? null : c,
        foreground: stroke
            ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fs * 0.28
                ..strokeJoin = StrokeJoin.round
                ..color = _ink)
            : null,
      );
      return TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  void _text(Canvas c, String s, Offset at, double fs, Color col, {bool outline = true}) {
    if (outline) {
      final o = _tp(s, fs, col, stroke: true);
      o.paint(c, at - Offset(o.width / 2, o.height / 2));
    }
    final t = _tp(s, fs, col);
    t.paint(c, at - Offset(t.width / 2, t.height / 2));
  }

  void _textRight(Canvas c, String s, double right, double y, double fs, Color col) {
    final o = _tp(s, fs, col, stroke: true);
    o.paint(c, Offset(right - o.width, y));
    _tp(s, fs, col).paint(c, Offset(right - o.width, y));
  }
}

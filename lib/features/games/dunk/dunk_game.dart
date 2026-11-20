import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart' show FontWeight, TextPainter, TextSpan, TextStyle, TextDirection;

import '../../../core/sfx.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'dunk_rules.dart';

// Arcade gym palette: solid colours, ink outlines.
const _ink = Color(0xFF1D1B2E);
const _wall = Color(0xFF2D6A8F);
const _wallDark = Color(0xFF265C7D);
const _wainscot = Color(0xFF1F4E6B);
const _floor = Color(0xFFD9964B);
const _floorDark = Color(0xFFB87A36);
const _cream = Color(0xFFFFF3DC);
const _gold = Color(0xFFFFC530);
const _goldDark = Color(0xFFD99A10);
const _red = Color(0xFFFF5348);
const _orange = Color(0xFFFF8A2B);
const _pink = Color(0xFFFF9EB5);
const _pinkDark = Color(0xFFFF7FA0);
const _green = Color(0xFF1FB86B);
const _blue = Color(0xFF2F8CFF);
const _grey = Color(0xFF6E8A8E);

const _maxParticles = 80;
const _maxPops = 6;
const _trailLife = 0.28;
const _orbEvery = 6;

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color, this.size, this.life);
  double x, y, vx, vy, age = 0;
  final Color color;
  final double size, life;
}

class _Pop {
  _Pop(this.text, this.x, this.y, this.color, this.size);
  static const life = 0.95;
  final String text;
  final double x, y, size;
  final Color color;
  double age = 0;
}

class _Dot {
  _Dot(this.x, this.y, this.t);
  final double x, y, t;
}

/// Piggy Dunk: pull the coin back and flick it through the piggy bank's ring.
class DunkGame extends ArcadeGame with DragCallbacks {
  DunkGame(super.config);

  @override
  List<PowerupType> get boosts => const [PowerupType.extraLife, PowerupType.doubleScore, PowerupType.slowMo];

  late final Random _rng = Random(config.seed ?? DateTime.now().microsecondsSinceEpoch);
  final _run = DunkRun();
  final _sparks = <_Spark>[];
  final _pops = <_Pop>[];
  final _trail = <_Dot>[];
  final _tpCache = <String, TextPainter>{};
  final _fp = Paint();
  final _sp = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  DunkField? _fieldOrNull;
  DunkSim? _simOrNull;
  late DunkHoop _hoop; // the real one (collision); display slides toward it
  Offset _hoopFrom = Offset.zero;
  double _hoopT = 1;
  double _t = 0, _slowT = 0, _dblT = 0, _wob = 0, _sq = 0, _shake = 0, _wait = 0, _deadT = -1, _spawnT = 1;
  bool _afterBasket = false, _orbDue = false;
  Offset? _orb;
  Offset? _dragStart;
  double _dx = 0, _dy = 0;
  double _prevX = 0, _prevY = 0;

  DunkField get _f => _fieldOrNull!;
  DunkSim get _sim => _simOrNull!;
  double get _k => _fieldOrNull?.k ?? 1;
  bool get _ready =>
      _simOrNull != null && !_sim.flying && _wait <= 0 && _hoopT >= 1 && !isOver && _deadT < 0 && _run.timeLeft > 0;
  double get _wideK => _slowT > 0 ? 1.3 : 1;
  Offset get _hoopPos {
    final e = Curves01.easeOut(_hoopT);
    return Offset(_hoopFrom.dx + (_hoop.x - _hoopFrom.dx) * e, _hoopFrom.dy + (_hoop.y - _hoopFrom.dy) * e);
  }

  // ------------------------------------------------------------------ setup

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x <= 0 || size.y <= 0) return;
    final f = _fieldOrNull = DunkField(size.x, size.y);
    _hoop = nextHoop(f, _rng, _run.baskets, null);
    _hoopFrom = Offset(_hoop.x, _hoop.y);
    _hoopT = 1;
    _simOrNull = DunkSim(f, _hoop);
    _orb = null;
    _wait = 0;
  }

  // ------------------------------------------------------------------ input

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!_ready) return;
    final p = event.localPosition;
    if (Offset(p.x - _f.startX, p.y - _f.startY).distance > _f.grabRadius) return;
    _dragStart = Offset(p.x, p.y);
    _dx = _dy = 0;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final s = _dragStart;
    if (s == null) return;
    final p = event.localEndPosition;
    _dx = p.x - s.dx;
    _dy = p.y - s.dy;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final had = _dragStart != null;
    _dragStart = null;
    if (had && _ready) flick(_dx, _dy);
    _dx = _dy = 0;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragStart = null;
    _dx = _dy = 0;
  }

  /// Launches the coin as if the finger had been dragged by (dx, dy). Returns false when the pull is too short.
  @visibleForTesting
  bool flick(double dx, double dy) {
    if (!_ready) return false;
    final v = launchVelocity(_f, dx, dy);
    if (v == null) return false;
    _sim.launch(v.vx, v.vy);
    _prevX = _sim.x;
    _prevY = _sim.y;
    _trail.clear();
    _sq = 0.6;
    Sound.play(Sfx.jump, volume: 0.6);
    Haptics.light();
    return true;
  }

  @visibleForTesting
  DunkHoop get hoop => _hoop;
  @visibleForTesting
  DunkRun get run => _run;
  @visibleForTesting
  DunkSim get sim => _sim;
  @visibleForTesting
  bool get canFlick => _ready;

  // ------------------------------------------------------------------ update

  @override
  void update(double dt) {
    super.update(dt);
    if (_simOrNull == null) return;
    dt = dt.clamp(0.0, 1 / 30).toDouble();
    _t += dt;
    _slowT = max(0, _slowT - dt);
    _dblT = max(0, _dblT - dt);
    _wob = max(0, _wob - dt * 1.6);
    _sq = max(0, _sq - dt * 4);
    _shake = max(0, _shake - dt * 2.2);
    _spawnT = min(1, _spawnT + dt * 5);
    if (_hoopT < 1) _hoopT = min(1, _hoopT + dt * 2.6);
    if (!isOver) {
      _run.tick(dt);
      if (_run.timeLeft <= 0) {
        gameOver();
        return;
      }
    }
    _sim.hoop = DunkHoop(_hoop.x, _hoop.y, _hoop.half * _wideK);

    _sim.advance(dt * (_slowT > 0 ? 0.7 : 1));
    for (final e in _sim.events) {
      _onEvent(e);
    }
    if (_sim.flying) {
      _checkOrb();
      _prevX = _sim.x;
      _prevY = _sim.y;
      _trail.add(_Dot(_sim.x, _sim.y, _t));
    }
    _trail.removeWhere((d) => _t - d.t > _trailLife);

    if (_wait > 0) {
      _wait -= dt;
      if (_wait <= 0) _respawn();
    }
    if (_deadT >= 0) {
      _deadT -= dt;
      if (_deadT < 0) gameOver();
    }
    for (final s in _sparks) {
      s.age += dt;
      s.vy += 800 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    _sparks.removeWhere((s) => s.age > s.life);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age > _Pop.life);
  }

  void _onEvent(DunkEvent e) {
    switch (e) {
      case DunkEvent.rim:
        _sq = 1;
        _wob = max(_wob, 0.35);
        Sound.play(Sfx.tick);
        _burst(_sim.x, _sim.y, _cream, 4, 160);
      case DunkEvent.wall:
        _sq = 0.7;
      case DunkEvent.basket:
      case DunkEvent.swish:
        _basket(e == DunkEvent.swish);
      case DunkEvent.miss:
        _miss();
    }
  }

  void _basket(bool swish) {
    final before = streakMultiplier(_run.streak);
    final pts = _run.basket(swish: swish, doubled: _dblT > 0);
    score.value += pts;
    if (swish) coins.value++;
    _wob = 1;
    final hp = _hoopPos;
    _burst(hp.dx, hp.dy + 20 * _k, _gold, swish ? 18 : 10, 340);
    _pop(swish ? '+$pts Swish!' : '+$pts', hp.dx, hp.dy - 70 * _k, swish ? _gold : _cream, swish ? 34 : 28);
    final mult = streakMultiplier(_run.streak);
    if (mult > before) _pop('Streak x$mult', size.x / 2, size.y * 0.5, _green, 30);
    Sound.play(Sfx.coin);
    if (swish) Sound.play(Sfx.perfect);
    Haptics.medium();
    _wait = 0.7;
    _afterBasket = true;
    if (_run.baskets % _orbEvery == 0) _orbDue = true;
  }

  void _miss() {
    _run.miss();
    _shake = 1;
    _pop('Miss', _sim.x.clamp(60, size.x - 60).toDouble(), _f.h * 0.55, _red, 34);
    Sound.play(Sfx.crash);
    Haptics.heavy();
    _wait = 0.6;
    _afterBasket = false;
    if (_run.over) _deadT = 0.8;
  }

  void _respawn() {
    if (_afterBasket) {
      _hoopFrom = _hoopPos;
      _hoop = nextHoop(_f, _rng, _run.baskets, _hoop);
      _hoopT = 0;
      _orb = _orbDue ? Offset(_hoop.x, _hoop.y - 34 * _k) : null;
      _orbDue = false;
    }
    _afterBasket = false;
    _sim.reset();
    _trail.clear();
    _spawnT = 0;
  }

  void _checkOrb() {
    final o = _orb;
    if (o == null || _hoopT < 1) return;
    // Distance from the orb to this frame's coin path, so a fast coin cannot skip it.
    final ax = _prevX, ay = _prevY, bx = _sim.x, by = _sim.y;
    final dx = bx - ax, dy = by - ay;
    final l2 = dx * dx + dy * dy;
    final t = l2 == 0 ? 0.0 : (((o.dx - ax) * dx + (o.dy - ay) * dy) / l2).clamp(0.0, 1.0);
    final d = Offset(ax + dx * t - o.dx, ay + dy * t - o.dy).distance;
    if (d <= _f.coinR + 16 * _k) {
      _orb = null;
      _burst(o.dx, o.dy, _blue, 12, 260);
      _pop('Boost!', o.dx, o.dy - 30 * _k, _gold, 28);
      Sound.play(Sfx.powerup);
      requestBoost();
    }
  }

  void _burst(double x, double y, Color c, int n, double speed) {
    for (var i = 0; i < n && _sparks.length < _maxParticles; i++) {
      final a = _rng.nextDouble() * pi * 2, v = speed * (0.3 + _rng.nextDouble() * 0.7);
      _sparks.add(
        _Spark(
          x,
          y,
          cos(a) * v,
          sin(a) * v - 100,
          i.isEven ? c : _gold,
          (3 + _rng.nextDouble() * 3) * _k,
          0.4 + _rng.nextDouble() * 0.3,
        ),
      );
    }
  }

  void _pop(String text, double x, double y, Color c, double fs) {
    if (_pops.length >= _maxPops) _pops.removeAt(0);
    _pops.add(_Pop(text, x, y, c, fs));
  }

  @override
  void applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.extraLife:
        _run.addLife();
      case PowerupType.doubleScore:
        _dblT = 8;
      case PowerupType.slowMo:
        _slowT = 8;
      case PowerupType.shield:
      case PowerupType.magnet:
        break;
    }
  }

  @override
  void revive() {
    _run.revive();
    _deadT = -1;
    _afterBasket = false;
    _wait = 0.3;
    _dragStart = null;
    _sim.reset();
    _trail.clear();
  }

  // ------------------------------------------------------------------ rendering

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

  Paint _fill(Color c) => _fp
    ..style = PaintingStyle.fill
    ..color = c;
  Paint _line(double w, [Color c = _ink]) => _sp
    ..strokeWidth = w
    ..color = c;

  void _outRRect(Canvas c, RRect r, Color fill, double w) {
    c.drawRRect(r, _fill(fill));
    c.drawRRect(r, _line(w));
  }

  void _outCircle(Canvas c, Offset o, double r, Color fill, double w) {
    c.drawCircle(o, r, _fill(fill));
    c.drawCircle(o, r, _line(w));
  }

  void _drawBackdrop(Canvas c) {
    final w = size.x, h = size.y, k = _k;
    final floorY = _f.startY + _f.coinR + 34 * k;
    c.drawRect(Rect.fromLTWH(-30, -30, w + 60, h + 60), _fill(_wall));
    for (var x = 32.0; x < w; x += 64) {
      c.drawRect(Rect.fromLTWH(x, 0, 4, floorY), _fill(_wallDark));
    }
    // Padded wall under the hoop, then the court.
    final pad = Rect.fromLTRB(-4, floorY - 54 * k, w + 4, floorY);
    c.drawRect(pad, _fill(_wainscot));
    c.drawRect(pad, _line(3));
    for (var x = 0.0; x < w; x += 78 * k) {
      c.drawLine(Offset(x, pad.top), Offset(x, pad.bottom), _line(2.5, _wall));
    }
    c.drawRect(Rect.fromLTRB(-30, floorY, w + 30, h + 30), _fill(_floor));
    for (var x = 0.0; x < w; x += 64) {
      c.drawLine(Offset(x, floorY), Offset(x - 40, h), _line(2.5, _floorDark));
    }
    c.drawLine(Offset(-4, floorY), Offset(w + 4, floorY), _line(4));
    final arc = Rect.fromCenter(center: Offset(w / 2, floorY + 10), width: w * 0.9, height: 130 * k);
    c.drawArc(arc, 0, pi, false, _line(4, _cream));
    // Stand the coin rests on.
    final stand = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(_f.startX, _f.startY + _f.coinR + 12 * k), width: 64 * k, height: 14 * k),
      Radius.circular(7 * k),
    );
    _outRRect(c, stand, _orange, 3);
  }

  void _drawBoardAndPig(Canvas c, Offset hp, double half) {
    final k = _k;
    final board = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(hp.dx, hp.dy - 14 * k), width: half * 2 + 64 * k, height: 76 * k),
      Radius.circular(8 * k),
    );
    _outRRect(c, board, _cream, 3.5);
    final target = Rect.fromCenter(center: Offset(hp.dx, hp.dy - 26 * k), width: half * 1.1, height: 30 * k);
    c.drawRect(target, _line(3, _red));
    // Pig holding the ring up: arms first, then body.
    final by = hp.dy + 84 * k, rx = half * 0.95, ry = 34 * k;
    for (final s in const [-1.0, 1.0]) {
      final a = Offset(hp.dx + s * rx * 0.85, by - 6 * k), b = Offset(hp.dx + s * half, hp.dy + 3 * k);
      c.drawLine(a, b, _line(11 * k));
      c.drawLine(a, b, _line(6 * k, _pink));
      final ear = Path()
        ..moveTo(hp.dx + s * rx * 0.35, by - ry * 0.85)
        ..lineTo(hp.dx + s * rx * 0.85, by - ry * 1.35)
        ..lineTo(hp.dx + s * rx * 0.95, by - ry * 0.45)
        ..close();
      c.drawPath(ear, _fill(_pink));
      c.drawPath(ear, _line(3));
      final leg = RRect.fromRectAndRadius(
        Rect.fromLTWH(hp.dx + s * rx * 0.5 - 9 * k, by + ry * 0.7, 18 * k, 16 * k),
        Radius.circular(5 * k),
      );
      _outRRect(c, leg, _pink, 3);
    }
    final body = Rect.fromCenter(center: Offset(hp.dx, by), width: rx * 2, height: ry * 2);
    c.drawOval(body, _fill(_pink));
    c.drawOval(body, _line(3.5));
    final slot = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(hp.dx, by - ry * 0.78), width: 26 * k, height: 6 * k),
      Radius.circular(3 * k),
    );
    c.drawRRect(slot, _fill(_ink));
    for (final s in const [-1.0, 1.0]) {
      c.drawCircle(Offset(hp.dx + s * rx * 0.42, by - ry * 0.3), 4 * k, _fill(_ink));
    }
    final snout = Rect.fromCenter(center: Offset(hp.dx, by + ry * 0.28), width: 30 * k, height: 20 * k);
    c.drawOval(snout, _fill(_pinkDark));
    c.drawOval(snout, _line(2.5));
    for (final s in const [-1.0, 1.0]) {
      c.drawCircle(Offset(hp.dx + s * 5 * k, by + ry * 0.28), 2 * k, _fill(_ink));
    }
  }

  void _drawNetAndRim(Canvas c, Offset hp, double half) {
    final k = _k;
    final sway = sin(_t * 26) * _wob * 9 * k, depth = 44 * k * (1 + 0.18 * _wob);
    final bw = half * 0.55;
    Offset at(double f, double d) {
      final w = half + (bw - half) * d;
      return Offset(hp.dx + (f * 2 - 1) * w + sway * d, hp.dy + depth * d);
    }

    for (var i = 0; i < 5; i++) {
      final f = i / 4;
      c.drawLine(at(f, 0), at(f, 1), _line(5 * k));
    }
    for (final d in const [0.35, 0.7, 1.0]) {
      c.drawLine(at(0, d), at(1, d), _line(5 * k));
    }
    for (var i = 0; i < 5; i++) {
      final f = i / 4;
      c.drawLine(at(f, 0), at(f, 1), _line(2 * k, _cream));
    }
    for (final d in const [0.35, 0.7, 1.0]) {
      c.drawLine(at(0, d), at(1, d), _line(2 * k, _cream));
    }
    final l = Offset(hp.dx - half, hp.dy), r = Offset(hp.dx + half, hp.dy);
    c.drawLine(l, r, _line(12 * k));
    c.drawLine(l, r, _line(6 * k, _orange));
    for (final p in [l, r]) {
      _outCircle(c, p, _f.rimR * 1.25, _red, 2.5);
    }
  }

  void _drawCoin(Canvas c, double x, double y, double angle, double sq, double pop) {
    final r = _f.coinR;
    c.save();
    c.translate(x, y);
    c.rotate(angle);
    c.scale((1 + 0.25 * sq) * pop, (1 - 0.25 * sq) * pop);
    c.drawCircle(Offset(0, r * 0.14), r, _fill(_ink));
    c.drawCircle(Offset.zero, r, _fill(_gold));
    c.drawCircle(Offset.zero, r, _line(r * 0.16));
    c.drawCircle(Offset.zero, r * 0.68, _line(r * 0.09, _goldDark));
    _text(c, '₹', Offset(0, r * 0.04), r * 1.05, _ink, outline: false);
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 0.85),
      pi * 1.05,
      pi * 0.3,
      false,
      _line(r * 0.1, _cream),
    );
    c.restore();
  }

  void _drawAim(Canvas c) {
    final s = _dragStart;
    if (s == null) return;
    var dx = _dx, dy = _dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len > _f.maxDrag) {
      dx *= _f.maxDrag / len;
      dy *= _f.maxDrag / len;
    }
    final sx = _f.startX + dx, sy = _f.startY + dy;
    final k = _k;
    for (final s in const [-1.0, 1.0]) {
      c.drawLine(Offset(_f.startX + s * 34 * k, _f.startY + 8 * k), Offset(sx, sy), _line(4 * k, _ink));
    }
    final v = launchVelocity(_f, _dx, _dy);
    if (v != null) {
      for (var i = 1; i <= 9; i++) {
        final t = i * 0.05;
        final p = Offset(_f.startX + v.vx * t, _f.startY + v.vy * t + 0.5 * _f.gravity * t * t);
        final r = (5.5 - i * 0.35) * k;
        c.drawCircle(p, r + 1.8, _fill(_ink));
        c.drawCircle(p, r, _fill(_cream));
      }
    }
    _drawCoin(c, sx, sy, 0, 0, 1);
  }

  void _heart(Canvas c, Offset at, double s, bool full) {
    final p = Path()
      ..moveTo(at.dx, at.dy + s * 0.9)
      ..cubicTo(at.dx - s * 1.5, at.dy + s * 0.1, at.dx - s * 0.9, at.dy - s * 1.0, at.dx, at.dy - s * 0.3)
      ..cubicTo(at.dx + s * 0.9, at.dy - s * 1.0, at.dx + s * 1.5, at.dy + s * 0.1, at.dx, at.dy + s * 0.9);
    c.drawPath(p, _fill(full ? _red : _grey));
    c.drawPath(p, _line(3));
  }

  void _chip(Canvas c, String text, Color col, double right, double y, double frac) {
    final tp = _tp(text, 15, _ink);
    final w = tp.width + 22;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(right - w, y, w, 28), const Radius.circular(14));
    c.drawRRect(rect.shift(const Offset(0, 3)), _fill(_ink));
    c.drawRRect(rect, _fill(col));
    if (frac < 1) c.drawRect(Rect.fromLTWH(right - w + 10, y + 22, (w - 20) * frac, 3), _fill(_ink));
    c.drawRRect(rect, _line(2.5));
    tp.paint(c, Offset(right - w + 11, y + 13 - tp.height / 2));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_simOrNull == null) return;
    final w = size.x, k = _k;
    canvas.save();
    if (_shake > 0) canvas.translate(sin(_t * 90) * 10 * _shake, cos(_t * 77) * 8 * _shake);
    _drawBackdrop(canvas);
    final hp = _hoopPos;
    final half = _hoop.half * _wideK;
    _drawBoardAndPig(canvas, hp, half);
    final orb = _orb;
    if (orb != null && _hoopT >= 1) _drawOrb(canvas, orb);

    // Coin trail, then the coin (behind the net so a basket looks like it drops through).
    for (final d in _trail) {
      final a = 1 - (_t - d.t) / _trailLife;
      canvas.drawCircle(Offset(d.x, d.y), _f.coinR * 0.75 * a, _fill(_goldDark));
    }
    if (_dragStart != null) {
      _drawAim(canvas);
    } else if (_sim.flying || _wait > 0 && _afterBasket) {
      if (_sim.flying) _drawCoin(canvas, _sim.x, _sim.y, _sim.angle, _sq, 1);
    } else if (!isOver && _wait <= 0) {
      _drawCoin(canvas, _f.startX, _f.startY, 0, 0, 0.3 + 0.7 * Curves01.overshoot(_spawnT));
    }
    _drawNetAndRim(canvas, hp, half);

    for (final s in _sparks) {
      final f = 1 - s.age / s.life;
      final p = Offset(s.x, s.y);
      canvas.drawCircle(p, s.size * (0.4 + f), _fill(_ink));
      canvas.drawCircle(p, s.size * (0.4 + f) - 1.6, _fill(s.color));
    }
    for (final p in _pops) {
      final f = p.age / _Pop.life;
      final pop = 1 + 0.3 * sin(min(1, p.age * 7) * pi);
      final at = Offset(p.x.clamp(70, w - 70).toDouble(), p.y - 50 * (1 - (1 - f) * (1 - f)));
      if (f < 0.7 || (p.age * 20).floor().isEven) _text(canvas, p.text, at, p.size * pop, p.color);
    }
    canvas.restore();
    _drawHud(canvas, w, k);
  }

  void _drawOrb(Canvas c, Offset o) {
    final r = 16 * _k * (1 + 0.08 * sin(_t * 6));
    _outCircle(c, o, r, _blue, 3);
    final bolt = Path()
      ..moveTo(o.dx + r * 0.15, o.dy - r * 0.8)
      ..lineTo(o.dx - r * 0.5, o.dy + r * 0.1)
      ..lineTo(o.dx - r * 0.02, o.dy + r * 0.1)
      ..lineTo(o.dx - r * 0.2, o.dy + r * 0.8)
      ..lineTo(o.dx + r * 0.5, o.dy - r * 0.2)
      ..lineTo(o.dx + r * 0.04, o.dy - r * 0.2)
      ..close();
    c.drawPath(bolt, _fill(_gold));
    c.drawPath(bolt, _line(2));
  }

  void _drawHud(Canvas canvas, double w, double k) {
    // Time bar under the host HUD.
    final bar = RRect.fromRectAndRadius(Rect.fromLTWH(16, 98, w - 32, 12), const Radius.circular(6));
    final frac = (_run.timeLeft / dunkRunSeconds).clamp(0.0, 1.0);
    canvas.drawRRect(bar, _fill(_ink));
    if (frac > 0) {
      final col = _run.timeLeft < 5 ? _red : (_run.timeLeft < 12 ? _orange : _green);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(16, 98, (w - 32) * frac, 12), const Radius.circular(6)),
        _fill(col),
      );
    }
    canvas.drawRRect(bar, _line(2.5, _cream));
    for (var i = 0; i < dunkMaxLives; i++) {
      if (i < max(3, _run.lives)) _heart(canvas, Offset(30 + i * 34, 136), 11, i < _run.lives);
    }
    final mult = streakMultiplier(_run.streak);
    var y = 154.0;
    if (mult > 1) {
      _chip(canvas, 'Streak x$mult', _green, 124, y, 1);
    }
    var cy = 120.0;
    if (_slowT > 0) {
      _chip(canvas, 'Slow-mo ${_slowT.ceil()}s', _blue, w - 12, cy, _slowT / 8);
      cy += 36;
    }
    if (_dblT > 0) _chip(canvas, '2x Score ${_dblT.ceil()}s', _gold, w - 12, cy, _dblT / 8);
  }
}

/// Tiny easing helpers (no Flutter animation import needed).
abstract final class Curves01 {
  static double easeOut(double t) => 1 - (1 - t) * (1 - t) * (1 - t);
  static double overshoot(double t) {
    const s = 1.70158;
    final u = t - 1;
    return 1 + (s + 1) * u * u * u + s * u * u;
  }
}

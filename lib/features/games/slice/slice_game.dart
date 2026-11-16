import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flutter/painting.dart' show FontWeight, TextPainter, TextSpan, TextStyle, TextDirection;

import '../../../core/sfx.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'slice_rules.dart';

// Market stall palette: solid colours, ink outlines.
const _ink = Color(0xFF1D1B2E);
const _wall = Color(0xFF2A7F86);
const _wallDark = Color(0xFF226B72);
const _shelf = Color(0xFF1B565C);
const _wood = Color(0xFFC07B3F);
const _woodLight = Color(0xFFDDA062);
const _woodDark = Color(0xFF9A5E2C);
const _red = Color(0xFFFF5348);
const _cream = Color(0xFFFFF3DC);
const _gold = Color(0xFFFFC530);
const _silver = Color(0xFFC9D3DD);
const _bronze = Color(0xFFD98A4A);
const _pink = Color(0xFFFF9EB5);
const _sack = Color(0xFFC9A26B);
const _green = Color(0xFF1FB86B);
const _blue = Color(0xFF2F8CFF);

const _maxLives = 5;
const _trailLife = 2.0;
const _labels = ['100% returns!', 'Hot tip', 'Sure shot', 'Double fast', 'Zero risk'];

class _Obj {
  _Obj(this.kind, this.x, this.y, this.vx, this.vy, this.r, this.vr, {this.label = 0})
    : hp = kind == SliceKind.bag ? 2 : 1;
  final SliceKind kind;
  double x, y, vx, vy, r, vr, rot = 0, cool = 0, wob = 0;
  int hp;
  final int label;
}

class _Half {
  _Half(this.o, this.side, this.cutRel, this.x, this.y, this.vx, this.vy, this.vr);
  final _Obj o;
  final double side, cutRel, vr;
  double x, y, vx, vy, rot = 0, age = 0;
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color, this.size, this.life);
  double x, y, vx, vy, age = 0;
  final Color color;
  final double size, life;
}

class _Pop {
  _Pop(this.text, this.x, this.y, this.color, this.size, {this.life = 0.9});
  final String text;
  final double x, y, size, life;
  final Color color;
  double age = 0;
}

class _Spawn {
  _Spawn(this.delay, this.kind);
  double delay;
  final SliceKind kind;
}

/// Coin Slash: swipe through coins, avoid scam bombs.
class SliceGame extends ArcadeGame with DragCallbacks {
  SliceGame(super.config);

  @override
  List<PowerupType> get boosts => const [
    PowerupType.slowMo,
    PowerupType.doubleScore,
    PowerupType.extraLife,
    PowerupType.shield,
  ];

  late final Random _rng = Random(config.seed ?? DateTime.now().microsecondsSinceEpoch);
  final _clock = Stopwatch()..start();
  final _tracker = SwipeTracker();
  final _objs = <_Obj>[];
  final _halves = <_Half>[];
  final _sparks = <_Spark>[];
  final _pops = <_Pop>[];
  final _pending = <_Spawn>[];
  final _trail = <(double, double, double)>[]; // x, y, clock time
  final _tpCache = <String, TextPainter>{};

  int _lives = 3, _streak = 0;
  bool _shield = false;
  double _t = 0, _slowT = 0, _dblT = 0, _dilate = 0, _shake = 0, _flash = 0, _calm = 1.2;
  double _waveT = 0.4, _orbT = 18 + 6.0, _dead = -1;
  double _lastSwipeSfx = -9;
  Offset? _last;
  double _lastT = 0;

  double get _k => (size.x / 390).clamp(0.8, 1.3);
  double get _counterTop => size.y - 96;
  double get _speed => min(1.25, 1 + _t / 240) * (1 + (config.difficulty - 1) * 0.04);
  int get _mult => streakMultiplier(_streak);

  // ------------------------------------------------------------------ input

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final p = event.localPosition;
    _last = Offset(p.x, p.y);
    _lastT = _clock.elapsedMicroseconds / 1e6;
    _tracker.end();
    _trail.add((p.x, p.y, _lastT));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final last = _last;
    if (last == null || paused || isOver) return;
    final now = _clock.elapsedMicroseconds / 1e6;
    final p = event.localEndPosition;
    final cur = Offset(p.x, p.y);
    final fast = _tracker.move((cur - last).distance, now - _lastT, now);
    _trail.add((cur.dx, cur.dy, now));
    if (_trail.length > 10) _trail.removeAt(0);
    if (fast && _dead < 0) {
      if (now - _lastSwipeSfx > 0.3 && _tracker.count == 0) {
        _lastSwipeSfx = now;
        Sound.play(Sfx.swipe);
      }
      _slice(last, cur);
    }
    _last = cur;
    _lastT = now;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _tracker.end();
    _last = null;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _tracker.end();
    _last = null;
  }

  // ------------------------------------------------------------------ rules

  void _slice(Offset a, Offset b) {
    final angle = atan2(b.dy - a.dy, b.dx - a.dx);
    for (final o in List.of(_objs)) {
      if (o.cool > 0 || !_objs.contains(o)) continue;
      if (segmentHitsCircle(a.dx, a.dy, b.dx, b.dy, o.x, o.y, o.r * 1.12)) _cut(o, angle);
    }
  }

  void _cut(_Obj o, double angle) {
    switch (o.kind) {
      case SliceKind.bomb:
        _objs.remove(o);
        _bomb(o);
      case SliceKind.orb:
        _objs.remove(o);
        _split(o, angle);
        _burst(o.x, o.y, _gold, 12, 260);
        _pops.add(_Pop('Boost!', o.x, o.y - 30, _gold, 26));
        Sound.play(Sfx.coin);
        requestBoost();
      case SliceKind.bag when o.hp > 1:
        o.hp--;
        o.cool = 0.3;
        o.wob = 1;
        o.vy -= 140;
        _burst(o.x, o.y, _gold, 6, 200);
        Sound.play(Sfx.coin);
      case SliceKind.bag:
        _objs.remove(o);
        _split(o, angle);
        coins.value += 2;
        _award(o, 10, merge: true);
        _burst(o.x, o.y, _gold, 16, 340);
      case SliceKind.piggy:
        _objs.remove(o);
        _split(o, angle);
        _award(o, 3, merge: true);
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + (i - 2) * 0.55 + (_rng.nextDouble() - 0.5) * 0.2;
          final v = 330 + _rng.nextDouble() * 120;
          _objs.add(_Obj(SliceKind.mini, o.x, o.y, cos(a) * v * 0.7, sin(a) * v, 15 * _k, 0)..cool = 0.18);
        }
        _burst(o.x, o.y, _pink, 10, 300);
      default:
        _objs.remove(o);
        _split(o, angle);
        if (o.kind == SliceKind.gold) coins.value++;
        _award(o, _value(o.kind));
        _burst(o.x, o.y, _colorOf(o.kind), 8, 260);
    }
  }

  int _value(SliceKind k) => switch (k) {
    SliceKind.silver => 2,
    SliceKind.gold => 5,
    SliceKind.bag => 10,
    SliceKind.piggy => 3,
    _ => 1,
  };

  void _award(_Obj o, int base, {bool merge = false}) {
    final hit = _tracker.hit();
    _streak++;
    final pts = (base * _mult + hit.bonus) * (_dblT > 0 ? 2 : 1);
    score.value += pts;
    _pops.add(_Pop('+$pts', o.x, o.y - o.r, _dblT > 0 ? _gold : _cream, base >= 5 ? 30 : 22));
    if (hit.count >= 3) {
      _pops.add(_Pop('x${hit.count} Combo', size.x / 2, size.y * 0.3, _gold, 34 + min(hit.count, 8) * 2, life: 1.1));
      Sound.play(Sfx.perfect);
      if (hit.count >= 5) _dilate = 0.28;
    } else {
      Sound.play(merge ? Sfx.merge : Sfx.coin);
    }
  }

  void _bomb(_Obj o) {
    final res = resolveBomb(_lives, _shield);
    _shield = res.shield;
    _tracker.end();
    if (!res.cleared) {
      _burst(o.x, o.y, _cream, 14, 220);
      _pops.add(_Pop('Defused!', o.x, o.y - 30, _green, 28));
      Sound.play(Sfx.powerup);
      return;
    }
    _lives = res.lives;
    _streak = 0;
    _shake = 1;
    _flash = 1;
    _calm = 1.0;
    _pending.clear();
    for (final x in _objs) {
      _burst(x.x, x.y, _cream, 5, 180);
    }
    _objs.clear();
    _burst(o.x, o.y, _red, 22, 420);
    _pops.add(_Pop('Scam!', o.x, o.y - 30, _red, 34, life: 1.1));
    Sound.play(Sfx.crash);
    if (_lives <= 0) _dead = 0.8;
  }

  void _miss(_Obj o) {
    if (o.kind == SliceKind.gold || o.kind == SliceKind.bag) {
      if (_streak >= 3) _pops.add(_Pop('Streak lost', o.x.clamp(70, size.x - 70), _counterTop - 30, _red, 20));
      _streak = 0;
    }
  }

  void _split(_Obj o, double angle) {
    final cutRel = angle - o.rot;
    final nx = -sin(angle), ny = cos(angle);
    for (final s in const [-1.0, 1.0]) {
      _halves.add(
        _Half(
          o,
          s,
          cutRel,
          o.x,
          o.y,
          o.vx * 0.6 + nx * s * 150,
          o.vy * 0.6 + ny * s * 150 - 60,
          s * (3 + _rng.nextDouble() * 3),
        ),
      );
    }
  }

  void _burst(double x, double y, Color c, int n, double speed) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * pi * 2, v = speed * (0.3 + _rng.nextDouble() * 0.7);
      final col = i.isEven ? c : _gold;
      _sparks.add(
        _Spark(x, y, cos(a) * v, sin(a) * v - 80, col, (3 + _rng.nextDouble() * 3) * _k, 0.5 + _rng.nextDouble() * 0.3),
      );
    }
  }

  Color _colorOf(SliceKind k) => switch (k) {
    SliceKind.silver => _silver,
    SliceKind.gold => _gold,
    SliceKind.bag => _sack,
    SliceKind.piggy => _pink,
    _ => _bronze,
  };

  double _radius(SliceKind k) =>
      _k *
      switch (k) {
        SliceKind.bronze => 24,
        SliceKind.silver => 28,
        SliceKind.gold => 32,
        SliceKind.bag => 38,
        SliceKind.piggy => 40,
        SliceKind.bomb => 34,
        SliceKind.orb => 28,
        SliceKind.mini => 15,
      };

  void _spawn(SliceKind kind) {
    final r = _radius(kind);
    final g = size.y * 1.25 * _speed * _speed;
    final startY = _counterTop + r;
    final vy = tossVy(g, startY, tossPeakY(_rng, size.y));
    final x = size.x * (0.12 + _rng.nextDouble() * 0.76);
    final land = size.x * (0.1 + _rng.nextDouble() * 0.8);
    final vx = (land - x) / (2 * vy / g);
    _objs.add(_Obj(kind, x, startY, vx, -vy, r, (_rng.nextDouble() - 0.5) * 3, label: _rng.nextInt(_labels.length)));
  }

  // ------------------------------------------------------------------ update

  @override
  void update(double dt) {
    super.update(dt);
    dt = dt.clamp(0.0, 0.05).toDouble();
    if (size.x == 0) return;
    _slowT = max(0, _slowT - dt);
    _dblT = max(0, _dblT - dt);
    _dilate = max(0, _dilate - dt);
    _shake = max(0, _shake - dt * 2.2);
    _flash = max(0, _flash - dt * 2.5);
    final now = _clock.elapsedMicroseconds / 1e6;
    _trail.removeWhere((p) => now - p.$3 > _trailLife);
    if (_tracker.active && _last != null && now - _lastT > 0.3) _tracker.end();
    final sdt = dt * (_slowT > 0 ? 0.5 : 1) * (_dilate > 0 ? 0.35 : 1);
    _t += sdt;

    if (_dead >= 0) {
      _dead -= dt;
      if (_dead < 0) gameOver();
    } else if (!isOver) {
      _spawner(sdt);
    }

    final g = size.y * 1.25 * _speed * _speed;
    for (final o in List.of(_objs)) {
      o.cool = max(0, o.cool - sdt);
      o.wob = max(0, o.wob - sdt * 3);
      o.vy += g * sdt * (o.kind == SliceKind.mini ? 0.8 : 1);
      o.x += o.vx * sdt;
      o.y += o.vy * sdt;
      o.rot += o.vr * sdt;
      if ((o.x < o.r && o.vx < 0) || (o.x > size.x - o.r && o.vx > 0)) o.vx = -o.vx;
      if (o.vy > 0 && o.y > _counterTop + o.r * 0.5) {
        _objs.remove(o);
        _miss(o);
      }
    }
    for (final h in _halves) {
      h.age += sdt;
      h.vy += g * sdt;
      h.vx *= 1 - 0.3 * sdt;
      h.rot += h.vr * sdt;
      h.x += h.vx * sdt;
      h.y += h.vy * sdt;
    }
    _halves.removeWhere((h) => h.y - h.o.r > size.y || h.age > 3);
    for (final s in _sparks) {
      s.age += sdt;
      s.vy += 700 * sdt;
      s.x += s.vx * sdt;
      s.y += s.vy * sdt;
    }
    _sparks.removeWhere((s) => s.age > s.life);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age > p.life);
  }

  void _spawner(double dt) {
    if (_calm > 0) {
      _calm -= dt;
      return;
    }
    for (final s in List.of(_pending)) {
      s.delay -= dt;
      if (s.delay <= 0) {
        _pending.remove(s);
        _spawn(s.kind);
      }
    }
    _orbT -= dt;
    if (_orbT <= 0) {
      _orbT = 25 + _rng.nextDouble() * 4 - 2;
      if (!_objs.any((o) => o.kind == SliceKind.orb)) _pending.add(_Spawn(0.3, SliceKind.orb));
    }
    _waveT -= dt;
    if (_waveT <= 0) {
      var d = 0.0;
      for (final k in planWave(_rng, _t)) {
        _pending.add(_Spawn(d, k));
        d += 0.12 + _rng.nextDouble() * 0.16;
      }
      _waveT = d + waveGap(_t);
    }
  }

  @override
  void applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.slowMo:
        _slowT = 6;
      case PowerupType.doubleScore:
        _dblT = 8;
      case PowerupType.extraLife:
        _lives = min(_maxLives, _lives + 1);
      case PowerupType.shield:
        _shield = true;
      case PowerupType.magnet:
        break;
    }
  }

  @override
  void revive() {
    _lives = 1;
    _dead = -1;
    _streak = 0;
    _objs.clear();
    _halves.clear();
    _pending.clear();
    _tracker.end();
    _calm = 1.5;
    _waveT = 0.3;
  }

  // ------------------------------------------------------------------ rendering

  TextPainter _tp(String s, double fs, Color c, {bool stroke = false}) {
    final key = '$s|${fs.round()}|${c.toARGB32()}|$stroke';
    if (_tpCache.length > 300) _tpCache.clear();
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

  Paint _fill(Color c) => Paint()..color = c;
  Paint _line(double w, [Color c = _ink]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = c;

  void _outlined(Canvas c, Path p, Color fill, double w) {
    c.drawPath(p, _fill(fill));
    c.drawPath(p, _line(w));
  }

  void _drawBackdrop(Canvas c) {
    final w = size.x, h = size.y;
    c.drawRect(Rect.fromLTWH(0, 0, w, h), _fill(_wall));
    for (var x = 28.0; x < w; x += 56) {
      c.drawRect(Rect.fromLTWH(x, 0, 3, h), _fill(_wallDark));
    }
    // Shelf with jars and crates on the back wall.
    final sy = h * 0.36;
    for (final (fx, fw, fh) in const [(0.1, 30.0, 40.0), (0.22, 24.0, 52.0), (0.7, 34.0, 36.0), (0.84, 26.0, 48.0)]) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(w * fx, sy - fh, fw, fh), const Radius.circular(6));
      c.drawRRect(r, _fill(_shelf));
      c.drawRRect(r, _line(2.5));
    }
    c.drawRect(Rect.fromLTWH(0, sy, w, 12), _fill(_woodDark));
    c.drawRect(Rect.fromLTWH(0, sy, w, 12), _line(2.5));
    // Awning.
    const stripeH = 56.0;
    final n = (w / 48).ceil() + 1, sw = w / n;
    for (var i = 0; i < n; i++) {
      final col = i.isEven ? _red : _cream;
      final p = Path()
        ..moveTo(i * sw, 0)
        ..lineTo((i + 1) * sw, 0)
        ..lineTo((i + 1) * sw, stripeH)
        ..arcToPoint(Offset(i * sw, stripeH), radius: Radius.circular(sw / 2), clockwise: true)
        ..close();
      _outlined(c, p, col, 3);
    }
  }

  void _drawCounter(Canvas c) {
    final w = size.x, top = _counterTop;
    c.drawRect(Rect.fromLTWH(0, top, w, size.y - top), _fill(_wood));
    for (var x = 0.0; x < w; x += 78) {
      c.drawRect(Rect.fromLTWH(x, top + 16, 3, size.y - top), _fill(_woodDark));
    }
    c.drawRect(Rect.fromLTWH(0, top, w, 16), _fill(_woodLight));
    c.drawLine(Offset(0, top + 16), Offset(w, top + 16), _line(3));
    c.drawLine(Offset(0, top), Offset(w, top), _line(3.5));
  }

  void _drawObj(Canvas c, _Obj o) {
    final r = o.r;
    switch (o.kind) {
      case SliceKind.bronze:
      case SliceKind.silver:
      case SliceKind.gold:
      case SliceKind.mini:
        final col = o.kind == SliceKind.mini ? _gold : _colorOf(o.kind);
        c.drawCircle(Offset(0, r * 0.12), r, _fill(_ink));
        c.drawCircle(Offset.zero, r, _fill(col));
        c.drawCircle(Offset.zero, r, _line(r * 0.12));
        c.drawCircle(Offset.zero, r * 0.68, _line(r * 0.08, _ink.withValues(alpha: 0.35)));
        if (o.kind != SliceKind.mini) {
          final label = switch (o.kind) {
            SliceKind.silver => '2',
            SliceKind.gold => '5',
            _ => '1',
          };
          _text(c, label, Offset.zero, r * 0.95, _cream);
        }
        c.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r * 0.85),
          pi * 1.05,
          pi * 0.3,
          false,
          _line(r * 0.09, _cream),
        );
      case SliceKind.bag:
        final body = Path()
          ..moveTo(-r * 0.3, -r * 0.55)
          ..cubicTo(-r * 1.3, -r * 0.1, -r * 1.1, r * 0.95, 0, r * 0.95)
          ..cubicTo(r * 1.1, r * 0.95, r * 1.3, -r * 0.1, r * 0.3, -r * 0.55)
          ..close();
        _outlined(c, body, _sack, r * 0.1);
        final neck = Path()
          ..moveTo(-r * 0.3, -r * 0.55)
          ..lineTo(-r * 0.5, -r * 0.95)
          ..lineTo(r * 0.5, -r * 0.95)
          ..lineTo(r * 0.3, -r * 0.55)
          ..close();
        _outlined(c, neck, _sack, r * 0.1);
        c.drawLine(Offset(-r * 0.36, -r * 0.55), Offset(r * 0.36, -r * 0.55), _line(r * 0.18, _red));
        c.drawLine(Offset(-r * 0.36, -r * 0.55), Offset(r * 0.36, -r * 0.55), _line(r * 0.04));
        _text(c, '10', Offset(0, r * 0.2), r * 0.75, _cream);
        if (o.hp < 2) c.drawLine(Offset(-r * 0.5, r * 0.55), Offset(r * 0.3, -r * 0.1), _line(r * 0.07));
      case SliceKind.piggy:
        for (final s in const [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(s * r * 0.3, -r * 0.75)
            ..lineTo(s * r * 0.75, -r * 1.1)
            ..lineTo(s * r * 0.85, -r * 0.45)
            ..close();
          _outlined(c, ear, _pink, r * 0.09);
          final leg = Rect.fromLTWH(s * r * 0.5 - r * 0.15, r * 0.65, r * 0.3, r * 0.35);
          c.drawRect(leg, _fill(_pink));
          c.drawRect(leg, _line(r * 0.09));
        }
        final body = Rect.fromCenter(center: Offset.zero, width: r * 2.1, height: r * 1.7);
        c.drawOval(body, _fill(_pink));
        c.drawOval(body, _line(r * 0.1));
        final snout = Rect.fromCenter(center: Offset(r * 0.85, r * 0.1), width: r * 0.6, height: r * 0.5);
        c.drawOval(snout, _fill(const Color(0xFFFF7FA0)));
        c.drawOval(snout, _line(r * 0.08));
        c.drawCircle(Offset(r * 0.45, -r * 0.25), r * 0.09, _fill(_ink));
        c.drawLine(Offset(-r * 0.3, -r * 0.62), Offset(r * 0.1, -r * 0.62), _line(r * 0.12));
        c.drawArc(
          Rect.fromCenter(center: Offset(-r * 1.0, 0), width: r * 0.5, height: r * 0.5),
          -1.2,
          4,
          false,
          _line(r * 0.09),
        );
      case SliceKind.bomb:
        // Fuse and spark first so the body overlaps its base.
        final fuse = Path()
          ..moveTo(0, -r * 0.85)
          ..quadraticBezierTo(r * 0.15, -r * 1.3, r * 0.55, -r * 1.35);
        c.drawPath(fuse, _line(r * 0.2));
        c.drawPath(fuse, _line(r * 0.09, _sack));
        final sp = Offset(r * 0.62, -r * 1.38);
        c.drawCircle(sp, r * 0.2, _fill(_gold));
        c.drawCircle(sp, r * 0.2, _line(r * 0.07));
        c.drawCircle(Offset.zero, r, _fill(const Color(0xFF14121F)));
        c.drawCircle(Offset.zero, r, _line(r * 0.1));
        c.drawCircle(Offset(-r * 0.4, -r * 0.4), r * 0.16, _fill(const Color(0xFF5A5670)));
        c.drawRect(Rect.fromCenter(center: Offset(0, r * 0.12), width: r * 1.8, height: r * 0.5), _fill(_cream));
        c.drawRect(Rect.fromCenter(center: Offset(0, r * 0.12), width: r * 1.8, height: r * 0.5), _line(r * 0.06));
        _text(c, _labels[o.label], Offset(0, r * 0.12), r * 0.27, _red, outline: false);
      case SliceKind.orb:
        c.drawCircle(Offset.zero, r, _fill(_blue));
        c.drawCircle(Offset.zero, r, _line(r * 0.12));
        final bolt = Path()
          ..moveTo(r * 0.15, -r * 0.8)
          ..lineTo(-r * 0.5, r * 0.1)
          ..lineTo(-r * 0.02, r * 0.1)
          ..lineTo(-r * 0.2, r * 0.8)
          ..lineTo(r * 0.5, -r * 0.2)
          ..lineTo(r * 0.04, -r * 0.2)
          ..close();
        _outlined(c, bolt, _gold, r * 0.08);
    }
  }

  void _heart(Canvas c, Offset at, double s, bool full) {
    final p = Path()
      ..moveTo(at.dx, at.dy + s * 0.9)
      ..cubicTo(at.dx - s * 1.5, at.dy + s * 0.1, at.dx - s * 0.9, at.dy - s * 1.0, at.dx, at.dy - s * 0.3)
      ..cubicTo(at.dx + s * 0.9, at.dy - s * 1.0, at.dx + s * 1.5, at.dy + s * 0.1, at.dx, at.dy + s * 0.9);
    _outlined(c, p, full ? _red : const Color(0xFF6E8A8E), 3);
  }

  void _chip(Canvas c, String text, Color col, double right, double y, double frac) {
    final tp = _tp(text, 15, _ink);
    final w = tp.width + 22;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(right - w, y, w, 28), const Radius.circular(14));
    c.drawRRect(rect.shift(const Offset(0, 3)), _fill(_ink));
    c.drawRRect(rect, _fill(col));
    if (frac < 1) {
      c.save();
      c.clipRRect(rect);
      c.drawRect(Rect.fromLTWH(right - w, y + 22, w * frac, 6), _fill(_ink.withValues(alpha: 0.35)));
      c.restore();
    }
    c.drawRRect(rect, _line(2.5));
    tp.paint(c, Offset(right - w + 11, y + 14 - tp.height / 2));
  }

  void _drawHalf(Canvas c, _Half h) {
    c.save();
    c.translate(h.x, h.y);
    c.rotate(h.o.rot + h.rot);
    c.rotate(h.cutRel);
    final r = h.o.r * 1.6;
    c.clipRect(h.side > 0 ? Rect.fromLTRB(-r, 0, r, r) : Rect.fromLTRB(-r, -r, r, 0));
    c.rotate(-h.cutRel);
    _drawObj(c, h.o);
    c.rotate(h.cutRel);
    c.drawLine(Offset(-r, 0), Offset(r, 0), _line(5));
    c.restore();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x == 0) return;
    final w = size.x;
    canvas.save();
    if (_shake > 0) {
      canvas.translate((_rng.nextDouble() - 0.5) * 22 * _shake, (_rng.nextDouble() - 0.5) * 22 * _shake);
    }
    _drawBackdrop(canvas);
    for (final o in _objs) {
      canvas.save();
      canvas.translate(o.x, o.y);
      canvas.rotate(o.rot + sin(o.wob * 18) * 0.25 * o.wob);
      if (o.wob > 0) canvas.scale(1 + 0.12 * o.wob);
      _drawObj(canvas, o);
      canvas.restore();
    }
    for (final h in _halves) {
      _drawHalf(canvas, h);
    }
    for (final s in _sparks) {
      final k = 1 - s.age / s.life;
      final p = Offset(s.x, s.y);
      canvas.drawCircle(p, s.size * (0.4 + k), _fill(_ink));
      canvas.drawCircle(p, s.size * (0.4 + k) - 1.6, _fill(s.color));
    }
    _drawCounter(canvas);
    _drawTrail(canvas);

    for (final p in _pops) {
      final k = p.age / p.life;
      final pop = 1 + 0.3 * sin(min(1, p.age * 7) * pi);
      final at = Offset(p.x.clamp(60, w - 60).toDouble(), p.y - 50 * (1 - (1 - k) * (1 - k)));
      if (k < 0.7 || (p.age * 20).floor().isEven) _text(canvas, p.text, at, p.size * pop, p.color);
    }
    canvas.restore();

    for (var i = 0; i < _maxLives; i++) {
      if (i < max(3, _lives)) _heart(canvas, Offset(30 + i * 34, 112), 11, i < _lives);
    }
    var y = 134.0;
    if (_mult > 1) {
      _chip(canvas, 'Streak x$_mult', _green, 124, y, 1);
      y += 36;
    }
    var cy = 100.0;
    if (_shield) {
      _chip(canvas, 'Shield', _green, w - 12, cy, 1);
      cy += 36;
    }
    if (_slowT > 0) {
      _chip(canvas, 'Slow-mo ${_slowT.ceil()}s', _blue, w - 12, cy, _slowT / 6);
      cy += 36;
    }
    if (_dblT > 0) {
      _chip(canvas, '2x Score ${_dblT.ceil()}s', _gold, w - 12, cy, _dblT / 8);
    }
    if (_flash > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, size.y), _fill(const Color(0xFFFFFFFF).withValues(alpha: _flash)));
    }
  }

  void _drawTrail(Canvas c) {
    if (_trail.length < 2) return;
    final now = _clock.elapsedMicroseconds / 1e6;
    final n = _trail.length;
    for (final pass in [0, 1, 2]) {
      for (var i = 1; i < n; i++) {
        final a = _trail[i - 1], b = _trail[i];
        final fade = (1 - (now - b.$3) / _trailLife).clamp(0.0, 1.0);
        final wd = (2 + 14 * i / n) * fade * _k;
        final col = pass == 0 ? _ink : (pass == 1 ? const Color(0xFF7FE3FF) : const Color(0xFFFFFFFF));
        final pw = pass == 0 ? wd + 6 : (pass == 1 ? wd : wd * 0.4);
        c.drawLine(Offset(a.$1, a.$2), Offset(b.$1, b.$2), _line(pw, col));
      }
    }
  }
}

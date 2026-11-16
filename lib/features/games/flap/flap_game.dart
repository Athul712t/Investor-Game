import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../core/sfx.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_colors.dart';
import '../_shared/arcade_game.dart';
import 'flap_art.dart';
import 'flap_rules.dart';

const _gravity = 1250.0;
const _thrust = -400.0;
const _maxFall = 650.0;
const _hitR = 10.0; // forgiving: the art is about 44 x 24
const _orbEvery = 12;
const _symbols = ['ZYN', 'FOOB', 'MNGO', 'ORBT', 'PLNT', 'RKT', 'KOI', 'BLIP', 'TUMB', 'NOVA'];

enum _Kind { coin, gold, orb }

class _Pickup {
  _Pickup(this.kind, this.x, this.y);
  final _Kind kind;
  double x, y;
  bool magnetised = false;
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, {this.square = false, this.gravity = 0});
  double x, y, vx, vy, life, size, age = 0, gravity;
  final Color color;
  final bool square;
}

class _Pop {
  _Pop(this.text, this.x, this.y, this.color);
  final String text;
  final double x, y;
  final Color color;
  double age = 0;
}

class _Tick {
  _Tick(this.sym, this.pct, this.up, this.width);
  final TextPainter sym, pct;
  final bool up;
  final double width;
}

/// Candle Hop: tap to thrust, fly the rocket through gaps between candlesticks.
class FlapGame extends ArcadeGame with TapCallbacks, KeyboardEvents {
  FlapGame(super.config);

  @override
  List<PowerupType> get boosts => const [
    PowerupType.shield,
    PowerupType.slowMo,
    PowerupType.magnet,
    PowerupType.doubleScore,
  ];

  final _fx = Random(3); // visual-only randomness, keeps the seeded run deterministic
  late final Random _rng = Random(config.seed ?? DateTime.now().microsecondsSinceEpoch);
  final _pairs = <CandlePair>[];
  final _pickups = <_Pickup>[];
  final _sparks = <_Spark>[];
  final _pops = <_Pop>[];
  late final List<List<double>> _clouds = List.generate(
    7,
    (i) => [_rng.nextDouble(), 0.08 + _rng.nextDouble() * 0.5, 0.6 + _rng.nextDouble() * 0.7, i.isEven ? 0.18 : 0.32],
  );
  late final List<List<double>> _stars = List.generate(
    36,
    (_) => [_rng.nextDouble(), _rng.nextDouble() * 0.55, 2 + _rng.nextDouble() * 2, _rng.nextDouble() * 6.28],
  );
  List<_Tick>? _ticker;
  double _tickerW = 0;

  double _t = 0, _worldX = 0, _cloudX = 0;
  double _ry = 0, _vy = 0, _rot = 0, _squash = 0, _flame = 0, _smokeT = 0, _shake = 0;
  double _grace = 1.2, _invuln = 0, _deadTimer = -1, _spin = 0;
  double _slowLeft = 0, _magnetLeft = 0, _doubleLeft = 0;
  bool _started = false, _shield = false, _dead = false;
  int _passed = 0, _spawned = 0;
  double _lastCentre = 0;

  double get _rx => max(90.0, size.x * 0.28);
  double get _top => flapHud;
  double get _ground => size.y - flapGroundInset;
  double get _speed => speedFor(_passed) * (_slowLeft > 0 ? 0.6 : 1);

  @override
  Future<void> onLoad() async {
    _ry = (_top + _ground) / 2;
  }

  // ------------------------------------------------------------------ input

  @override
  void onTapDown(TapDownEvent event) => thrust();

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      thrust();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void thrust() {
    if (isOver || paused || _dead || size.x == 0) return;
    _started = true;
    _vy = _thrust;
    _squash = 1;
    _flame = 1;
    Sound.play(Sfx.jump, volume: 0.5);
    _burst(_rx - 20, _ry, 3, white, 60);
  }

  // ------------------------------------------------------------------ rules

  void _spawn() {
    while (_pairs.isEmpty || _pairs.last.x < size.x + 80) {
      final x = _pairs.isEmpty ? _rx + 340 : _pairs.last.x + flapSpacing;
      final n = _spawned;
      final centre = nextCentre(_lastCentre, _rng, n, _top, _ground);
      final gap = gapFor(n, _ground - _top);
      _spawned++;
      final p = CandlePair(
        x: x,
        centre: centre,
        gap: gap,
        index: _spawned,
        greenTop: _rng.nextBool(),
        greenBottom: _rng.nextBool(),
        lenTop: 0.45 + _rng.nextDouble() * 0.3,
        lenBottom: 0.45 + _rng.nextDouble() * 0.3,
      );
      _pairs.add(p);
      if (p.golden) {
        _pickups.add(_Pickup(_Kind.gold, x, centre));
      } else if (_spawned % _orbEvery == 6) {
        _pickups.add(_Pickup(_Kind.orb, x - flapSpacing / 2, (_lastCentre + centre) / 2));
      } else if (_spawned > 1 && _rng.nextDouble() < 0.55) {
        _pickups.add(_Pickup(_Kind.coin, x, centre + (_rng.nextDouble() - 0.5) * gap * 0.35));
      }
      _lastCentre = centre;
    }
  }

  CandlePair? get _nextPair {
    for (final p in _pairs) {
      if (p.x + candleBodyW / 2 + _hitR > _rx) return p;
    }
    return null;
  }

  void _hit() {
    final res = resolveHit(shield: _shield);
    _shield = res.shield;
    Sound.play(Sfx.crash, volume: res.dead ? 1 : 0.6);
    if (res.dead) {
      _dead = true;
      _deadTimer = 0.9;
      _vy = -320;
      _spin = 9;
      _shake = 16;
      _burst(_rx, _ry, 26, ArcadeColors.coral, 260, gravity: 700, square: true);
      _burst(_rx, _ry, 14, white, 200, gravity: 700, square: true);
      _burst(_rx, _ry, 10, ArcadeColors.amber, 220, gravity: 700);
    } else {
      _ry = _nextPair?.centre ?? (_top + _ground) / 2;
      _vy = 0;
      _invuln = 1.3;
      _shake = 7;
      _burst(_rx, _ry, 14, ArcadeColors.sky, 180);
      _pops.add(_Pop('Shield!', _rx, _ry - 36, ArcadeColors.sky));
    }
  }

  @override
  void applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.shield:
        _shield = true;
      case PowerupType.slowMo:
        _slowLeft = 6;
      case PowerupType.magnet:
        _magnetLeft = 8;
      case PowerupType.doubleScore:
        _doubleLeft = 8;
      case PowerupType.extraLife:
        break;
    }
  }

  @override
  void revive() {
    _dead = false;
    _deadTimer = -1;
    _spin = 0;
    _rot = 0;
    _vy = 0;
    _pairs.removeWhere((p) => (p.x - _rx).abs() < candleBodyW / 2 + _hitR + 70);
    _spawn();
    _ry = _nextPair?.centre ?? (_top + _ground) / 2;
    _invuln = 2;
    _grace = 0;
    _started = true;
  }

  // ----------------------------------------------------------------- update

  @override
  void update(double dt) {
    super.update(dt);
    if (size.x == 0) return;
    dt = dt.clamp(0, 0.05);
    _t += dt;
    _squash *= exp(-dt * 9);
    _flame = max(0, _flame - dt * 4);
    _shake *= exp(-dt * 7);
    _grace = max(0, _grace - dt);
    _invuln = max(0, _invuln - dt);
    _slowLeft = max(0, _slowLeft - dt);
    _magnetLeft = max(0, _magnetLeft - dt);
    _doubleLeft = max(0, _doubleLeft - dt);
    _cloudX += (_started ? _speed : 20) * dt;
    _updateEffects(dt);

    if (_dead) {
      _vy = min(_maxFall, _vy + _gravity * dt);
      _ry = min(_ground - 14, _ry + _vy * dt);
      _rot += _spin * dt;
      if (_deadTimer > 0 && (_deadTimer -= dt) <= 0 && !isOver) gameOver();
      return;
    }

    if (_started) {
      _vy = min(_maxFall, _vy + _gravity * dt);
      _ry += _vy * dt;
    } else {
      _ry = (_top + _ground) / 2 + sin(_t * 3) * 8;
    }
    _rot += (atan2(_vy, 260).clamp(-0.55, 0.75) - _rot) * min(1, dt * 10);

    if (_started) {
      final dx = _speed * dt;
      _worldX += dx;
      for (final p in _pairs) {
        p.x -= dx;
      }
      for (final p in _pickups) {
        p.x -= dx;
      }
    }
    _spawn();
    _pairs.removeWhere((p) => p.x < -80);
    _pickups.removeWhere((p) => p.x < -60);

    _smokeT -= dt;
    if (_started && _smokeT <= 0) {
      _smokeT = 0.05;
      _sparks.add(_Spark(_rx - 22, _ry + 2, -20, -8, 0.7, 6 + 3 * _flame, white, gravity: -20));
    }

    _collide();
    _collect(dt);
  }

  void _collide() {
    final safe = _grace > 0 || _invuln > 0;
    final floor = _ground - _hitR, ceil = _top + _hitR;
    if (_ry > floor || _ry < ceil) {
      if (safe) {
        _ry = _ry.clamp(ceil, floor).toDouble();
        _vy = 0;
      } else {
        _hit();
        return;
      }
    }
    for (final p in _pairs) {
      if ((p.x - _rx).abs() > candleBodyW / 2 + _hitR + 30) continue;
      final c = pairClearance(p, _ground, _rx, _ry, _hitR);
      if (c < p.minClear) p.minClear = c;
      if (c < 0 && !safe) {
        _hit();
        return;
      }
    }
    for (final p in collectPassed(_pairs, _rx)) {
      _passed++;
      score.value += _doubleLeft > 0 ? 2 : 1;
      Sound.play(Sfx.tick);
      if (p.minClear < 7 && !safe) {
        _pops.add(_Pop('Close!', _rx + 30, _ry - 34, ArcadeColors.amber));
      }
    }
  }

  void _collect(double dt) {
    for (final p in _pickups.toList()) {
      final dx = _rx - p.x, dy = _ry - p.y, d = sqrt(dx * dx + dy * dy);
      if (p.kind != _Kind.orb && _magnetLeft > 0 && d < 300) p.magnetised = true;
      if (p.magnetised && d > 1) {
        final v = 560 * dt / d;
        p.x += dx * min(1, v);
        p.y += dy * min(1, v);
      }
      if (d > (p.kind == _Kind.coin ? 26 : 34)) continue;
      _pickups.remove(p);
      switch (p.kind) {
        case _Kind.coin:
          coins.value += 1;
          Sound.play(Sfx.coin);
          _burst(p.x, p.y, 8, ArcadeColors.amber, 150, square: true);
          _pops.add(_Pop('+1', p.x, p.y - 24, ArcadeColors.amber));
        case _Kind.gold:
          coins.value += 3;
          Sound.play(Sfx.perfect);
          _burst(p.x, p.y, 18, ArcadeColors.amber, 230, square: true);
          _burst(p.x, p.y, 8, white, 180);
          _pops.add(_Pop('+3', p.x, p.y - 30, ArcadeColors.amber));
        case _Kind.orb:
          _burst(p.x, p.y, 14, ArcadeColors.amber, 200);
          _pops.add(_Pop('Boost!', p.x, p.y - 30, white));
          requestBoost();
      }
    }
  }

  void _burst(double x, double y, int n, Color col, double speed, {double gravity = 0, bool square = false}) {
    for (var i = 0; i < n; i++) {
      final a = _fx.nextDouble() * 2 * pi, v = speed * (0.35 + _fx.nextDouble() * 0.65);
      _sparks.add(
        _Spark(
          x,
          y,
          cos(a) * v,
          sin(a) * v,
          0.4 + _fx.nextDouble() * 0.4,
          3 + _fx.nextDouble() * 4,
          col,
          square: square,
          gravity: gravity,
        ),
      );
    }
  }

  void _updateEffects(double dt) {
    for (final s in _sparks) {
      s.age += dt;
      s.vy += s.gravity * dt;
      s.x += s.vx * dt - (_started && !_dead ? _speed * dt * 0.6 : 0);
      s.y += s.vy * dt;
    }
    _sparks.removeWhere((s) => s.age > s.life);
    if (_sparks.length > 160) _sparks.removeRange(0, _sparks.length - 160);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age > 0.9);
  }

  // -------------------------------------------------------------- rendering

  void _buildTicker() {
    TextPainter tp(String s, Color c) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'Fredoka', fontSize: 14, fontWeight: FontWeight.w600, color: c),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Random(11);
    _ticker = [
      for (final s in _symbols)
        () {
          final up = r.nextBool();
          final sym = tp(s, ArcadeColors.text);
          final pct = tp(
            '${(r.nextDouble() * 4 + 0.1).toStringAsFixed(1)}%',
            up ? ArcadeColors.mint : ArcadeColors.coral,
          );
          return _Tick(sym, pct, up, sym.width + pct.width + 14 + 26);
        }(),
    ];
    _tickerW = _ticker!.fold(0.0, (a, b) => a + b.width);
  }

  /// Blend of the three skies: index of the current one and the mix toward the next.
  (int, double) get _phase {
    final p = _passed / 22.0, i = p.floor();
    final f = ((p - i - 0.7) / 0.3).clamp(0.0, 1.0).toDouble();
    return (i % 3, Curves.easeInOut.transform(f));
  }

  Color _sky(List<Color> a, List<Color> b, int i, double f) => Color.lerp(a[i], b[i], f)!;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x == 0) return;
    final w = size.x, h = size.y, gy = _ground;
    final (ph, mix) = _phase;
    final skies = [skyDay, skySunset, skyNight];
    final a = skies[ph], b = skies[(ph + 1) % 3];
    final double night = (ph == 2 ? 1 - mix : 0) + (ph == 1 ? mix : 0);

    canvas.save();
    if (_shake > 0.3) canvas.translate((_fx.nextDouble() - 0.5) * _shake, (_fx.nextDouble() - 0.5) * _shake);

    // Sky as stepped flat bands.
    final bandH = (gy + 6) / 7;
    for (var i = 0; i < 7; i++) {
      canvas.drawRect(Rect.fromLTWH(-20, i * bandH - 1, w + 40, bandH + 2), Paint()..color = _sky(a, b, i, mix));
    }

    for (final s in _stars) {
      final al = (night * (0.5 + 0.5 * sin(_t * 2 + s[3]))).clamp(0.0, 1.0).toDouble();
      if (al > 0.05) {
        canvas.drawRect(Rect.fromLTWH(s[0] * w, s[1] * gy, s[2], s[2]), Paint()..color = white.withValues(alpha: al));
      }
    }

    // Sun or moon.
    final sunCol = Color.lerp(sunColors[ph], sunColors[(ph + 1) % 3], mix)!;
    final sy = lerpDouble(sunY[ph], sunY[(ph + 1) % 3], mix)!;
    canvas.drawCircle(Offset(w * 0.78, sy), 32, Paint()..color = sunCol);
    canvas.drawCircle(
      Offset(w * 0.78, sy),
      32,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ArcadeColors.ink,
    );

    // Chart-paper grid.
    final grid = Paint()
      ..color = Color.lerp(ArcadeColors.ink, white, night)!.withValues(alpha: 0.09)
      ..strokeWidth = 1.5;
    for (var x = -(_worldX % 56); x < w; x += 56) {
      canvas.drawLine(Offset(x, _top), Offset(x, gy), grid);
    }
    for (var y = gy; y > _top; y -= 56) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Parallax clouds.
    final cc = Color.lerp(cloudColors[ph], cloudColors[(ph + 1) % 3], mix)!;
    for (final c in _clouds) {
      final span = w + 200;
      final x = ((c[0] * span - _cloudX * c[3]) % span + span) % span - 100;
      drawCloud(canvas, x, 110 + c[1] * (gy - 200), c[2] * (c[3] > 0.25 ? 1.0 : 0.8), cc);
    }

    for (final p in _pairs) {
      if (p.x > -candleBodyW && p.x < w + candleBodyW) drawCandlePair(canvas, p, gy);
    }

    for (final p in _pickups) {
      switch (p.kind) {
        case _Kind.coin:
          drawCoin(canvas, p.x, p.y, 11, _t * 4 + p.y, ArcadeColors.amber);
        case _Kind.gold:
          drawCoin(canvas, p.x, p.y, 17, _t * 3, const Color(0xFFFFD84D));
        case _Kind.orb:
          drawBolt(canvas, p.x, p.y, 15, _t);
      }
    }

    for (final s in _sparks.where((s) => !s.square && s.color == white && s.gravity < 0)) {
      final k = s.age / s.life;
      _puff(canvas, s.x, s.y, s.size * (1 - k * 0.6));
    }

    _drawRocket(canvas);

    for (final s in _sparks.where((s) => !(s.color == white && s.gravity < 0))) {
      final k = 1 - s.age / s.life;
      final r = s.size * (0.4 + 0.6 * k);
      final fill = Paint()..color = s.color;
      if (s.square) {
        canvas.drawRect(Rect.fromCenter(center: Offset(s.x, s.y), width: r * 2, height: r * 2), fill);
      } else {
        canvas.drawCircle(Offset(s.x, s.y), r, fill);
      }
    }

    _drawGround(canvas, w, h, gy);
    canvas.restore();

    for (final p in _pops) {
      final k = p.age / 0.9;
      final sc = 1 + 0.3 * sin(min(1, p.age * 6) * pi);
      outlinedText(
        canvas,
        p.text,
        Offset(p.x, p.y - k * 30),
        (p.text == 'Close!' ? 24 : 20) * sc,
        p.color,
        alpha: (1 - max(0.0, (k - 0.6) / 0.4)).clamp(0.0, 1.0).toDouble(),
      );
    }
    if (!_started && !_dead) {
      outlinedText(canvas, 'Tap to hop', Offset(w / 2, _ry + 70 + sin(_t * 4) * 4), 24, white);
    }
    _chips(canvas);
  }

  void _puff(Canvas c, double x, double y, double r) {
    c.drawCircle(Offset(x, y), r, Paint()..color = white);
    c.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ArcadeColors.ink,
    );
  }

  void _drawRocket(Canvas canvas) {
    if (_invuln > 0 && !_dead && (_t * 12).floor().isOdd) return;
    canvas.save();
    canvas.translate(_rx, _ry);
    canvas.rotate(_rot);
    canvas.scale(1 - 0.16 * _squash, 1 + 0.22 * _squash);
    drawRocket(canvas, flame: _dead ? 0 : _flame, t: _t);
    canvas.restore();
    if (_shield && !_dead) {
      canvas.drawCircle(
        Offset(_rx, _ry),
        30 + sin(_t * 8) * 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = ArcadeColors.sky,
      );
      canvas.drawCircle(
        Offset(_rx, _ry),
        33,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ArcadeColors.ink,
      );
    }
  }

  /// The chart's axis with scrolling ticks, and a decorative ticker tape below it.
  void _drawGround(Canvas canvas, double w, double h, double gy) {
    if (_ticker == null) _buildTicker();
    canvas.drawRect(Rect.fromLTWH(-20, gy, w + 40, h - gy + 20), Paint()..color = ArcadeColors.surface);
    canvas.drawRect(Rect.fromLTWH(-20, gy, w + 40, 20), Paint()..color = ArcadeColors.surfaceHi);
    final tick = Paint()
      ..color = ArcadeColors.textDim
      ..strokeWidth = 2.5;
    const step = 28.0;
    final first = (_worldX / step).floor();
    for (var i = 0; i * step < w + step; i++) {
      final idx = first + i;
      final x = idx * step - _worldX;
      canvas.drawLine(Offset(x, gy + 3), Offset(x, gy + (idx % 4 == 0 ? 15 : 8)), tick);
    }
    canvas.drawRect(Rect.fromLTWH(-20, gy - 2, w + 40, 5), Paint()..color = ArcadeColors.ink);

    final ty = gy + 28;
    canvas.drawRect(Rect.fromLTWH(-20, ty, w + 40, 36), Paint()..color = ArcadeColors.ink);
    canvas.drawRect(Rect.fromLTWH(-20, ty + 36, w + 40, 3), Paint()..color = ArcadeColors.line);
    var x = -((_t * 38 + _worldX * 0.5) % _tickerW);
    var i = 0;
    while (x < w) {
      final it = _ticker![i % _ticker!.length];
      it.sym.paint(canvas, Offset(x + 10, ty + (36 - it.sym.height) / 2));
      final ax = x + 10 + it.sym.width + 11;
      triangle(canvas, ax, ty + 18, 5, it.up, it.up ? ArcadeColors.mint : ArcadeColors.coral);
      it.pct.paint(canvas, Offset(ax + 10, ty + (36 - it.pct.height) / 2));
      x += it.width;
      i++;
    }
  }

  /// Active powerup timers, below the host HUD.
  void _chips(Canvas canvas) {
    final chips = <(String, Color, double)>[
      if (_shield) ('Shield', ArcadeColors.sky, 1),
      if (_slowLeft > 0) ('Slow-mo', ArcadeColors.mint, _slowLeft / 6),
      if (_magnetLeft > 0) ('Magnet', ArcadeColors.coral, _magnetLeft / 8),
      if (_doubleLeft > 0) ('2x', ArcadeColors.amber, _doubleLeft / 8),
    ];
    if (chips.isEmpty) return;
    const cw = 78.0, gap = 8.0;
    var x = (size.x - (chips.length * cw + (chips.length - 1) * gap)) / 2;
    for (final (label, col, f) in chips) {
      final r = Rect.fromLTWH(x, 98, cw, 26);
      pill(canvas, r, col, f);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ArcadeColors.ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r.left + (cw - tp.width) / 2, r.top + (26 - tp.height) / 2));
      x += cw + gap;
    }
  }
}

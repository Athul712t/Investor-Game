import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter/painting.dart' show FontWeight, TextAlign, TextDirection, TextPainter, TextSpan, TextStyle;

import '../../../core/sfx.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import '../_shared/quick_data.dart';
import 'whack_rules.dart';

// Market stall palette: solid colours, ink outlines.
const _ink = Color(0xFF1D1B2E);
const _wall = Color(0xFF2A7F86);
const _wallDark = Color(0xFF226B72);
const _wood = Color(0xFFC07B3F);
const _woodLight = Color(0xFFDDA062);
const _woodDark = Color(0xFF9A5E2C);
const _holeDark = Color(0xFF3B2210);
const _red = Color(0xFFFF5348);
const _cream = Color(0xFFFFF3DC);
const _gold = Color(0xFFFFC530);
const _sack = Color(0xFFC9A26B);
const _green = Color(0xFF1FB86B);
const _blue = Color(0xFF2F8CFF);
const _scamTile = Color(0xFF6E1F3A);
const _grey = Color(0xFF6E8A8E);

const _popLife = 0.9;
const _flyLife = 0.55;

class _Fly {
  _Fly(this.tile, this.x, this.y, this.vx, this.vy, this.vr);
  final WhackTile tile;
  double x, y, vx, vy, rot = 0, age = 0;
  final double vr;
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.color, this.size, this.life);
  double x, y, vx, vy, age = 0;
  final Color color;
  final double size, life;
}

class _Pop {
  _Pop(this.text, this.x, this.y, this.color, this.size);
  final String text;
  final double x, y, size;
  final Color color;
  double age = 0;
}

/// Springy 0 -> 1 with a little overshoot.
double _spring(double x) => x <= 0 ? 0 : 1 - exp(-7 * x) * cos(13 * x);

/// Scam Whack: tap the real offers, leave the scams. 30 seconds, 3 lives.
class WhackGame extends ArcadeGame with TapCallbacks {
  WhackGame(super.config);

  @override
  List<PowerupType> get boosts => const [PowerupType.slowMo, PowerupType.extraLife, PowerupType.doubleScore];

  late final Random _fx = Random(config.seed ?? 11); // visual randomness only
  WhackRules? _rules;
  final _flies = <_Fly>[];
  final _sparks = <_Spark>[];
  final _pops = <_Pop>[];
  final _tpCache = <String, TextPainter>{};
  final _fill = Paint();
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  double _cell = 100, _gx = 0, _gy = 0;
  double _shake = 0, _flash = 0;
  int _lastTick = 99;
  final _awning = <Path>[];
  late Path _bag, _bolt, _heart;

  Rect _cellRect(int hole) => Rect.fromLTWH(_gx + (hole % 3) * _cell, _gy + (hole ~/ 3) * _cell, _cell, _cell);

  // ------------------------------------------------------------------ setup

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

  /// Grid sits between the host HUD (150) and the host quiz card (bottom 200).
  void _layout() {
    final w = size.x, h = size.y;
    final avail = max(150.0, h - 200 - 150);
    _cell = min(min(avail / 3, w * 0.94 / 3), 150);
    _gx = (w - _cell * 3) / 2;
    _gy = 150 + (avail - _cell * 3) / 2;
    _awning.clear();
    final n = (w / 48).ceil() + 1, sw = w / n;
    for (var i = 0; i < n; i++) {
      _awning.add(
        Path()
          ..moveTo(i * sw, 0)
          ..lineTo((i + 1) * sw, 0)
          ..lineTo((i + 1) * sw, 50)
          ..arcToPoint(Offset(i * sw, 50), radius: Radius.circular(sw / 2), clockwise: true)
          ..close(),
      );
    }
    final c = _cell;
    _bag = Path()
      ..moveTo(-c * 0.1, -c * 0.2)
      ..cubicTo(-c * 0.42, -c * 0.05, -c * 0.38, c * 0.3, 0, c * 0.3)
      ..cubicTo(c * 0.38, c * 0.3, c * 0.42, -c * 0.05, c * 0.1, -c * 0.2)
      ..lineTo(c * 0.16, -c * 0.3)
      ..lineTo(-c * 0.16, -c * 0.3)
      ..close();
    final b = c * 0.3;
    _bolt = Path()
      ..moveTo(b * 0.15, -b * 0.9)
      ..lineTo(-b * 0.5, b * 0.1)
      ..lineTo(-b * 0.02, b * 0.1)
      ..lineTo(-b * 0.2, b * 0.9)
      ..lineTo(b * 0.5, -b * 0.2)
      ..lineTo(b * 0.04, -b * 0.2)
      ..close();
    _heart = Path()
      ..moveTo(0, 0.9)
      ..cubicTo(-1.5, 0.1, -0.9, -1.0, 0, -0.3)
      ..cubicTo(0.9, -1.0, 1.5, 0.1, 0, 0.9);
  }

  @override
  Future<void> onLoad() async {
    final data = await QuickGameData.load();
    _rules = WhackRules(
      Random(config.seed ?? DateTime.now().microsecondsSinceEpoch),
      offers: data.realOffers,
      scams: data.scams,
    );
    _layout();
  }

  // ------------------------------------------------------------------ input

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition;
    for (var i = 0; i < whackHoles; i++) {
      if (_cellRect(i).contains(Offset(p.x, p.y))) {
        tapHole(i);
        return;
      }
    }
  }

  /// A tap on hole [i]; public so tests can drive it.
  void tapHole(int i) {
    final r = _rules;
    if (r == null || isOver || paused) return;
    final o = r.tap(i);
    if (o == null) return;
    final rect = _cellRect(i);
    final at = Offset(rect.center.dx, rect.center.dy - _cell * 0.1);
    score.value = r.score;
    coins.value = r.coins;
    final t = o.tile;
    _fly(t, at, scam: o.lifeLost);
    if (o.lifeLost) {
      _shake = 1;
      _flash = 1;
      _burst(at, _red, 18, 380);
      _pop('Scam!', at, _red, 30);
      Sound.play(Sfx.crash);
      Haptics.heavy();
    } else if (t.kind == TileKind.boost) {
      _burst(at, _blue, 12, 300);
      _pop('Boost!', at, _gold, 28);
      Sound.play(Sfx.powerup);
      Haptics.medium();
      requestBoost();
    } else {
      _burst(at, t.kind == TileKind.offer ? _green : _gold, 10, 300);
      _pop('+${o.points}', at, t.kind == TileKind.coin ? _gold : _cream, o.points >= 3 ? 30 : 24);
      if (o.comboStep) {
        _pop('x${r.combo} combo', Offset(size.x / 2, _gy - 22), _gold, 28);
        Sound.play(Sfx.perfect);
      } else {
        Sound.play(Sfx.coin);
      }
      Haptics.light();
    }
    if (r.over) gameOver();
  }

  // ------------------------------------------------------------------ fx

  void _fly(WhackTile t, Offset at, {required bool scam}) {
    if (_flies.length >= 6) _flies.removeAt(0);
    final dir = (_fx.nextDouble() - 0.5) * 2;
    _flies.add(_Fly(t, at.dx, at.dy, dir * 220, -(scam ? 260.0 : 420.0), dir * 6));
  }

  void _burst(Offset at, Color c, int n, double speed) {
    for (var i = 0; i < n && _sparks.length < 80; i++) {
      final a = _fx.nextDouble() * pi * 2, v = speed * (0.3 + _fx.nextDouble() * 0.7);
      _sparks.add(
        _Spark(
          at.dx,
          at.dy,
          cos(a) * v,
          sin(a) * v - 80,
          i.isEven ? c : _gold,
          3 + _fx.nextDouble() * 3,
          0.4 + _fx.nextDouble() * 0.3,
        ),
      );
    }
  }

  void _pop(String text, Offset at, Color c, double size) {
    if (_pops.length >= 6) _pops.removeAt(0);
    _pops.add(_Pop(text, at.dx, at.dy - _cell * 0.3, c, size));
  }

  // ------------------------------------------------------------------ update

  @override
  void update(double dt) {
    super.update(dt);
    dt = min(dt, 1 / 30);
    final r = _rules;
    if (r == null || size.x == 0) return;
    _shake = max(0, _shake - dt * 2.2);
    _flash = max(0, _flash - dt * 2.5);
    for (final f in _flies) {
      f.age += dt;
      f.vy += 1400 * dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.rot += f.vr * dt;
    }
    _flies.removeWhere((f) => f.age > _flyLife);
    for (final s in _sparks) {
      s.age += dt;
      s.vy += 700 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    _sparks.removeWhere((s) => s.age > s.life);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age > _popLife);
    if (isOver) return;

    r.step(dt);
    final left = r.remaining;
    if (left <= 5 && left > 0) {
      final sec = left.ceil();
      if (sec != _lastTick) {
        _lastTick = sec;
        Sound.play(Sfx.tick);
      }
    } else {
      _lastTick = 99;
    }
    if (r.over) gameOver();
  }

  @override
  void applyPowerup(PowerupType type) {
    final r = _rules;
    if (r == null) return;
    switch (type) {
      case PowerupType.slowMo:
        r.slowMo();
      case PowerupType.doubleScore:
        r.doubleScore();
      case PowerupType.extraLife:
        r.extraLife();
      default:
        break;
    }
  }

  @override
  void revive() {
    _rules?.revive();
    _flies.clear();
    _lastTick = 99;
  }

  // ------------------------------------------------------------------ rendering

  TextPainter _tp(String s, double fs, Color c, {double maxW = 0, bool stroke = false}) {
    final key = '$s|${fs.round()}|${c.toARGB32()}|${maxW.round()}|$stroke';
    if (_tpCache.length > 200) _tpCache.clear();
    return _tpCache.putIfAbsent(key, () {
      final style = TextStyle(
        fontFamily: 'Fredoka',
        fontSize: fs,
        fontWeight: FontWeight.w700,
        height: 1.05,
        color: stroke ? null : c,
        foreground: stroke
            ? (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fs * 0.28
                ..strokeJoin = StrokeJoin.round
                ..color = _ink)
            : null,
      );
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
      );
      tp.layout(maxWidth: maxW > 0 ? maxW : double.infinity);
      return tp;
    });
  }

  void _text(Canvas c, String s, Offset at, double fs, Color col, {double maxW = 0, bool outline = true}) {
    if (outline) {
      final o = _tp(s, fs, col, maxW: maxW, stroke: true);
      o.paint(c, at - Offset(o.width / 2, o.height / 2));
    }
    final t = _tp(s, fs, col, maxW: maxW);
    t.paint(c, at - Offset(t.width / 2, t.height / 2));
  }

  void _f(Canvas c, Rect r, Color col) => c.drawRect(r, _fill..color = col);

  void _outRRect(Canvas c, RRect r, Color col, double w) {
    c.drawRRect(r, _fill..color = col);
    c.drawRRect(
      r,
      _stroke
        ..strokeWidth = w
        ..color = _ink,
    );
  }

  void _outPath(Canvas c, Path p, Color col, double w) {
    c.drawPath(p, _fill..color = col);
    c.drawPath(
      p,
      _stroke
        ..strokeWidth = w
        ..color = _ink,
    );
  }

  void _outCircle(Canvas c, Offset o, double r, Color col, double w) {
    c.drawCircle(o, r, _fill..color = col);
    c.drawCircle(
      o,
      r,
      _stroke
        ..strokeWidth = w
        ..color = _ink,
    );
  }

  void _drawBackdrop(Canvas c) {
    final w = size.x, h = size.y;
    _f(c, Rect.fromLTWH(-30, -30, w + 60, 150), _wall);
    for (var x = 28.0; x < w; x += 56) {
      _f(c, Rect.fromLTWH(x, 0, 3, 120), _wallDark);
    }
    // Counter top.
    _f(c, Rect.fromLTWH(-30, 112, w + 60, h - 82), _wood);
    for (var y = 112.0 + 70; y < h; y += 70) {
      _f(c, Rect.fromLTWH(-30, y, w + 60, 3), _woodDark);
    }
    _f(c, Rect.fromLTWH(-30, 112, w + 60, 14), _woodLight);
    c.drawLine(
      const Offset(-30, 126),
      Offset(w + 30, 126),
      _stroke
        ..strokeWidth = 3
        ..color = _ink,
    );
    c.drawLine(
      const Offset(-30, 112),
      Offset(w + 30, 112),
      _stroke
        ..strokeWidth = 3.5
        ..color = _ink,
    );
    for (var i = 0; i < _awning.length; i++) {
      _outPath(c, _awning[i], i.isEven ? _red : _cream, 3);
    }
  }

  Offset _holeCenter(int i) {
    final r = _cellRect(i);
    return Offset(r.center.dx, r.top + _cell * 0.72);
  }

  void _drawHole(Canvas c, int i) {
    final hc = _holeCenter(i);
    final oval = Rect.fromCenter(center: hc, width: _cell * 0.9, height: _cell * 0.34);
    c.drawOval(oval.inflate(_cell * 0.04).shift(Offset(0, _cell * 0.04)), _fill..color = _ink);
    c.drawOval(oval, _fill..color = _holeDark);
    c.drawOval(
      oval,
      _stroke
        ..strokeWidth = 3.5
        ..color = _ink,
    );
  }

  /// Draws a tile centred at the origin; tile box is (0.84 x 0.72) of a cell.
  void _drawTile(Canvas c, TileKind kind, String label) {
    final cs = _cell, w = cs * 0.84, h = cs * 0.72;
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(cs * 0.14),
    );
    final sw = max(2.5, cs * 0.03);
    switch (kind) {
      case TileKind.coin:
        final r = h * 0.52;
        _outCircle(c, Offset.zero, r, _gold, sw);
        c.drawCircle(
          Offset.zero,
          r * 0.7,
          _stroke
            ..strokeWidth = sw * 0.7
            ..color = _woodDark,
        );
        _text(c, '3', Offset.zero, r * 1.05, _cream);
      case TileKind.bag:
        _outPath(c, _bag, _sack, sw);
        c.drawLine(
          Offset(-cs * 0.13, -cs * 0.2),
          Offset(cs * 0.13, -cs * 0.2),
          _stroke
            ..strokeWidth = sw * 1.6
            ..color = _red,
        );
        _text(c, '5', Offset(0, cs * 0.06), cs * 0.24, _cream);
      case TileKind.offer:
        _outRRect(c, box, _cream, sw);
        final band = Rect.fromLTWH(-w / 2 + sw, -h / 2 + sw, w - 2 * sw, h * 0.2);
        c.drawRRect(
          RRect.fromRectAndCorners(band, topLeft: Radius.circular(cs * 0.11), topRight: Radius.circular(cs * 0.11)),
          _fill..color = _green,
        );
        final ck = Path()
          ..moveTo(-cs * 0.06, -h * 0.4)
          ..lineTo(-cs * 0.02, -h * 0.3)
          ..lineTo(cs * 0.07, -h * 0.47);
        c.drawPath(
          ck,
          _stroke
            ..strokeWidth = sw
            ..color = _cream,
        );
        _text(c, label, Offset(0, h * 0.12), max(9.0, cs * 0.105), _ink, maxW: w * 0.9, outline: false);
      case TileKind.scam:
        _outRRect(c, box, _scamTile, sw);
        final sk = Offset(0, -h * 0.22), sr = h * 0.2;
        c.drawRect(
          Rect.fromCenter(center: sk + Offset(0, sr * 0.9), width: sr * 1.0, height: sr * 0.6),
          _fill..color = _cream,
        );
        _outCircle(c, sk, sr, _cream, sw * 0.7);
        // red bandit mask over the eyes
        final mask = Rect.fromCenter(center: sk + Offset(0, -sr * 0.05), width: sr * 2.3, height: sr * 0.8);
        c.drawRRect(RRect.fromRectAndRadius(mask, Radius.circular(sr * 0.3)), _fill..color = _red);
        c.drawRRect(
          RRect.fromRectAndRadius(mask, Radius.circular(sr * 0.3)),
          _stroke
            ..strokeWidth = sw * 0.7
            ..color = _ink,
        );
        for (final s in const [-1.0, 1.0]) {
          c.drawCircle(sk + Offset(s * sr * 0.5, -sr * 0.05), sr * 0.17, _fill..color = _ink);
        }
        _text(c, label, Offset(0, h * 0.2), max(9.0, cs * 0.1), _cream, maxW: w * 0.9, outline: false);
      case TileKind.boost:
        final r = h * 0.5;
        _outCircle(c, Offset.zero, r, _blue, sw);
        _outPath(c, _bolt, _gold, sw * 0.6);
    }
  }

  void _drawTileAt(Canvas c, WhackTile t, Offset at, double rot, double sx, double sy) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(rot);
    c.scale(sx, sy);
    _drawTile(c, t.kind, t.label);
    c.restore();
  }

  void _drawLive(Canvas c, WhackTile t) {
    final cs = _cell, h = cs * 0.72;
    final hc = _holeCenter(t.hole);
    final rect = _cellRect(t.hole);
    final out = ((t.life - t.age) / 0.15).clamp(0.0, 1.0);
    final rise = _spring(t.age / 0.2) * (out * out * (3 - 2 * out));
    final top = hc.dy + cs * 0.05 - h / 2;
    final y = top + (1 - rise) * (h + cs * 0.1);
    final wob = t.kind == TileKind.scam ? sin(t.age * 16) * 0.09 : 0.0;
    final squash = 1 + 0.08 * sin(min(1, t.age / 0.2) * pi);
    c.save();
    c.clipRect(Rect.fromLTRB(rect.left - cs * 0.1, rect.top - cs * 0.3, rect.right + cs * 0.1, hc.dy + cs * 0.02));
    _drawTileAt(c, t, Offset(hc.dx, y), wob, 1 / squash, squash);
    c.restore();
    // front lip of the hole
    final oval = Rect.fromCenter(center: hc, width: _cell * 0.9, height: _cell * 0.34);
    c.drawArc(
      oval,
      0,
      pi,
      false,
      _stroke
        ..strokeWidth = 4
        ..color = _ink,
    );
  }

  void _drawHeart(Canvas c, Offset at, double s, bool full) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(s);
    c.drawPath(_heart, _fill..color = full ? _red : _grey);
    c.drawPath(
      _heart,
      _stroke
        ..strokeWidth = 3 / s
        ..color = _ink,
    );
    c.restore();
  }

  void _chip(Canvas c, String text, Color col, double right, double y) {
    final tp = _tp(text, 14, _ink);
    final w = tp.width + 20;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(right - w, y, w, 26), const Radius.circular(13));
    c.drawRRect(rect.shift(const Offset(0, 3)), _fill..color = _ink);
    _outRRect(c, rect, col, 2.5);
    tp.paint(c, Offset(right - w + 10, y + 13 - tp.height / 2));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final r = _rules;
    if (r == null || size.x == 0) return;
    final w = size.x;
    canvas.save();
    if (_shake > 0) {
      canvas.translate((_fx.nextDouble() - 0.5) * 20 * _shake, (_fx.nextDouble() - 0.5) * 20 * _shake);
    }
    _drawBackdrop(canvas);
    for (var i = 0; i < whackHoles; i++) {
      _drawHole(canvas, i);
    }
    for (final t in r.tiles) {
      _drawLive(canvas, t);
    }
    for (final f in _flies) {
      final k = f.age / _flyLife;
      final sq = f.age < 0.08 ? 1 - f.age / 0.08 * 0.25 : 1.0;
      _drawTileAt(canvas, f.tile, Offset(f.x, f.y), f.rot, (1 + (1 - sq)) * (1 - k * 0.5), sq * (1 - k * 0.5));
    }
    for (final s in _sparks) {
      final k = 1 - s.age / s.life;
      final p = Offset(s.x, s.y);
      canvas.drawCircle(p, s.size * (0.4 + k), _fill..color = _ink);
      canvas.drawCircle(p, s.size * (0.4 + k) - 1.5, _fill..color = s.color);
    }
    for (final p in _pops) {
      final k = p.age / _popLife;
      final pop = 1 + 0.3 * sin(min(1, p.age * 7) * pi);
      final at = Offset(p.x.clamp(60, w - 60).toDouble(), p.y - 50 * (1 - (1 - k) * (1 - k)));
      if (k < 0.7 || (p.age * 20).floor().isEven) _text(canvas, p.text, at, p.size * pop, p.color);
    }
    canvas.restore();

    // HUD: hearts and time bar sit under the host HUD (top 90).
    for (var i = 0; i < max(3, r.lives); i++) {
      _drawHeart(canvas, Offset(30 + i * 32, 108), 11, i < r.lives);
    }
    if (r.combo >= 3) _chip(canvas, 'Combo ${r.combo}', _gold, w - 16, 96);
    final bar = RRect.fromRectAndRadius(Rect.fromLTWH(16, 130, w - 32, 12), const Radius.circular(6));
    canvas.drawRRect(bar, _fill..color = _cream);
    final frac = (r.remaining / r.duration).clamp(0.0, 1.0);
    if (frac > 0) {
      canvas.save();
      canvas.clipRRect(bar);
      canvas.drawRect(Rect.fromLTWH(16, 130, (w - 32) * frac, 12), _fill..color = r.remaining <= 5 ? _red : _green);
      canvas.restore();
    }
    canvas.drawRRect(
      bar,
      _stroke
        ..strokeWidth = 3
        ..color = _ink,
    );
    var cy = 148.0;
    if (r.slowT > 0) {
      _chip(canvas, 'Slow-mo ${r.slowT.ceil()}s', _blue, w - 16, cy);
      cy += 30;
    }
    if (r.doubleT > 0) _chip(canvas, '2x Score ${r.doubleT.ceil()}s', _gold, w - 16, cy);
    if (_flash > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, size.y), _fill..color = _red.withValues(alpha: _flash * 0.45));
    }
  }
}

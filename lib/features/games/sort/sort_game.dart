import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart' show FontWeight, TextAlign, TextDirection, TextPainter, TextSpan, TextStyle;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../core/sfx.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import '../_shared/quick_data.dart';
import 'sort_rules.dart';

// Mail-room palette: solid colours, ink outlines.
const _ink = Color(0xFF1D1B2E);
const _wall = Color(0xFF2F4858);
const _hole = Color(0xFF223744);
const _holeEdge = Color(0xFF3B5A6D);
const _wood = Color(0xFFC07B3F);
const _woodLight = Color(0xFFDDA062);
const _woodDark = Color(0xFF9A5E2C);
const _belt = Color(0xFF3A3F4A);
const _beltTick = Color(0xFF5A6070);
const _cream = Color(0xFFFFF3DC);
const _paperDeep = Color(0xFFF7E2B8);
const _white = Color(0xFFFFFFFF);
const _boltCard = Color(0xFFFFE9A0);
const _gold = Color(0xFFFFC530);
const _red = Color(0xFFFF5348);
const _green = Color(0xFF1FB86B);
const _blue = Color(0xFF2F8CFF);
const _iceBlue = Color(0xFF9CCBFF);
const _orange = Color(0xFFFF8A2B);
const _binColors = [_blue, _orange];

const _maxSparks = 80;
const _maxPops = 6;
const _maxFlyers = 4;

class _Flyer {
  _Flyer(this.text, this.bolt, this.x, this.y, this.rot, this.left, this.correct);
  final String text;
  final bool bolt, left, correct;
  final double x, y, rot;
  double age = 0;
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

/// Sort Rush: drag each card into the right bin before the 30 seconds run out.
class SortGame extends ArcadeGame with DragCallbacks, TapCallbacks, KeyboardEvents {
  SortGame(super.config);

  @override
  List<PowerupType> get boosts => const [PowerupType.extraLife, PowerupType.slowMo, PowerupType.doubleScore];

  late final Random _rng = Random(config.seed ?? DateTime.now().microsecondsSinceEpoch);
  SortRules? _r;
  SortDeck _deck = QuickGameData.fallback.sortDecks.first;

  final _flyers = <_Flyer>[];
  final _sparks = <_Spark>[];
  final _pops = <_Pop>[];
  final _tpCache = <String, TextPainter>{};
  final _fitCache = <String, TextPainter>{};

  // Reused paints (never allocated per frame).
  final _fp = Paint();
  final _sp = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final _boltPath = Path()
    ..moveTo(0.15, -1)
    ..lineTo(-0.7, 0.15)
    ..lineTo(-0.1, 0.15)
    ..lineTo(-0.3, 1)
    ..lineTo(0.7, -0.2)
    ..lineTo(0.1, -0.2)
    ..close();

  // Layout
  double _w = 390, _h = 844, _k = 1;
  double _cardW = 240, _cardH = 150, _cx = 195, _cy = 300, _binW = 140, _binH = 118, _binY = 506, _span = 117;

  // Card state
  double _dx = 0, _dy = 0, _vx = 0, _vy = 0, _enter = 1;
  bool _dragging = false;
  double _elapsed = 0, _shake = 0, _flash = 0, _clock = 0, _lastTickSec = 99;
  final _bounce = [0.0, 0.0];

  double get _holdSide => _dx.abs() < _span * 0.15 ? 0 : _dx.sign;

  // ------------------------------------------------------------------ layout

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _w = size.x;
    _h = size.y;
    _k = (_w / 390).clamp(0.8, 1.3);
    _binW = min(_w * 0.36, 150);
    _binH = 118 * _k;
    _binY = _h * 0.6;
    _cardW = min(_w * 0.62, 270);
    _cardH = _cardW * 0.62;
    _cx = _w / 2;
    final binTop = _binY - _binH / 2;
    _cy = 150 + (binTop - 150) * 0.5;
    _span = _w * 0.3;
  }

  double _binX(bool left) => left ? _w * 0.2 : _w * 0.8;

  @override
  Future<void> onLoad() async {
    final data = await QuickGameData.load();
    final decks = data.sortDecks.where((d) => d.items.isNotEmpty).toList();
    if (decks.isNotEmpty) _deck = decks[_rng.nextInt(decks.length)];
    _r = SortRules(_deck, _rng);
    _startCard();
  }

  void _startCard() {
    _dx = _dy = _vx = _vy = 0;
    _dragging = false;
    _enter = 0;
  }

  // ------------------------------------------------------------------ input

  bool get _live => _r != null && !paused && !isOver;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_live) _dragging = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_dragging || !_live) return;
    final d = event.localDelta;
    _dx = (_dx + d.x).clamp(-_span * 1.2, _span * 1.2).toDouble();
    _dy = (_dy + d.y * 0.5).clamp(-50.0, 70.0).toDouble();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_dragging) return;
    _dragging = false;
    final side = sortCommitSide(_dx, event.velocity.x, _span);
    if (side != 0 && _live) {
      _commit(side < 0);
    } else {
      _vx = event.velocity.x * 0.05;
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragging = false;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_live) Haptics.light();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_live) _commit(event.localPosition.x < _w / 2);
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && _live) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _commit(true);
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) _commit(false);
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------------ rules

  @visibleForTesting
  SortRules get debugRules => _r!;
  @visibleForTesting
  void debugSort(bool left) => _commit(left);

  double get _enterSpeed => 0.28 - 0.14 * (_elapsed / sortRunSeconds).clamp(0.0, 1.0);

  void _commit(bool left) {
    final r = _r!;
    final card = r.current;
    final bolt = r.bolt;
    final fromX = _cx + _dx, fromY = _cy + _dy, rot = _dx / _span * 0.2;
    final out = r.sort(left);
    Sound.play(Sfx.swipe);
    Haptics.select();
    if (_flyers.length >= _maxFlyers) _flyers.removeAt(0);
    _flyers.add(_Flyer(card.text, bolt, fromX, fromY, rot, left, out.correct));
    final bx = _binX(left);
    if (out.correct) {
      score.value += out.points;
      if (out.coin) coins.value++;
      Sound.play(Sfx.merge);
      _pop('+${out.points}', bx, _binY - _binH / 2 - 10, out.multiplier > 1 ? _gold : _cream, 30);
      _burst(bx, _binY - _binH / 2, _binColors[left ? 0 : 1], 8);
      if (out.comboStep) {
        Sound.play(Sfx.perfect);
        _pop('COMBO x${r.multiplier}!', _w / 2, _cy - _cardH / 2 - 26, _gold, 38, life: 1.2);
      }
      if (out.boost) requestBoost();
    } else {
      _flash = 1;
      _shake = 1;
      Sound.play(Sfx.wrong);
      Haptics.heavy();
      _pop('-2s', _w / 2, 186, _red, 30, life: 1.0);
    }
    _startCard();
  }

  void _pop(String t, double x, double y, Color c, double size, {double life = 0.9}) {
    if (_pops.length >= _maxPops) _pops.removeAt(0);
    _pops.add(_Pop(t, x, y, c, size, life: life));
  }

  void _burst(double x, double y, Color c, int n) {
    for (var i = 0; i < n && _sparks.length < _maxSparks; i++) {
      final a = -pi / 2 + (_rng.nextDouble() - 0.5) * pi * 1.4, v = 120 + _rng.nextDouble() * 240;
      final size = (3 + _rng.nextDouble() * 3) * _k;
      _sparks.add(_Spark(x, y, cos(a) * v, sin(a) * v, i.isEven ? c : _gold, size, 0.4 + _rng.nextDouble() * 0.3));
    }
  }

  @override
  void applyPowerup(PowerupType type) {
    final r = _r;
    if (r == null) return;
    switch (type) {
      case PowerupType.extraLife:
        r.addTime(5);
      case PowerupType.slowMo:
        r.freeze = 4;
      case PowerupType.doubleScore:
        r.doubleLeft = 8;
      default:
    }
    Sound.play(Sfx.powerup);
  }

  @override
  void revive() {
    final r = _r;
    if (r == null) return;
    r.time = 8;
    r.freeze = 0;
    _flyers.clear();
    _lastTickSec = 99;
    _startCard();
  }

  // ------------------------------------------------------------------ update

  @override
  void update(double dt) {
    super.update(dt);
    dt = dt.clamp(0.0, 1 / 30).toDouble();
    final r = _r;
    if (r == null || isOver) return;
    _clock += dt;
    _elapsed += dt;
    r.tick(dt);
    final sec = r.time.ceilToDouble();
    if (sec != _lastTickSec) {
      _lastTickSec = sec;
      if (r.time > 0 && r.time <= 5 && r.freeze <= 0) Sound.play(Sfx.tick);
    }
    _enter = min(1, _enter + dt / _enterSpeed);
    _shake = max(0, _shake - dt * 4);
    _flash = max(0, _flash - dt * 3.5);
    for (var i = 0; i < 2; i++) {
      _bounce[i] = max(0, _bounce[i] - dt * 3);
    }
    if (!_dragging && (_dx != 0 || _dy != 0 || _vx != 0 || _vy != 0)) {
      // Springs back to rest with a slight overshoot.
      _vx += (-_dx * 380 - _vx * 22) * dt;
      _vy += (-_dy * 380 - _vy * 22) * dt;
      _dx += _vx * dt;
      _dy += _vy * dt;
      if (_dx.abs() < 0.3 && _dy.abs() < 0.3 && _vx.abs() < 5 && _vy.abs() < 5) _dx = _dy = _vx = _vy = 0;
    }
    for (final f in _flyers) {
      f.age += dt;
    }
    _flyers.removeWhere((f) {
      final done = f.age >= (f.correct ? 0.26 : 0.55);
      if (done && f.correct) _bounce[f.left ? 0 : 1] = 1;
      return done;
    });
    for (final s in _sparks) {
      s.age += dt;
      s.vy += 700 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    _sparks.removeWhere((s) => s.age >= s.life);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age >= p.life);
    if (r.ended) gameOver();
  }

  // ------------------------------------------------------------------ text

  TextPainter _tp(String s, double fs, Color c, {bool stroke = false}) {
    final key = '$s|${fs.round()}|${c.toARGB32()}|$stroke';
    final hit = _tpCache[key];
    if (hit != null) return hit;
    if (_tpCache.length > 80) _tpCache.remove(_tpCache.keys.first);
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
    return _tpCache[key] = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _text(Canvas c, String s, Offset at, double fs, Color col, {bool outline = true}) {
    if (outline) {
      final o = _tp(s, fs, col, stroke: true);
      o.paint(c, at - Offset(o.width / 2, o.height / 2));
    }
    final t = _tp(s, fs, col);
    t.paint(c, at - Offset(t.width / 2, t.height / 2));
  }

  /// Biggest size that fits [maxLines] lines in [maxW]; cached per text and width.
  TextPainter _fit(String s, double maxW, int maxLines, List<double> sizes) {
    final key = '$s|${maxW.round()}|$maxLines';
    final hit = _fitCache[key];
    if (hit != null) return hit;
    if (_fitCache.length > 40) _fitCache.remove(_fitCache.keys.first);
    late TextPainter tp;
    for (final fs in sizes) {
      tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontFamily: 'Fredoka', fontSize: fs, fontWeight: FontWeight.w700, height: 1.05, color: _ink),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: maxW);
      if (!tp.didExceedMaxLines) break;
    }
    return _fitCache[key] = tp;
  }

  Paint _fill(Color c) => _fp..color = c;
  Paint _line(double w, [Color c = _ink]) => _sp
    ..strokeWidth = w
    ..color = c;

  // ------------------------------------------------------------------ rendering

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final r = _r;
    canvas.save();
    if (_shake > 0) canvas.translate(sin(_clock * 70) * 6 * _shake, cos(_clock * 53) * 3 * _shake);
    _world(canvas);
    if (r != null) {
      _bin(canvas, true);
      _bin(canvas, false);
      for (final f in _flyers) {
        _flyer(canvas, f);
      }
      _card(canvas, r);
    }
    for (final s in _sparks) {
      final a = 1 - s.age / s.life;
      final sz = s.size * a + 1;
      canvas.drawRect(Rect.fromCenter(center: Offset(s.x, s.y), width: sz, height: sz), _fill(s.color));
    }
    canvas.restore();
    if (_flash > 0) canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), _fill(_red.withAlpha((_flash * 90).round())));
    if (r != null) _hud(canvas, r);
    for (final p in _pops) {
      final t = p.age / p.life;
      final pop = t < 0.15 ? Curves.easeOutBack.transform(t / 0.15) : 1.0;
      canvas.save();
      canvas.translate(p.x, p.y - t * 40);
      canvas.scale(pop);
      _text(canvas, p.text, Offset.zero, p.size * _k, p.color);
      canvas.restore();
    }
  }

  void _world(Canvas c) {
    c.drawRect(Rect.fromLTWH(-20, -20, _w + 40, _h + 40), _fill(_wall));
    // Pigeonholes (mail slots) with a few letters poking out.
    final deskTop = _binY - _binH * 0.18;
    const cw = 62.0, ch = 50.0;
    for (var gy = 0; gy * ch < deskTop; gy++) {
      for (var gx = -1; gx * cw < _w + cw; gx++) {
        final x = gx * cw + (gy.isOdd ? 20 : 0);
        final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x + 4, gy * ch + 4, cw - 8, ch - 8), const Radius.circular(5));
        c.drawRRect(rr, _fill(_hole));
        c.drawRRect(rr, _line(2, _holeEdge));
        if ((gx * 7 + gy * 3) % 5 == 0) c.drawRect(Rect.fromLTWH(x + 14, gy * ch + 8, 24, 10), _fill(_cream));
      }
    }
    // Desk.
    c.drawRect(Rect.fromLTWH(-20, deskTop, _w + 40, _h - deskTop + 20), _fill(_wood));
    c.drawRect(Rect.fromLTWH(-20, deskTop, _w + 40, 12), _fill(_woodLight));
    for (var y = deskTop + 70; y < _h; y += 70) {
      c.drawRect(Rect.fromLTWH(-20, y, _w + 40, 3), _fill(_woodDark));
    }
    c.drawLine(Offset(-20, deskTop), Offset(_w + 20, deskTop), _line(3));
    // Conveyor under the card.
    final by = _cy + _cardH / 2 + 4, bh = 24 * _k;
    c.drawRect(Rect.fromLTWH(-20, by, _w + 40, bh), _fill(_belt));
    final off = (_clock * 60) % 28;
    for (var x = -28 + off; x < _w + 28; x += 28) {
      c.drawRect(Rect.fromLTWH(x, by + 8 * _k, 14, 6 * _k), _fill(_beltTick));
    }
    c.drawLine(Offset(-20, by), Offset(_w + 20, by), _line(3));
    c.drawLine(Offset(-20, by + bh), Offset(_w + 20, by + bh), _line(3));
  }

  void _bin(Canvas c, bool left) {
    final i = left ? 0 : 1;
    final hot = _dragging && _holdSide == (left ? -1 : 1);
    final squash = sin(_bounce[i] * pi) * 0.12;
    final sc = 1 + (hot ? 0.07 : 0) + squash;
    final col = _binColors[i];
    c.save();
    c.translate(_binX(left), _binY + _binH / 2);
    c.scale(sc, sc - squash * 1.5);
    c.translate(0, -_binH / 2);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: _binW, height: _binH),
      const Radius.circular(16),
    );
    c.drawRRect(body.shift(const Offset(0, 6)), _fill(_ink));
    c.drawRRect(body, _fill(col));
    // Dark opening at the top, then the front plate with the label.
    final slot = Rect.fromLTWH(-_binW / 2 + 8, -_binH / 2 + 7, _binW - 16, 14 * _k);
    c.drawRRect(RRect.fromRectAndRadius(slot, const Radius.circular(7)), _fill(_ink));
    final plate = RRect.fromRectAndRadius(
      Rect.fromLTWH(-_binW / 2 + 9, -_binH / 2 + 28 * _k, _binW - 18, _binH - 28 * _k - 10),
      const Radius.circular(10),
    );
    c.drawRRect(plate, _fill(hot ? _gold : _cream));
    c.drawRRect(plate, _line(2.5));
    c.drawRRect(body, _line(3.5, hot ? _gold : _ink));
    if (hot) c.drawRRect(body.deflate(5), _line(3));
    final tp = _fit(left ? _deck.leftLabel : _deck.rightLabel, plate.width - 10, 2, const [21, 18, 16, 14, 12]);
    tp.paint(c, Offset(plate.center.dx - tp.width / 2, plate.center.dy - tp.height / 2));
    c.restore();
  }

  void _drawBolt(Canvas c, double x, double y, double s) {
    c.save();
    c.translate(x, y);
    c.scale(s);
    c.drawPath(_boltPath, _fill(_gold));
    c.drawPath(_boltPath, _line(2.5 / s));
    c.restore();
  }

  void _cardBody(Canvas c, String text, bool bolt, double lift) {
    final rect = Rect.fromCenter(center: Offset.zero, width: _cardW, height: _cardH);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(18 * _k));
    c.drawRRect(rr.shift(Offset(0, 6 + lift)), _fill(_ink));
    c.drawRRect(rr, _fill(bolt ? _boltCard : _white));
    c.drawRRect(rr, _line(4));
    // Envelope-style stripe at the top.
    c.drawRect(Rect.fromLTWH(-_cardW / 2 + 14, -_cardH / 2 + 12, _cardW * 0.3, 7), _fill(bolt ? _gold : _paperDeep));
    final tp = _fit(text, _cardW - 32, 3, const [32, 28, 25, 22, 19, 16]);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2 + 6));
    if (bolt) _drawBolt(c, _cardW / 2 - 6, -_cardH / 2 + 4, 17 * _k);
  }

  void _card(Canvas c, SortRules r) {
    final e = Curves.easeOutBack.transform(_enter.clamp(0.0, 1.0));
    c.save();
    c.translate(_cx + _dx, _cy + _dy - (1 - e) * 70);
    c.rotate((_dx / _span).clamp(-1.0, 1.0) * 0.2);
    c.scale((0.72 + 0.28 * e) * (_dragging ? 1.05 : 1));
    _cardBody(c, r.current.text, r.bolt, _dragging ? 4 : 0);
    c.restore();
  }

  void _flyer(Canvas c, _Flyer f) {
    final life = f.correct ? 0.26 : 0.55;
    final t = (f.age / life).clamp(0.0, 1.0);
    final tx = _binX(f.left), ty = _binY - _binH / 2 + 8;
    double x, y, rot, s = 1;
    if (f.correct) {
      final q = t * t;
      x = f.x + (tx - f.x) * q;
      y = f.y + (ty - f.y) * q;
      s = 1 - 0.65 * q;
      rot = f.rot + (f.left ? -1 : 1) * 0.5 * q;
    } else if (t < 0.3) {
      // Bumps the bin...
      final q = Curves.easeOut.transform(t / 0.3);
      x = f.x + (tx - f.x) * 0.55 * q;
      y = f.y + (ty - f.y) * 0.45 * q;
      rot = f.rot;
    } else {
      // ...then bounces back out, spinning.
      final q = (t - 0.3) / 0.7;
      final ox = f.x + (tx - f.x) * 0.55, oy = f.y + (ty - f.y) * 0.45;
      x = ox - (tx - f.x) * 0.9 * q;
      y = oy - 340 * q + 350 * q * q;
      rot = f.rot + (f.left ? 1 : -1) * 6 * q;
    }
    c.save();
    c.translate(x, y);
    c.rotate(rot);
    c.scale(s);
    _cardBody(c, f.text, f.bolt, 0);
    c.restore();
  }

  void _hud(Canvas c, SortRules r) {
    // Timer bar.
    const barY = 100.0, barH = 18.0;
    final barW = _w - 32;
    final frac = (r.time / sortRunSeconds).clamp(0.0, 1.0);
    final frozen = r.freeze > 0;
    final col = frozen ? _blue : (r.time <= 5 ? _red : (r.time <= 10 ? _orange : _green));
    final track = RRect.fromRectAndRadius(Rect.fromLTWH(16, barY, barW, barH), const Radius.circular(9));
    c.drawRRect(track, _fill(_cream));
    if (frac > 0.01) {
      final fill = Rect.fromLTWH(16, barY, max(barH, barW * frac), barH);
      c.drawRRect(RRect.fromRectAndRadius(fill, const Radius.circular(9)), _fill(col));
    }
    c.drawRRect(track, _line(3));
    final pulse = r.time <= 5 && !frozen ? 1 + 0.12 * sin(_clock * 12) : 1.0;
    _text(c, '${r.time.ceil()}', Offset(_w / 2, barY + barH / 2), 22 * pulse, _white);
    // Combo pill with pips.
    final m = r.multiplier;
    const rowY = 148.0;
    final pill = RRect.fromRectAndRadius(Rect.fromLTWH(16, rowY - 15, 112, 30), const Radius.circular(15));
    c.drawRRect(pill.shift(const Offset(0, 3)), _fill(_ink));
    c.drawRRect(pill, _fill(m > 1 ? _gold : _cream));
    c.drawRRect(pill, _line(2.5));
    _text(c, 'x$m', Offset(38, rowY), 19, m > 1 ? _white : _ink, outline: m > 1);
    final into = r.streak % 5;
    for (var i = 0; i < 5; i++) {
      final at = Offset(66 + i * 12.0, rowY);
      c.drawCircle(at, 4.5, _fill(i < into ? _green : _paperDeep));
      c.drawCircle(at, 4.5, _line(1.8));
    }
    // Active boosts.
    var x = _w - 16;
    void tag(String s, Color bg) {
      final tp = _tp(s, 15, _ink);
      final w = tp.width + 20;
      x -= w;
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x, rowY - 14, w, 28), const Radius.circular(14));
      c.drawRRect(rr.shift(const Offset(0, 3)), _fill(_ink));
      c.drawRRect(rr, _fill(bg));
      c.drawRRect(rr, _line(2.5));
      tp.paint(c, Offset(x + 10, rowY - tp.height / 2));
      x -= 8;
    }

    if (r.doubleLeft > 0) tag('x2 SCORE ${r.doubleLeft}', _gold);
    if (r.freeze > 0) tag('SLOW-MO ${r.freeze.ceil()}s', _iceBlue);
  }
}

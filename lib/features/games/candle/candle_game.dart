import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flutter/painting.dart' show FontWeight, TextPainter, TextSpan, TextStyle, TextDirection;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../core/sfx.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'candle_rules.dart';

// Trading desk palette: dark chart world, solid fills, ink outlines.
const _ink = Color(0xFF0A0F1A);
const _desk = Color(0xFF111A2B);
const _grid = Color(0xFF1B2740);
const _shadow = Color(0xFF05080F);
const _red = Color(0xFFE5484D);
const _redHi = Color(0xFFFF7A7E);
const _green = Color(0xFF22C777);
const _greenHi = Color(0xFF7CF0B2);
const _yellow = Color(0xFFFFD23F);
const _cream = Color(0xFFFFF3DC);
const _amber = Color(0xFFFFC857);
const _steel = Color(0xFF5B7BA6);

const _hud = 90.0;
const _reserved = 190.0;
const _bannerLen = 0.8;
const _resultLen = 1.1;
const _summaryLen = 2.2;
const _slowLimit = 2.0;
const _maxParticles = 80;
const _maxPops = 6;
const _points = 48;
const _tape = [
  'IDX 101.2 +0.4%',
  'GOLD 62.8 -0.1%',
  'OIL 78.3 +0.9%',
  'FX 83.1 -0.2%',
  'BOND 7.1 +0.0%',
  'TECH 214 +1.3%',
];

enum CandlePhase { banner, waiting, go, result, summary }

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.size, this.life, this.color);
  double x, y, vx, vy, rot = 0, age = 0;
  final double size, life;
  final Color color;
}

class _Pop {
  _Pop(this.text, this.x, this.y, this.color);
  final String text;
  final double x, y;
  final Color color;
  double age = 0;
}

/// Green Candle: tap the moment the candle turns green. Five rounds.
class CandleGame extends ArcadeGame with TapCallbacks, KeyboardEvents {
  CandleGame(super.config) : _rng = Random(config.seed);

  final Random _rng;

  @override
  List<PowerupType> get boosts => const [];

  @override
  void applyPowerup(PowerupType type) {}

  // Own clock, summed from update(dt); reaction times are differences of it.
  double _clock = 0;
  CandlePhase phase = CandlePhase.banner;
  int _round = 1;
  final _results = <int?>[];
  double _phaseEnd = 0, _goAt = 0, _decoyAt = -1, _decoyUntil = -1, _decoyStart = 0;
  bool _decoyWick = false, _tickPending = true;

  // Visual state.
  String _label = '';
  Color _labelColor = _cream;
  double _labelAge = 9, _popAge = 9, _flashAge = 9, _badAge = 9, _shake = 0, _tapeX = 0, _lineT = 0;
  bool _lastGood = false;
  final _line = List<double>.filled(_points, 0);
  final _particles = <_Spark>[];
  final _pops = <_Pop>[];
  final _tpCache = <String, TextPainter>{};
  final _fill = Paint();
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final _linePath = Path();
  final _star = _makeStar();

  static Path _makeStar() {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 1.0 : 0.45;
      final a = -pi / 2 + i * pi / 5;
      final x = cos(a) * r, y = sin(a) * r;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }

  @override
  Future<void> onLoad() async {
    _startRound(play: false);
  }

  // ------------------------------------------------------------------ rules in motion

  void _startRound({bool play = true}) {
    phase = CandlePhase.banner;
    _phaseEnd = _clock + _bannerLen;
    _label = 'Round $_round of $candleRounds';
    _labelColor = _cream;
    _labelAge = 0;
    _lastGood = false;
    _decoyAt = _decoyUntil = -1;
    _tickPending = !play;
    if (play) Sound.play(Sfx.tick);
  }

  void _beginWait() {
    final wait = nextWait(_rng);
    phase = CandlePhase.waiting;
    _goAt = _clock + wait;
    final d = planDecoy(_rng, _round, wait);
    _decoyAt = d == null ? -1 : _clock + d;
    _decoyWick = _rng.nextBool();
    _label = 'Wait for green...';
    _labelColor = _steel;
    _labelAge = 0;
  }

  /// Player input (tap or space). Reaction is measured on the game's own clock.
  void tap() {
    if (isOver) return;
    if (phase == CandlePhase.waiting) {
      _finish(null, 'Too early!');
    } else if (phase == CandlePhase.go) {
      _finish(((_clock - _goAt) * 1000).round(), '');
    }
  }

  void _finish(int? ms, String text) {
    _results.add(ms);
    final pts = roundScore(ms);
    score.value += pts;
    coins.value += coinsFor(ms);
    phase = CandlePhase.result;
    _phaseEnd = _clock + _resultLen;
    _labelAge = 0;
    _lastGood = ms != null;
    final cx = size.x / 2;
    final cy = _chartMid();
    if (ms == null) {
      _label = text;
      _labelColor = _redHi;
      _badAge = 0;
      _shake = 1;
      Sound.play(Sfx.wrong);
      Haptics.heavy();
    } else {
      _label = '$ms ms';
      _labelColor = ms < 300 ? _greenHi : _amber;
      _popAge = 0;
      _addPop('+$pts', cx + 80, cy - 70, _labelColor);
      Sound.play(Sfx.coin);
      if (ms < 220) Sound.play(Sfx.perfect);
      Haptics.medium();
      if (ms < 200) _burst(cx, cy, 14);
    }
  }

  void _timeout() {
    _finish(null, 'Too slow!');
    _shake = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (size.x == 0) return;
    dt = dt.clamp(0.0, 1 / 30);
    _clock += dt;
    if (_tickPending) {
      _tickPending = false;
      Sound.play(Sfx.tick);
    }
    _labelAge += dt;
    _popAge += dt;
    _flashAge += dt;
    _badAge += dt;
    _shake = max(0, _shake - dt * 3.5);
    _tapeX = (_tapeX + dt * 60) % 100000;
    _stepLine(dt);
    _stepFx(dt);

    switch (phase) {
      case CandlePhase.banner:
        if (_clock >= _phaseEnd) _beginWait();
      case CandlePhase.waiting:
        if (_decoyAt >= 0 && _clock >= _decoyAt) {
          _decoyStart = _clock;
          _decoyUntil = _clock + candleDecoyLen;
          _decoyAt = -1;
        }
        if (_clock >= _goAt) {
          phase = CandlePhase.go;
          _goAt = _clock;
          _decoyUntil = -1;
          _popAge = 0;
          _flashAge = 0;
          _label = 'TAP!';
          _labelColor = _greenHi;
          _labelAge = 0;
        }
      case CandlePhase.go:
        if (_clock - _goAt > _slowLimit) _timeout();
      case CandlePhase.result:
        if (_clock >= _phaseEnd) {
          if (runEnds(_results.length)) {
            phase = CandlePhase.summary;
            _phaseEnd = _clock + _summaryLen;
            Sound.play(Sfx.win);
          } else {
            _round++;
            _startRound();
          }
        }
      case CandlePhase.summary:
        if (_clock >= _phaseEnd) gameOver();
    }
  }

  void _stepLine(double dt) {
    _lineT += dt;
    if (_lineT < 0.06) return;
    _lineT = 0;
    final amp = phase == CandlePhase.waiting ? 0.5 : 0.25;
    final trend = phase == CandlePhase.go || _lastGood ? 0.1 : 0;
    for (var i = 0; i < _points - 1; i++) {
      _line[i] = _line[i + 1];
    }
    final last = _line[_points - 2];
    _line[_points - 1] = (last * 0.9 + (_rng.nextDouble() - 0.5) * amp + trend).clamp(-1.0, 1.0);
  }

  void _stepFx(double dt) {
    for (final s in _particles) {
      s.age += dt;
      s.vy += 700 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.rot += dt * 6;
    }
    _particles.removeWhere((s) => s.age >= s.life);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age >= 0.9);
  }

  void _burst(double x, double y, int n) {
    for (var i = 0; i < n; i++) {
      if (_particles.length >= _maxParticles) _particles.removeAt(0);
      final a = _rng.nextDouble() * 2 * pi;
      final v = 160 + _rng.nextDouble() * 280;
      _particles.add(
        _Spark(x, y, cos(a) * v, sin(a) * v - 220, 7 + _rng.nextDouble() * 8, 0.8, i.isEven ? _amber : _cream),
      );
    }
  }

  void _addPop(String t, double x, double y, Color c) {
    if (_pops.length >= _maxPops) _pops.removeAt(0);
    _pops.add(_Pop(t, x, y, c));
  }

  @override
  void revive() {
    if (_results.isNotEmpty) {
      score.value -= roundScore(_results.removeLast());
      _round = _results.length + 1;
    }
    _particles.clear();
    _pops.clear();
    _startRound();
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

  // ------------------------------------------------------------------ layout

  double get _top => _hud;
  double get _bot => max(size.y - _reserved, 450);
  double get _chartTop => _top + 44;
  double get _chartBot => _bot - 86;
  double _chartMid() => (_chartTop + _chartBot) / 2;

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

  Paint _f(Color c) => _fill..color = c;
  Paint _s(double w, Color c) => _stroke
    ..strokeWidth = w
    ..color = c;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x == 0) return;
    final w = size.x, h = size.y;
    canvas.save();
    if (_shake > 0) {
      canvas.translate((_rng.nextDouble() - 0.5) * 18 * _shake, (_rng.nextDouble() - 0.5) * 18 * _shake);
    }
    canvas.drawRect(Rect.fromLTWH(-30, -30, w + 60, h + 60), _f(_desk));
    _drawChart(canvas, w);
    _drawCandle(canvas, w);
    _drawTape(canvas, w);
    _drawPips(canvas, w);
    _drawLabel(canvas, w);
    for (final s in _particles) {
      final k = 1 - s.age / s.life;
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(s.rot);
      canvas.scale(s.size * (0.4 + k));
      canvas.drawPath(_star, _f(_ink));
      canvas.scale(0.72);
      canvas.drawPath(_star, _f(s.color));
      canvas.restore();
    }
    for (final p in _pops) {
      final k = p.age / 0.9;
      _text(canvas, p.text, Offset(p.x, p.y - 50 * k), 26, p.color.withValues(alpha: 1 - k * k));
    }
    if (phase == CandlePhase.summary) _drawSummary(canvas, w);
    canvas.restore();
    if (_flashAge < 0.35) {
      final a = 0.26 * (1 - _flashAge / 0.35);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _f(_green.withValues(alpha: a)));
    }
  }

  void _drawChart(Canvas canvas, double w) {
    final left = 16.0, right = w - 16, top = _chartTop, bot = _chartBot;
    final panel = RRect.fromLTRBR(left, top, right, bot, const Radius.circular(14));
    canvas.drawRRect(panel.shift(const Offset(5, 6)), _f(_shadow));
    canvas.drawRRect(panel, _f(_ink));
    for (var i = 1; i < 5; i++) {
      final y = top + (bot - top) * i / 5;
      canvas.drawLine(Offset(left + 4, y), Offset(right - 4, y), _s(1.5, _grid));
    }
    for (var i = 1; i < 6; i++) {
      final x = left + (right - left) * i / 6;
      canvas.drawLine(Offset(x, top + 4), Offset(x, bot - 4), _s(1.5, _grid));
    }
    final mid = (top + bot) / 2, amp = (bot - top) * 0.36;
    _linePath.reset();
    for (var i = 0; i < _points; i++) {
      final x = left + 10 + (right - left - 20) * i / (_points - 1);
      final y = mid - _line[i] * amp;
      i == 0 ? _linePath.moveTo(x, y) : _linePath.lineTo(x, y);
    }
    final c = phase == CandlePhase.go || _lastGood ? _green : (_badAge < 0.5 ? _red : _steel);
    canvas.drawPath(_linePath, _s(4, c));
    canvas.drawRRect(panel, _s(5, _ink));
  }

  void _drawCandle(Canvas canvas, double w) {
    final cx = w / 2, cy = _chartMid();
    final ch = _chartBot - _chartTop;
    final bodyH = ch * 0.4, bodyW = min(w * 0.3, 118.0), wickW = 12.0;
    final wickTop = cy - ch * 0.42, wickBot = cy + ch * 0.42;
    final go = phase == CandlePhase.go || _lastGood;
    final decoy = _decoyUntil > _clock;
    final flick = decoy && ((_clock - _decoyStart) * 1000 ~/ 40).isEven;
    var body = go ? _green : _red;
    var hi = go ? _greenHi : _redHi;
    if (decoy && !_decoyWick && flick) {
      body = _yellow;
      hi = _cream;
    }
    var wick = decoy && _decoyWick ? _greenHi : body;
    if (_badAge < 0.12) {
      body = Color.lerp(body, _cream, 1 - _badAge / 0.12)!;
      wick = body;
    }
    // Pop on go / good tap: quick overshoot that settles.
    final s = _popAge < 0.4 ? 1 + 0.28 * pow(1 - _popAge / 0.4, 2) * cos(_popAge * 22) : 1.0;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(s);
    canvas.translate(-cx, -cy);
    final bodyR = RRect.fromLTRBR(
      cx - bodyW / 2,
      cy - bodyH / 2,
      cx + bodyW / 2,
      cy + bodyH / 2,
      const Radius.circular(12),
    );
    final wickR = RRect.fromLTRBR(cx - wickW / 2, wickTop, cx + wickW / 2, wickBot, const Radius.circular(5));
    const off = Offset(8, 9);
    canvas.drawRRect(wickR.shift(off), _f(_shadow));
    canvas.drawRRect(bodyR.shift(off), _f(_shadow));
    canvas.drawRRect(wickR, _f(wick));
    canvas.drawRRect(wickR, _s(4, _ink));
    canvas.drawRRect(bodyR, _f(body));
    final shine = RRect.fromLTRBR(
      cx - bodyW / 2 + 9,
      cy - bodyH / 2 + 10,
      cx - bodyW / 2 + 22,
      cy + bodyH / 2 - 10,
      const Radius.circular(6),
    );
    canvas.drawRRect(shine, _f(hi));
    canvas.drawRRect(bodyR, _s(6, _ink));
    canvas.restore();
  }

  void _drawTape(Canvas canvas, double w) {
    final y = _bot - 26;
    canvas.drawRect(Rect.fromLTWH(0, y, w, 26), _f(_ink));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, y, w, 26));
    var x = -(_tapeX % 1500);
    while (x < w) {
      for (final t in _tape) {
        final tp = _tp(t, 13, _steel, stroke: false);
        tp.paint(canvas, Offset(x, y + 6));
        x += tp.width + 36;
      }
    }
    canvas.restore();
  }

  void _drawPips(Canvas canvas, double w) {
    final y = _top + 20;
    for (var i = 0; i < candleRounds; i++) {
      final x = w / 2 + (i - 2) * 30;
      final cur = i == _results.length && phase != CandlePhase.summary;
      final r = cur ? 11.0 : 9.0;
      Color? fill;
      if (i < _results.length) fill = _results[i] == null ? _red : _green;
      canvas.drawCircle(Offset(x, y), r + 2, _f(_ink));
      canvas.drawCircle(Offset(x, y), r, _f(fill ?? (cur ? _cream : _grid)));
    }
  }

  void _drawLabel(Canvas canvas, double w) {
    if (phase == CandlePhase.summary) return;
    final y = _bot - 62;
    final big = phase == CandlePhase.result || phase == CandlePhase.go;
    final t = (_labelAge / 0.25).clamp(0.0, 1.0);
    final k = 1 - pow(1 - t, 3).toDouble();
    final scale = phase == CandlePhase.result ? 2.2 - 1.2 * k : 1.0;
    canvas.save();
    canvas.translate(w / 2, y);
    canvas.scale(scale);
    final fs = big ? 52.0 : 26.0;
    _text(canvas, _label, Offset.zero, fs, _labelColor);
    canvas.restore();
  }

  void _drawSummary(Canvas canvas, double w) {
    final avg = averageMs(_results), best = bestMs(_results);
    final r = RRect.fromLTRBR(w / 2 - 150, _chartTop + 10, w / 2 + 150, _chartBot + 30, const Radius.circular(18));
    canvas.drawRRect(r.shift(const Offset(6, 7)), _f(_shadow));
    canvas.drawRRect(r, _f(_cream));
    canvas.drawRRect(r, _s(5, _ink));
    final cx = w / 2, y0 = r.top;
    _text(canvas, 'Results', Offset(cx, y0 + 36), 30, _green);
    final lines = [
      ('Average', avg == null ? '-' : '${avg.round()} ms'),
      ('Best round', best == null ? '-' : '$best ms'),
      ('Score', '${score.value}'),
    ];
    for (var i = 0; i < lines.length; i++) {
      final y = y0 + 84 + i * 40;
      _tp(lines[i].$1, 18, _ink).paint(canvas, Offset(cx - 124, y - 9));
      final v = _tp(lines[i].$2, 24, _ink);
      v.paint(canvas, Offset(cx + 124 - v.width, y - 12));
    }
  }
}

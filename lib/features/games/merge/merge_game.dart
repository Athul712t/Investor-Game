import 'dart:math';
import 'dart:ui' as ui show Gradient;

import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../core/theme.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'merge_board.dart';

const _emoji = ['🪙', '🪙', '💵', '💵', '💴', '💰', '💰', '🏦', '🏦', '💎', '💎', '👑'];
const _slideT = 0.12, _popT = 0.2;

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
    _last = r;
    _t = 0;
    var needBoost = false;
    final mult = _doubleMoves > 0 ? 2 : 1;
    if (_doubleMoves > 0) _doubleMoves--;
    r.merges.forEach((cell, v) {
      score.value += v * mult;
      if (v >= 16) coins.value++;
      if (v >= 64) {
        _burst(cell, v);
        HapticFeedback.mediumImpact();
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
  Rect get _boardRect {
    final availH = size.y - 90 - 64;
    final s = min(min(size.x - 32, availH), 520.0);
    return Rect.fromLTWH((size.x - s) / 2, 90 + (availH - s) / 2 + 8, s, s);
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
    final col = _tierColor(MergeBoard.tierOf(value));
    for (var i = 0; i < 18; i++) {
      final a = _rng.nextDouble() * 2 * pi, v = 80 + _rng.nextDouble() * 200;
      _particles.add(
        _Particle(c, Offset(cos(a), sin(a)) * v, i.isEven ? col : AppColors.amber, 3 + _rng.nextDouble() * 4),
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
  }

  // ---- drawing ----
  static const _ramp = [AppColors.sky, AppColors.mint, AppColors.amber, AppColors.coral, AppColors.violet];

  static Color _tierColor(int tier) {
    final pos = ((tier - 1).clamp(0, 11)) / 11 * (_ramp.length - 1);
    final i = pos.floor().clamp(0, _ramp.length - 2);
    final base = Color.lerp(_ramp[i], _ramp[i + 1], pos - i)!;
    return Color.lerp(AppColors.surfaceHi, base, 0.6 + 0.4 * min(1.0, (tier - 1) / 3))!;
  }

  final _tp = <String, TextPainter>{};

  /// Emoji are not cached: on web the colour-emoji fallback font loads late and a painter laid out
  /// before that would stay a tofu box forever.
  TextPainter _text(String s, double size, Color color, {bool display = true}) {
    TextPainter build() => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontFamily: display ? 'Fredoka' : null,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return display ? _tp['$s|${size.round()}|${color.toARGB32()}'] ??= build() : build();
  }

  void _paintText(Canvas canvas, TextPainter tp, Offset center) =>
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

  void _drawTile(Canvas canvas, Rect rect, int value, double scale) {
    final tier = MergeBoard.tierOf(value);
    final base = _tierColor(tier);
    final lift = rect.height * 0.06;
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(scale);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.2));
    canvas.drawRRect(rr.shift(Offset(0, lift)), Paint()..color = Color.lerp(base, AppColors.ink, 0.45)!);
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomLeft, [Color.lerp(base, AppColors.text, 0.22)!, base]),
    );
    if (tier >= 6) {
      canvas.drawRRect(
        rr.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.text.withValues(alpha: 0.35),
      );
    }
    final fg = base.computeLuminance() > 0.35 ? AppColors.ink : AppColors.text;
    final label = '₹$value';
    final fs = rect.width * (label.length <= 3 ? 0.3 : (label.length == 4 ? 0.26 : 0.21));
    final emoji = _text(_emoji[(tier - 1).clamp(0, 11)], rect.width * 0.34, fg, display: false);
    _paintText(canvas, emoji, rect.center.translate(0, -rect.height * 0.16));
    _paintText(canvas, _text(label, fs, fg), rect.center.translate(0, rect.height * 0.22));
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0) return;
    final br = _boardRect;
    final panel = RRect.fromRectAndRadius(br, const Radius.circular(AppSpace.radius));
    canvas.drawRRect(panel.shift(const Offset(0, 6)), Paint()..color = AppColors.ink.withValues(alpha: 0.6));
    canvas.drawRRect(panel, Paint()..color = AppColors.surface);
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.line,
    );
    for (var i = 0; i < 16; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_cellRect(i), Radius.circular(_cell * 0.2)),
        Paint()..color = AppColors.ink.withValues(alpha: 0.45),
      );
    }

    if (_t < _slideT) {
      final e = Curves.easeOut.transform(_t / _slideT);
      for (final s in _last.slides) {
        _drawTile(canvas, Rect.lerp(_cellRect(s.from), _cellRect(s.to), e)!, s.value, 1);
      }
    } else {
      final pt = (_t - _slideT) / _popT;
      for (var i = 0; i < 16; i++) {
        final v = _board.cells[i];
        if (v == 0) continue;
        var scale = 1.0;
        if (pt < 1) {
          if (_last.merges.containsKey(i)) {
            scale = 1 + 0.2 * sin(pt * pi);
          } else if (i == _last.spawnCell) {
            scale = Curves.easeOutBack.transform(pt).clamp(0.0, 1.3);
          }
        }
        _drawTile(canvas, _cellRect(i), v, scale);
      }
    }

    for (final p in _particles) {
      final paint = Paint()..color = p.color.withValues(alpha: (p.life / 0.4).clamp(0.0, 1.0));
      canvas.drawCircle(p.pos, p.size * (p.life / 0.6).clamp(0.2, 1.0), paint);
    }
    _drawHint(canvas, br);
    _drawBanner(canvas, br);
  }

  void _drawHint(Canvas canvas, Rect br) {
    final next = max(_board.highest, 1) * 2;
    final tier = MergeBoard.tierOf(next);
    final label = '${_emoji[(tier - 1).clamp(0, 11)]}  Next goal ₹$next';
    _paintText(canvas, _text(label, 16, AppColors.textDim, display: false), Offset(size.x / 2, br.bottom + 30));
    if (_doubleMoves > 0) {
      final s = '2x score: $_doubleMoves moves left';
      _paintText(canvas, _text(s, 13, AppColors.amber), Offset(size.x / 2, br.bottom + 52));
    }
  }

  void _drawBanner(Canvas canvas, Rect br) {
    if (_bannerT > 1.4) return;
    final a = (_bannerT < 0.15 ? _bannerT / 0.15 : 1 - ((_bannerT - 0.9) / 0.5).clamp(0.0, 1.0)).toDouble();
    final tp = _text(_banner, 24, AppColors.text);
    final c = br.center.translate(0, -_bannerT * 20);
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: tp.width + 40, height: tp.height + 20),
      const Radius.circular(24),
    );
    canvas.drawRRect(pill, Paint()..color = AppColors.surfaceHi.withValues(alpha: 0.95 * a));
    canvas.drawRRect(
      pill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.amber.withValues(alpha: a),
    );
    canvas.saveLayer(null, Paint()..color = AppColors.text.withValues(alpha: a));
    _paintText(canvas, tp, c);
    canvas.restore();
  }
}

import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, FontWeight;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../core/theme.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'runner_backdrop.dart';
import 'runner_sim.dart';

class _Particle {
  _Particle(this.p, this.v, this.life, this.size, this.color, {this.gravity = 0, this.star = false}) : max = life;
  Offset p, v;
  double life;
  final double max, size, gravity;
  final Color color;
  final bool star;
}

/// Bull Run: a 3-lane pseudo-3D endless runner. Logic lives in [RunnerSim]; this class draws and handles input.
class RunnerGame extends ArcadeGame with TapCallbacks, DragCallbacks, KeyboardEvents {
  RunnerGame(super.config) : sim = RunnerSim(seed: config.seed);

  @override
  List<PowerupType> get boosts => const [
    PowerupType.shield,
    PowerupType.magnet,
    PowerupType.doubleScore,
    PowerupType.slowMo,
  ];

  final RunnerSim sim;
  final cam = Cam();
  final _backdrop = Backdrop();
  final _fx = Random();
  final _particles = <_Particle>[];
  final _glyphs = <String, TextPainter>{};
  double _t = 0, _shake = 0, _flash = 0, _crashT = -1, _dustT = 0;
  double _squash = 0, _squashV = 0; // spring for squash and stretch
  Offset _drag = Offset.zero;
  bool _swiped = false;

  static const _crashDelay = 0.8;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    cam.resize(size.x, size.y);
  }

  // ---------------------------------------------------------------- input

  void _left() => _lane(-1);
  void _right() => _lane(1);
  void _lane(int d) {
    if (paused || sim.crashed) return;
    final before = sim.lane;
    sim.moveLane(d);
    if (sim.lane != before) _squashV -= 2.5;
  }

  void _jump() {
    if (paused || !sim.jump()) return;
    _squashV += 7;
    HapticFeedback.selectionClick();
  }

  @override
  void onTapUp(TapUpEvent event) {
    final x = event.canvasPosition.x;
    if (x < size.x / 3) {
      _left();
    } else if (x > size.x * 2 / 3) {
      _right();
    } else {
      _jump();
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _drag = Offset.zero;
    _swiped = false;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_swiped) return;
    _drag += Offset(event.canvasDelta.x, event.canvasDelta.y);
    if (_drag.distance < 24) return;
    _swiped = true;
    _swipe(_drag);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    // A short flick may end before crossing the distance threshold.
    if (!_swiped && event.velocity.length > 300) _swipe(Offset(event.velocity.x, event.velocity.y));
  }

  void _swipe(Offset d) {
    if (d.dx.abs() > d.dy.abs()) {
      d.dx < 0 ? _left() : _right();
    } else if (d.dy < 0) {
      _jump();
    } else {
      sim.drop();
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      _left();
    } else if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      _right();
    } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyW) {
      _jump();
    } else if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      sim.drop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------- powerups

  @override
  void applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.shield || PowerupType.extraLife:
        sim.shield = true;
      case PowerupType.magnet:
        sim.magnet = 8;
      case PowerupType.doubleScore:
        sim.doubleScore = 8;
      case PowerupType.slowMo:
        sim.slowMo = 5;
    }
  }

  @override
  void revive() {
    sim.revive();
    _crashT = -1;
    _flash = 0;
    _shake = 0;
  }

  // ---------------------------------------------------------------- update

  @override
  void update(double dt) {
    super.update(dt);
    dt = min(dt, 1 / 30);
    // On web the emoji font arrives after the first layout; re-lay out glyphs now and then.
    final every = _t < 6 ? 0.5 : 2.0;
    if ((_t / every).floor() != ((_t + dt) / every).floor()) _glyphs.clear();
    _t += dt;
    for (final e in sim.step(dt)) {
      _onEvent(e);
    }
    score.value = sim.score.floor();
    coins.value = sim.coins;
    cam.camX = sim.x * 0.35;

    if (_crashT >= 0) {
      _crashT += dt;
      if (_crashT >= _crashDelay && !isOver) gameOver();
    }

    // Squash/stretch spring.
    _squashV += (-260 * _squash - 16 * _squashV) * dt;
    _squash += _squashV * dt;
    _shake = max(0, _shake - dt * 30);
    _flash = max(0, _flash - dt * 2.5);

    _dustT -= dt;
    if (!sim.crashed && sim.jumpT < 0 && _dustT <= 0) {
      _dustT = 0.04;
      final feet = cam.p(sim.x, 0, -0.3);
      _particles.add(
        _Particle(
          feet + Offset((_fx.nextDouble() - 0.5) * cam.ppu * 1.2, 0),
          Offset((_fx.nextDouble() - 0.5) * 60, 40 + sim.speed * 4),
          0.45,
          2 + _fx.nextDouble() * 2.5,
          (sim.doubleScore > 0 ? AppColors.mint : AppColors.textDim).withValues(alpha: 0.6),
        ),
      );
    }
    for (final p in _particles) {
      p.life -= dt;
      p.v = Offset(p.v.dx * (1 - dt * 1.5), p.v.dy + p.gravity * dt);
      p.p += p.v * dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  void _onEvent(SimEvent e) {
    final at = cam.p(e.x, e.y, max(e.z, 0));
    switch (e.type) {
      case SimEventType.coin:
        HapticFeedback.selectionClick();
        _burst(at, 10, [AppColors.amber, AppColors.text], 160, star: true);
      case SimEventType.boost:
        HapticFeedback.mediumImpact();
        _burst(at, 26, [AppColors.violet, AppColors.amber, AppColors.text], 260, star: true);
        _flash = 0.35;
        requestBoost();
      case SimEventType.shieldBreak:
        HapticFeedback.heavyImpact();
        _shake = 8;
        _burst(at, 30, [AppColors.sky, AppColors.text, AppColors.coral], 320);
      case SimEventType.hit:
        HapticFeedback.heavyImpact();
        _shake = 18;
        _flash = 1;
        _crashT = 0;
        _burst(cam.p(sim.x, sim.jumpH + 1, 0), 46, [AppColors.coral, AppColors.amber, AppColors.text], 420);
      case SimEventType.land:
        _squashV -= 6;
        _burst(cam.p(sim.x, 0, 0), 8, [AppColors.textDim], 120, gravity: 300);
    }
  }

  void _burst(Offset at, int n, List<Color> colors, double speed, {bool star = false, double gravity = 500}) {
    for (var i = 0; i < n; i++) {
      final a = _fx.nextDouble() * pi * 2;
      final v = speed * (0.35 + _fx.nextDouble() * 0.65);
      _particles.add(
        _Particle(
          at,
          Offset(cos(a) * v, sin(a) * v - speed * 0.3),
          0.45 + _fx.nextDouble() * 0.45,
          star ? 3 + _fx.nextDouble() * 3 : 2 + _fx.nextDouble() * 4,
          colors[i % colors.length],
          gravity: gravity,
          star: star,
        ),
      );
    }
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas canvas) {
    final c = canvas;
    c.save();
    if (_shake > 0) c.translate((_fx.nextDouble() - 0.5) * _shake, (_fx.nextDouble() - 0.5) * _shake);
    _backdrop.render(c, cam, _t, sim.distance);
    _laneGlow(c);
    _backdrop.lamps(c, cam, sim.distance);

    final ents = [...sim.entities]..sort((a, b) => b.at.compareTo(a.at));
    var playerDrawn = false;
    for (final e in ents) {
      final z = sim.zOf(e);
      if (!playerDrawn && z < 0.2) {
        _player(c);
        playerDrawn = true;
      }
      _entity(c, e, z);
    }
    if (!playerDrawn) _player(c);

    _drawParticles(c);
    c.restore();
    _speedLines(c);
    _overlays(c);
    _hud(c);
    super.render(c);
  }

  void _laneGlow(Canvas c) {
    final x = sim.x;
    final near = cam.p(x, 0, cam.zBottom), far = cam.p(x, 0, 45);
    final path = Path()
      ..moveTo(cam.p(x - 1.4, 0, 45).dx, far.dy)
      ..lineTo(cam.p(x + 1.4, 0, 45).dx, far.dy)
      ..lineTo(cam.p(x + 1.4, 0, cam.zBottom).dx, near.dy)
      ..lineTo(cam.p(x - 1.4, 0, cam.zBottom).dx, near.dy)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(Offset(0, far.dy), Offset(0, near.dy), [
          AppColors.mint.withValues(alpha: 0),
          AppColors.mint.withValues(alpha: 0.10),
        ]),
    );
  }

  TextPainter _glyph(String s, {Color color = AppColors.text, double size = 64}) => _glyphs.putIfAbsent(
    '$s$size${color.toARGB32()}',
    () => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w900, fontFamily: 'Fredoka'),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  /// Draw [s] centred at [at] with a height of about [px].
  void _emoji(Canvas c, String s, Offset at, double px, {double angle = 0, double sx = 1, double sy = 1}) {
    final tp = _glyph(s);
    final k = px / tp.height;
    c.save();
    c.translate(at.dx, at.dy);
    if (angle != 0) c.rotate(angle);
    c.scale(k * sx, k * sy);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  // Fade in at the horizon; fade out once past the player so near obstacles don't hide the road.
  double _fog(double z) => ((RunnerSim.spawnAhead - z) / 28).clamp(0.0, 1.0) * (1 + z / 4).clamp(0.25, 1.0);

  void _entity(Canvas c, Entity e, double z) {
    final a = _fog(z);
    if (a <= 0) return;
    switch (e.kind) {
      case Kind.low:
        _block(c, e.x, z, 1.3, RunnerSim.lowHeight, 0.4, AppColors.coral, a, low: true);
      case Kind.tall:
        _block(c, e.x, z, 1.3, 3.3, 0.3, Color.lerp(AppColors.surfaceHi, AppColors.coral, 0.3)!, a, low: false);
      case Kind.coin:
        _coin(c, e, z, a);
      case Kind.boost:
        _boost(c, e, z, a);
    }
  }

  void _block(Canvas c, double x, double z, double hw, double h, double hd, Color base, double a, {required bool low}) {
    final s = cam.k(z) * cam.ppu;
    final z1 = z - hd, z2 = z + hd;
    final fr = cam.p(x + hw, 0, z1);
    final tl = cam.p(x - hw, h, z1), tr = cam.p(x + hw, h, z1);
    final bl = cam.p(x - hw, h, z2), br = cam.p(x + hw, h, z2);
    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);
    Paint fill(Color col) => Paint()..color = col.withValues(alpha: a);

    // Red pool of light under the block.
    c.drawOval(
      Rect.fromCenter(center: cam.p(x, 0, z), width: s * hw * 3.4, height: s * 1.3),
      Paint()
        ..color = AppColors.coral.withValues(alpha: 0.35 * a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(2, s * 0.5)),
    );
    final dx = x - cam.camX;
    if (dx.abs() > hw) {
      final sx = dx > 0 ? x - hw : x + hw;
      c.drawPath(
        poly([cam.p(sx, 0, z1), cam.p(sx, h, z1), cam.p(sx, h, z2), cam.p(sx, 0, z2)]),
        fill(Color.lerp(base, AppColors.ink, 0.5)!),
      );
    }
    c.drawPath(poly([tl, tr, br, bl]), fill(Color.lerp(base, AppColors.text, low ? 0.35 : 0.15)!));
    final front = Rect.fromPoints(tl, fr);
    c.drawRect(
      front,
      Paint()
        ..shader = Gradient.linear(front.topCenter, front.bottomCenter, [
          base.withValues(alpha: a),
          Color.lerp(base, AppColors.ink, 0.45)!.withValues(alpha: a),
        ]),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, s * 0.07)
      ..color = Color.lerp(AppColors.coral, AppColors.text, 0.3)!.withValues(alpha: a);
    c.drawRect(front, edge);

    if (low) {
      // A falling price line: this is a dip.
      final pts = const [
        Offset(0.08, 0.28),
        Offset(0.3, 0.42),
        Offset(0.45, 0.32),
        Offset(0.68, 0.72),
        Offset(0.92, 0.8),
      ];
      final line = Path()
        ..addPolygon([for (final p in pts) front.topLeft + Offset(p.dx * front.width, p.dy * front.height)], false);
      c.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.2, s * 0.12)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = AppColors.text.withValues(alpha: 0.9 * a),
      );
      final tip = front.topLeft + Offset(0.92 * front.width, 0.8 * front.height);
      c.drawPath(
        poly([tip + Offset(-s * 0.32, -s * 0.05), tip + Offset(s * 0.05, s * 0.06), tip + Offset(-s * 0.1, -s * 0.3)]),
        fill(AppColors.text),
      );
    } else {
      // Hazard stripes at the base, a bear on the face.
      final stripe = Rect.fromLTRB(front.left, front.bottom - front.height * 0.16, front.right, front.bottom);
      c.save();
      c.clipRect(stripe);
      final sp = Paint()..color = AppColors.coral.withValues(alpha: 0.85 * a);
      final step = stripe.height * 1.2;
      for (var sx = stripe.left - stripe.height; sx < stripe.right; sx += step * 2) {
        c.drawPath(
          poly([
            Offset(sx, stripe.bottom),
            Offset(sx + step, stripe.bottom),
            Offset(sx + step + stripe.height, stripe.top),
            Offset(sx + stripe.height, stripe.top),
          ]),
          sp,
        );
      }
      c.restore();
      c.drawRect(
        front.deflate(-s * 0.05),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.25
          ..color = AppColors.coral.withValues(alpha: 0.4 * a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(2, s * 0.3)),
      );
      if (a > 0.05) {
        c.saveLayer(null, Paint()..color = AppColors.text.withValues(alpha: a));
        _emoji(c, '🐻', Offset(front.center.dx, front.top + front.height * 0.42), s * 1.7);
        c.restore();
      }
    }
  }

  void _coin(Canvas c, Entity e, double z, double a) {
    final bob = sin(_t * 4 + e.at) * 0.12;
    final at = cam.p(e.x, e.y + bob, z);
    final r = 0.48 * cam.k(z) * cam.ppu;
    final spin = max(0.18, cos(_t * 4.5 + e.at * 0.6).abs());
    c.drawCircle(
      at,
      r * 1.6,
      Paint()
        ..color = AppColors.amber.withValues(alpha: 0.35 * a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(2, r * 0.8)),
    );
    final rect = Rect.fromCenter(center: at, width: r * 2 * spin, height: r * 2);
    c.drawOval(rect, Paint()..color = Color.lerp(AppColors.amber, AppColors.coral, 0.35)!.withValues(alpha: a));
    c.drawOval(rect.deflate(r * 0.14), Paint()..color = AppColors.amber.withValues(alpha: a));
    c.drawOval(
      Rect.fromCenter(center: at, width: r * 0.9 * spin, height: r * 0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.12)
        ..color = Color.lerp(AppColors.amber, AppColors.ink, 0.25)!.withValues(alpha: a),
    );
    c.drawOval(
      Rect.fromCenter(center: at + Offset(-r * 0.3 * spin, -r * 0.35), width: r * 0.5 * spin, height: r * 0.3),
      Paint()..color = AppColors.text.withValues(alpha: 0.7 * a),
    );
  }

  void _boost(Canvas c, Entity e, double z, double a) {
    final pulse = 1 + sin(_t * 6) * 0.08;
    final at = cam.p(e.x, e.y + sin(_t * 3) * 0.2, z);
    final r = 0.8 * cam.k(z) * cam.ppu * pulse;
    final rays = Paint()
      ..strokeWidth = max(1, r * 0.12)
      ..strokeCap = StrokeCap.round
      ..color = AppColors.amber.withValues(alpha: 0.55 * a);
    for (var i = 0; i < 10; i++) {
      final ang = _t * 1.5 + i * pi / 5;
      final d = Offset(cos(ang), sin(ang));
      c.drawLine(at + d * r * 1.25, at + d * r * (1.6 + 0.2 * sin(_t * 8 + i)), rays);
    }
    c.drawCircle(
      at,
      r * 1.5,
      Paint()
        ..color = AppColors.violet.withValues(alpha: 0.6 * a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(3, r * 0.7)),
    );
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = Gradient.radial(at - Offset(r * 0.3, r * 0.3), r * 1.3, [
          Color.lerp(AppColors.violet, AppColors.text, 0.5)!.withValues(alpha: a),
          AppColors.violet.withValues(alpha: a),
        ]),
    );
    c.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, r * 0.1)
        ..color = AppColors.amber.withValues(alpha: a),
    );
    // Lightning bolt.
    final bolt = [
      const Offset(0.12, -0.62),
      const Offset(-0.36, 0.08),
      const Offset(-0.02, 0.08),
      const Offset(-0.14, 0.62),
      const Offset(0.36, -0.12),
      const Offset(0.02, -0.12),
    ];
    c.drawPath(
      Path()..addPolygon([for (final p in bolt) at + p * r], true),
      Paint()..color = AppColors.amber.withValues(alpha: a),
    );
  }

  void _player(Canvas c) {
    final h = sim.jumpH;
    final feet = cam.p(sim.x, h, 0);
    final ground = cam.p(sim.x, 0, 0);
    final s = cam.ppu;
    final blink = sim.invuln > 0 && !sim.crashed && (_t * 10).floor().isEven;

    // Shadow and neon ring on the road.
    final shrink = 1 - (h / 5).clamp(0.0, 0.6);
    c.drawOval(
      Rect.fromCenter(center: ground, width: s * 2.0 * shrink, height: s * 0.55 * shrink),
      Paint()..color = AppColors.ink.withValues(alpha: 0.6),
    );
    c.drawOval(
      Rect.fromCenter(center: ground, width: s * 2.3 * shrink, height: s * 0.62 * shrink),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.mint.withValues(alpha: 0.75 * shrink)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final size = s * 2.8;
    var tilt = ((sim.lane * RunnerSim.laneW - sim.x) * 0.12).clamp(-0.4, 0.4);
    final run = sim.jumpT < 0 && !sim.crashed ? sin(_t * 16).abs() : 0.0;
    var lift = run * s * 0.12;
    if (sim.crashed) {
      final ct = _crashT.clamp(0.0, _crashDelay);
      tilt = ct * 9;
      lift = sin(ct / _crashDelay * pi) * s * 1.6;
    }
    final sq = _squash.clamp(-0.4, 0.4);
    final sy = 1 + sq - run * 0.05, sx = 1 - sq * 0.6 + run * 0.03;

    if (blink) return;
    c.save();
    c.translate(feet.dx, feet.dy - lift);
    c.rotate(tilt);
    c.scale(sx, sy);
    // Mint aura so the bull pops off the dark road.
    c.drawCircle(
      Offset(0, -size * 0.42),
      size * 0.5,
      Paint()
        ..color = (sim.doubleScore > 0 ? AppColors.amber : AppColors.mint).withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.25),
    );
    _emoji(c, '🐂', Offset(0, -size * 0.45), size);
    c.restore();

    if (sim.shield) {
      final center = Offset(feet.dx, feet.dy - lift - size * 0.45);
      final r = size * 0.72 * (1 + sin(_t * 5) * 0.03);
      c.drawCircle(
        center,
        r,
        Paint()
          ..shader = Gradient.radial(
            center,
            r,
            [
              AppColors.sky.withValues(alpha: 0.0),
              AppColors.sky.withValues(alpha: 0.10),
              AppColors.sky.withValues(alpha: 0.35),
            ],
            [0, 0.7, 1],
          ),
      );
      c.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.sky.withValues(alpha: 0.85),
      );
      c.drawArc(
        Rect.fromCircle(center: center, radius: r * 0.82),
        -pi * 0.85 + sin(_t * 2) * 0.2,
        pi * 0.35,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = AppColors.text.withValues(alpha: 0.7),
      );
    }
  }

  void _drawParticles(Canvas c) {
    final p = Paint();
    for (final q in _particles) {
      final a = (q.life / q.max).clamp(0.0, 1.0);
      p.color = q.color.withValues(alpha: q.color.a * a);
      if (q.star) {
        final r = q.size * (0.6 + a);
        c.drawPath(
          Path()..addPolygon([
            q.p + Offset(0, -r * 1.6),
            q.p + Offset(r * 0.35, -r * 0.35),
            q.p + Offset(r * 1.6, 0),
            q.p + Offset(r * 0.35, r * 0.35),
            q.p + Offset(0, r * 1.6),
            q.p + Offset(-r * 0.35, r * 0.35),
            q.p + Offset(-r * 1.6, 0),
            q.p + Offset(-r * 0.35, -r * 0.35),
          ], true),
          p,
        );
      } else {
        c.drawCircle(q.p, q.size * (0.5 + a * 0.5), p);
      }
    }
  }

  void _speedLines(Canvas c) {
    final f = ((sim.speed - 15) / 10).clamp(0.0, 1.0) * (sim.crashed ? 0 : 1) * (sim.slowMo > 0 ? 0.3 : 1);
    if (f <= 0) return;
    final o = Offset(cam.cx, cam.hy);
    final reach = sqrt(cam.w * cam.w + cam.h * cam.h);
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var i = 0; i < 36; i++) {
      final ang = _hash01(i) * pi * 2;
      final ph = (_t * (1.4 + _hash01(i + 50)) + _hash01(i + 99)) % 1.0;
      final r0 = reach * (0.3 + ph * 0.5);
      final d = Offset(cos(ang), sin(ang));
      p.color = AppColors.text.withValues(alpha: 0.5 * f * ph);
      c.drawLine(o + d * r0, o + d * (r0 + 40 + 120 * ph), p);
    }
  }

  static double _hash01(int i) {
    final v = sin(i * 91.345 + 12.9) * 15731.743;
    return v - v.floorToDouble();
  }

  void _overlays(Canvas c) {
    final r = Offset.zero & Size(cam.w, cam.h);
    // Keep the host's HUD readable.
    c.drawRect(
      Rect.fromLTWH(0, 0, cam.w, 120),
      Paint()
        ..shader = Gradient.linear(Offset.zero, const Offset(0, 120), [
          AppColors.ink.withValues(alpha: 0.55),
          AppColors.ink.withValues(alpha: 0),
        ]),
    );
    final tint = sim.slowMo > 0 ? AppColors.sky : AppColors.ink;
    c.drawRect(
      r,
      Paint()
        ..shader = Gradient.radial(
          r.center,
          max(cam.w, cam.h) * 0.75,
          [tint.withValues(alpha: 0), tint.withValues(alpha: sim.slowMo > 0 ? 0.35 : 0.55)],
          [0.55, 1],
        ),
    );
    if (_flash > 0) {
      c.drawRect(r, Paint()..color = (sim.crashed ? AppColors.coral : AppColors.text).withValues(alpha: _flash * 0.35));
    }
  }

  /// Timer rings for active powerups, below the host's top bar.
  void _hud(Canvas c) {
    final items = <(String, double, Color)>[
      if (sim.shield) ('🛡️', 1, AppColors.sky),
      if (sim.magnet > 0) ('🧲', sim.magnet / 8, AppColors.coral),
      if (sim.doubleScore > 0) ('2×', sim.doubleScore / 8, AppColors.mint),
      if (sim.slowMo > 0) ('🐢', sim.slowMo / 5, AppColors.sky),
    ];
    for (final (i, (label, frac, color)) in items.indexed) {
      final at = Offset(32 + i * 52.0, 122);
      c.drawCircle(at, 21, Paint()..color = AppColors.surface.withValues(alpha: 0.85));
      c.drawCircle(
        at,
        19,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = AppColors.line,
      );
      c.drawArc(
        Rect.fromCircle(center: at, radius: 19),
        -pi / 2,
        pi * 2 * frac,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      if (label == '2×') {
        final tp = _glyph(label, color: AppColors.mint, size: 18);
        tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
      } else {
        _emoji(c, label, at, 20);
      }
    }
  }
}

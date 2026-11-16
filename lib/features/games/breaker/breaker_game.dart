import 'dart:math';

import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../../core/sfx.dart';
import '../../../core/theme.dart';
import '../../../domain/game/game_types.dart';
import '../_shared/arcade_game.dart';
import 'breaker_logic.dart';

// The vault room palette. Solid fills only, ink outlines everywhere.
const _ink = AppColors.ink;
const _wallBase = Color(0xFF2B3B52);
const _wallLight = Color(0xFF364A66);
const _wallDark = Color(0xFF223046);
const _floor = Color(0xFF1B2638);
const _steel = Color(0xFFA9B8CC);
const _vaultBody = Color(0xFF5E6E86);
const _paper = AppColors.paper;
const _rowColors = [AppColors.red, AppColors.orange, AppColors.green, AppColors.blue, AppColors.teal];

const _cols = 8;
const _brickH = 24.0;
const _faceH = 7.0; // visible bottom face of a brick
const _rowH = _brickH + _faceH + 3;
const _gridTop = 142.0;
const _ceiling = 84.0;
const _wall = 6.0;
const _ballR = 8.0;
const _quizZone = 190.0; // the host covers this much of the bottom while playing

enum _Kind { coin, wide, multi, slow, bolt }

class _Ball {
  _Ball(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy;
  final trail = <Offset>[];
}

class _Pickup {
  _Pickup(this.kind, this.x, this.y);
  final _Kind kind;
  double x, y, age = 0;
}

class _Shard {
  _Shard(this.x, this.y, this.vx, this.vy, this.vr, this.size, this.color);
  double x, y, vx, vy, vr, size, rot = 0, age = 0;
  final Color color;
}

class _Pop {
  _Pop(this.text, this.x, this.y, this.color, this.size);
  final String text;
  final double x, y, size;
  final Color color;
  double age = 0;
}

/// Brick Bank: drag the paddle, break the vault wall, catch the pickups.
class BreakerGame extends ArcadeGame with TapCallbacks, DragCallbacks, KeyboardEvents {
  BreakerGame(super.config);

  @override
  List<PowerupType> get boosts => const [
    PowerupType.extraLife,
    PowerupType.slowMo,
    PowerupType.magnet,
    PowerupType.doubleScore,
  ];

  late final Random _rng = Random(config.seed ?? DateTime.now().microsecondsSinceEpoch);
  final lives = Lives();
  final _bricks = <Brick>[];
  final _balls = <_Ball>[];
  final _pickups = <_Pickup>[];
  final _shards = <_Shard>[];
  final _pops = <_Pop>[];

  int level = 1, _combo = 0, _destroyed = 0;
  bool _launched = false;
  double _t = 0, _enterT = 0, _banner = 0, _shake = 0, _squash = 0, _flash = 0;
  double _px = 0, _pw = 90; // paddle centre and current width
  double _wideLeft = 0, _slowLeft = 0, _magnetLeft = 0, _doubleLeft = 0;
  int _keyDir = 0;

  // ---------------------------------------------------------------- geometry

  double get _paddleY => size.y - _quizZone - 36; // top of the paddle
  static const _paddleH = 16.0;
  double get _baseW => (size.x * 0.23).clamp(76.0, 118.0);
  double get _brickW => (size.x - 2 * (_wall + 6)) / _cols;
  int get _maxRows => max(3, ((_paddleY - 150 - _gridTop) / _rowH).floor());
  double get _speedScale => max(0.8, size.y / 844);

  Rect _rect(Brick b) =>
      Rect.fromLTWH(_wall + 6 + b.col * _brickW + 1.5, _gridTop + b.row * _rowH, _brickW - 3, _brickH + _faceH);

  @override
  Future<void> onLoad() async {
    _px = size.x / 2;
    _pw = _baseW;
    _newLevel();
    _resetBall();
  }

  void _newLevel() {
    _bricks
      ..clear()
      ..addAll(generateLevel(level, _cols, _maxRows, _rng));
    _enterT = 0;
    _banner = 1.5;
  }

  void _resetBall() {
    _launched = false;
    _balls
      ..clear()
      ..add(_Ball(_px, _paddleY - _ballR, 0, 0));
    _combo = 0;
  }

  // ------------------------------------------------------------------- input

  @override
  void onTapDown(TapDownEvent event) => launch();

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    launch();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => movePaddle(event.canvasDelta.x);

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final l = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final r = keysPressed.contains(LogicalKeyboardKey.arrowRight);
    _keyDir = (r ? 1 : 0) - (l ? 1 : 0);
    if (event is KeyDownEvent && (l || r || event.logicalKey == LogicalKeyboardKey.space)) {
      launch();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void movePaddle(double dx) {
    final half = _pw / 2 + _wall;
    _px = (_px + dx).clamp(half, size.x - half);
    if (!_launched && _balls.isNotEmpty) _balls.first.x = _px;
  }

  void launch() {
    if (_launched || isOver || size.x == 0 || _enterT < 0.5 || _balls.isEmpty) return;
    _launched = true;
    final v = fixVelocity((_rng.nextDouble() - 0.5) * 0.5, -1, _speed);
    _balls.first
      ..vx = v.$1
      ..vy = v.$2;
  }

  double get _speed => ballSpeed(level, difficulty: config.difficulty, scale: _speedScale) * (_slowLeft > 0 ? 0.65 : 1);

  // ------------------------------------------------------------------ update

  @override
  void update(double dt) {
    super.update(dt);
    if (size.x == 0) return;
    dt = dt.clamp(0, 0.05);
    _t += dt;
    _enterT += dt;
    _banner = max(0, _banner - dt);
    _shake *= exp(-dt * 9);
    _squash *= exp(-dt * 14);
    _flash = max(0, _flash - dt * 3);
    for (final s in _shards) {
      s.vy += 900 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.rot += s.vr * dt;
      s.age += dt;
    }
    _shards.removeWhere((s) => s.age > 0.8);
    for (final p in _pops) {
      p.age += dt;
    }
    _pops.removeWhere((p) => p.age > 0.9);
    if (isOver) return;

    _wideLeft = max(0, _wideLeft - dt);
    _slowLeft = max(0, _slowLeft - dt);
    _magnetLeft = max(0, _magnetLeft - dt);
    _doubleLeft = max(0, _doubleLeft - dt);
    _pw += ((_wideLeft > 0 ? _baseW * 1.6 : _baseW) - _pw) * min(1, dt * 12);
    if (_keyDir != 0) movePaddle(_keyDir * 560 * dt);
    movePaddle(0); // re-clamp while the paddle grows

    for (final b in List.of(_balls)) {
      _moveBall(b, dt);
    }
    _updatePickups(dt);

    if (_launched && _balls.isEmpty) _loseBall();
  }

  void _moveBall(_Ball b, double dt) {
    if (!_launched) return;
    final v = fixVelocity(b.vx, b.vy, _speed);
    b.vx = v.$1;
    b.vy = v.$2;
    final steps = max(1, (_speed * dt / 4).ceil());
    final h = dt / steps;
    for (var i = 0; i < steps; i++) {
      b.x += b.vx * h;
      b.y += b.vy * h;
      if (b.x < _wall + _ballR) {
        b.x = _wall + _ballR;
        b.vx = b.vx.abs();
        _wallHit();
      } else if (b.x > size.x - _wall - _ballR) {
        b.x = size.x - _wall - _ballR;
        b.vx = -b.vx.abs();
        _wallHit();
      }
      if (b.y < _ceiling + _ballR) {
        b.y = _ceiling + _ballR;
        b.vy = b.vy.abs();
        _wallHit();
      }
      if (b.vy > 0 && _hitPaddle(b)) continue;
      if (_hitBricks(b)) {
        final f = fixVelocity(b.vx, b.vy, _speed);
        b.vx = f.$1;
        b.vy = f.$2;
        if (_bricks.isEmpty) return _clearLevel();
      }
      if (b.y - _ballR > _paddleY + 70) {
        _balls.remove(b);
        return;
      }
    }
    b.trail.add(Offset(b.x, b.y));
    if (b.trail.length > 9) b.trail.removeAt(0);
  }

  void _wallHit() => Sound.play(Sfx.tick, volume: 0.5);

  bool _hitPaddle(_Ball b) {
    final top = _paddleY;
    if (b.y + _ballR < top || b.y - _ballR > top + _paddleH) return false;
    if ((b.x - _px).abs() > _pw / 2 + _ballR) return false;
    final v = paddleBounce((b.x - _px) / (_pw / 2), _speed);
    b.vx = v.$1;
    b.vy = v.$2;
    b.y = top - _ballR;
    _combo = 0;
    _squash = 1;
    Sound.play(Sfx.tick);
    return true;
  }

  bool _hitBricks(_Ball b) {
    for (final br in _bricks) {
      final rc = _rect(br);
      final dx = b.x - b.x.clamp(rc.left, rc.right), dy = b.y - b.y.clamp(rc.top, rc.bottom);
      if (dx * dx + dy * dy >= _ballR * _ballR) continue;
      final penX = min(b.x + _ballR - rc.left, rc.right - (b.x - _ballR));
      final penY = min(b.y + _ballR - rc.top, rc.bottom - (b.y - _ballR));
      if (penX < penY) {
        final s = b.x < rc.center.dx ? -1.0 : 1.0;
        b.vx = s * b.vx.abs();
        b.x += s * penX;
      } else {
        final s = b.y < rc.center.dy ? -1.0 : 1.0;
        b.vy = s * b.vy.abs();
        b.y += s * penY;
      }
      _combo++;
      if (br.hit()) {
        _bricks.remove(br);
        _breakBrick(br, rc);
      } else {
        _shake = max(_shake, 5);
        _shatter(rc, _brickColor(br), 3);
        Sound.play(Sfx.tick, volume: 0.8);
      }
      return true;
    }
    return false;
  }

  void _breakBrick(Brick br, Rect rc) {
    final mult = comboMultiplier(_combo) * (_doubleLeft > 0 ? 2 : 1);
    final pts = br.type.points * mult;
    score.value += pts;
    Sound.play(Sfx.merge);
    _shatter(rc, _brickColor(br), 7);
    if (br.type != BrickType.normal) _shake = max(_shake, 4);
    _pops.add(
      _Pop(
        mult > 1 ? '+$pts  x$mult' : '+$pts',
        rc.center.dx,
        rc.top,
        mult > 3 ? AppColors.yellow : _paper,
        mult > 1 ? 20 : 15,
      ),
    );
    _destroyed++;
    final at = rc.center;
    if (_destroyed % 20 == 0) {
      _pickups.add(_Pickup(_Kind.bolt, at.dx, at.dy));
    } else if (br.type == BrickType.gold) {
      for (var i = -1; i <= 1; i++) {
        _pickups.add(_Pickup(_Kind.coin, at.dx + i * 22, at.dy - i.abs() * 8));
      }
    } else if (br.type == BrickType.vault) {
      _pickups.add(_Pickup(const [_Kind.wide, _Kind.multi, _Kind.slow][_rng.nextInt(3)], at.dx, at.dy));
    } else if (_rng.nextDouble() < 0.08) {
      _pickups.add(_Pickup(_Kind.coin, at.dx, at.dy));
    }
  }

  void _shatter(Rect rc, Color col, int n) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final sp = 90 + _rng.nextDouble() * 200;
      _shards.add(
        _Shard(
          rc.left + _rng.nextDouble() * rc.width,
          rc.top + _rng.nextDouble() * rc.height,
          cos(a) * sp,
          sin(a) * sp - 140,
          (_rng.nextDouble() - 0.5) * 16,
          8 + _rng.nextDouble() * 6,
          col,
        ),
      );
    }
  }

  void _clearLevel() {
    Sound.play(Sfx.perfect);
    _flash = 1;
    level++;
    _pickups.clear();
    _newLevel();
    _resetBall();
  }

  void _loseBall() {
    Sound.play(Sfx.crash);
    _shake = 10;
    _pickups.removeWhere((p) => p.kind != _Kind.coin);
    if (lives.loseLife()) {
      gameOver();
    } else {
      _resetBall();
    }
  }

  void _updatePickups(double dt) {
    for (final p in List.of(_pickups)) {
      p.age += dt;
      p.y += (150 + 8 * level) * dt;
      if (_magnetLeft > 0) p.x += ((_px - p.x) * 2.6).clamp(-170.0, 170.0) * dt;
      final caught = p.y + 13 >= _paddleY && p.y - 13 <= _paddleY + _paddleH && (p.x - _px).abs() <= _pw / 2 + 12;
      if (caught) {
        _pickups.remove(p);
        _collect(p);
      } else if (p.y > size.y + 20) {
        _pickups.remove(p);
      }
    }
  }

  void _collect(_Pickup p) {
    _squash = 0.5;
    switch (p.kind) {
      case _Kind.coin:
        coins.value++;
        Sound.play(Sfx.coin);
        _pops.add(_Pop('+1', p.x, _paddleY - 16, AppColors.yellow, 16));
      case _Kind.wide:
        _wideLeft = 10;
        Sound.play(Sfx.coin, volume: 0.6);
        _pops.add(_Pop('Wide paddle', p.x, _paddleY - 16, AppColors.green, 16));
      case _Kind.slow:
        _slowLeft = 8;
        Sound.play(Sfx.coin, volume: 0.6);
        _pops.add(_Pop('Slow ball', p.x, _paddleY - 16, AppColors.teal, 16));
      case _Kind.multi:
        _splitBall();
        Sound.play(Sfx.coin, volume: 0.6);
        _pops.add(_Pop('Multi-ball', p.x, _paddleY - 16, AppColors.blue, 16));
      case _Kind.bolt:
        Sound.play(Sfx.coin);
        requestBoost();
    }
  }

  void _splitBall() {
    if (!_launched || _balls.isEmpty || _balls.length > 6) return;
    final b = _balls.first;
    for (final a in const [-0.45, 0.45]) {
      final v = fixVelocity(b.vx * cos(a) - b.vy * sin(a), b.vx * sin(a) + b.vy * cos(a), _speed);
      _balls.add(_Ball(b.x, b.y, v.$1, v.$2));
    }
  }

  @override
  void applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.extraLife:
        lives.add();
      case PowerupType.slowMo:
        _slowLeft = 8;
      case PowerupType.magnet:
        _magnetLeft = 10;
      case PowerupType.doubleScore:
        _doubleLeft = 10;
      default:
        break;
    }
  }

  @override
  void revive() {
    lives.count = max(1, lives.count);
    _pickups.clear();
    _resetBall();
  }

  // ---------------------------------------------------------------- rendering

  Color _dark(Color c) => Color.lerp(c, _ink, 0.38)!;
  Color _light(Color c) => Color.lerp(c, const Color(0xFFFFFFFF), 0.4)!;

  Color _brickColor(Brick b) => switch (b.type) {
    BrickType.normal => _rowColors[(b.row + b.col ~/ 4) % _rowColors.length],
    BrickType.steel => _steel,
    BrickType.gold => AppColors.yellow,
    BrickType.vault => _vaultBody,
  };

  final _fill = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _ink;

  /// Filled shape with an ink outline.
  void _piece(Canvas c, Path p, Color col, [double w = 2.5]) {
    c.drawPath(p, _fill..color = col);
    c.drawPath(p, _line..strokeWidth = w);
  }

  void _text(
    Canvas c,
    String s,
    Offset at,
    double fs,
    Color col, {
    double alpha = 1,
    double scale = 1,
    bool outline = true,
  }) {
    TextPainter mk(Paint? fg) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Baloo2',
          fontWeight: FontWeight.w800,
          fontSize: fs,
          height: 1,
          color: fg == null ? col.withValues(alpha: alpha) : null,
          foreground: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = fs * 0.28
      ..strokeJoin = StrokeJoin.round
      ..color = _ink.withValues(alpha: alpha);
    final o = mk(stroke), f = mk(null);
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(scale);
    if (outline) o.paint(c, Offset(-o.width / 2, -o.height / 2));
    f.paint(c, Offset(-f.width / 2, -f.height / 2));
    c.restore();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x == 0) return;
    final w = size.x, h = size.y;
    canvas.save();
    canvas.translate(sin(_t * 97) * _shake, cos(_t * 83) * _shake);
    _backdrop(canvas, w, h);

    for (final b in _bricks) {
      final k = Curves.easeOutBack.transform(((_enterT - b.row * 0.05) / 0.35).clamp(0.0, 1.0));
      final rc = _rect(b).shift(Offset(0, -(1 - k) * 220));
      _brick(canvas, rc, b);
    }

    for (final b in _balls) {
      for (var i = 0; i < b.trail.length; i++) {
        final k = (i + 1) / b.trail.length;
        canvas.drawCircle(b.trail[i], _ballR * (0.35 + 0.5 * k), _fill..color = _paper.withValues(alpha: 0.35 * k));
      }
    }
    for (final p in _pickups) {
      _pickup(canvas, p);
    }
    _paddle(canvas);
    for (final b in _balls) {
      canvas.drawCircle(Offset(b.x, b.y + 2), _ballR, _fill..color = _ink);
      canvas.drawCircle(Offset(b.x, b.y), _ballR, _fill..color = _paper);
      canvas.drawCircle(Offset(b.x, b.y), _ballR, _line..strokeWidth = 2.5);
      canvas.drawCircle(Offset(b.x - 2.5, b.y - 2.5), 2, _fill..color = const Color(0xFFFFFFFF));
    }

    for (final s in _shards) {
      final k = 1 - s.age / 0.8;
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(s.rot);
      final r = s.size * (0.4 + 0.6 * k);
      _piece(
        canvas,
        Path()
          ..moveTo(-r, r * 0.7)
          ..lineTo(r * 0.2, -r)
          ..lineTo(r, r * 0.5)
          ..close(),
        s.color,
        2,
      );
      canvas.restore();
    }
    for (final p in _pops) {
      final k = p.age / 0.9;
      final pop = 1 + 0.35 * sin(min(1, p.age * 7) * pi);
      final a = (1 - max(0.0, (k - 0.6) / 0.4)).clamp(0.0, 1.0).toDouble();
      _text(canvas, p.text, Offset(p.x, p.y - k * 36), p.size, p.color, alpha: a, scale: pop);
    }
    canvas.restore();

    _hud(canvas, w);
    if (_banner > 0) _bannerPlate(canvas, w, h);
    if (!_launched && !isOver && _banner < 0.8) {
      final a = 0.55 + 0.45 * sin(_t * 5);
      _text(canvas, 'TOUCH TO LAUNCH', Offset(w / 2, _paddleY - 44), 14, _paper, alpha: a);
    }
  }

  void _backdrop(Canvas c, double w, double h) {
    c.drawRect(Rect.fromLTWH(-20, -20, w + 40, h + 40), _fill..color = _wallBase);
    const tile = 78.0;
    for (var y = 0.0; y < h; y += tile) {
      for (var x = 0.0; x < w; x += tile) {
        final odd = ((x / tile).floor() + (y / tile).floor()).isOdd;
        c.drawRect(Rect.fromLTWH(x + 3, y + 3, tile - 6, tile - 6), _fill..color = odd ? _wallLight : _wallBase);
        c.drawRect(Rect.fromLTWH(x + 3, y + tile - 6, tile - 6, 3), _fill..color = _wallDark);
        for (final o in const [
          Offset(10, 10),
          Offset(tile - 10, 10),
          Offset(10, tile - 10),
          Offset(tile - 10, tile - 10),
        ]) {
          c.drawCircle(Offset(x, y) + o, 2, _fill..color = _wallDark);
        }
      }
    }
    // The vault door behind the wall: rings and spokes in the same dark tone.
    final dc = Offset(w / 2, _gridTop + 130);
    c.drawCircle(dc, 150, _fill..color = _wallDark);
    c.drawCircle(dc, 150, _line..strokeWidth = 3);
    c.drawCircle(dc, 112, _fill..color = _wallBase);
    c.drawCircle(dc, 112, _line..strokeWidth = 3);
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + _t * 0.05;
      c.drawLine(dc, dc + Offset(cos(a), sin(a)) * 112, _line..strokeWidth = 8);
    }
    c.drawCircle(dc, 30, _fill..color = _wallDark);
    c.drawCircle(dc, 30, _line..strokeWidth = 3);

    // Floor with the paddle rail: the drag zone.
    final fy = _paddleY + _paddleH + 22;
    c.drawRect(Rect.fromLTWH(-20, fy, w + 40, h - fy + 20), _fill..color = _floor);
    for (var x = -20.0, i = 0; x < w; x += 39, i++) {
      if (i.isEven) c.drawRect(Rect.fromLTWH(x, fy + 6, 39, h), _fill..color = _wallDark);
    }
    c.drawRect(Rect.fromLTWH(-20, fy, w + 40, 3), _fill..color = _ink);
    final rail = Rect.fromLTWH(_wall, _paddleY + _paddleH / 2 - 3, w - 2 * _wall, 6);
    c.drawRect(rail, _fill..color = _floor);
    c.drawRect(rail, _line..strokeWidth = 2);

    // Steel side rails and ceiling beam.
    c.drawRect(Rect.fromLTWH(0, 0, _wall, h), _fill..color = _steel);
    c.drawRect(Rect.fromLTWH(w - _wall, 0, _wall, h), _fill..color = _steel);
    c.drawLine(Offset(_wall, 0), Offset(_wall, h), _line..strokeWidth = 2.5);
    c.drawLine(Offset(w - _wall, 0), Offset(w - _wall, h), _line..strokeWidth = 2.5);
    c.drawRect(Rect.fromLTWH(-4, -4, w + 8, _ceiling + 4), _fill..color = _steel);
    c.drawRect(Rect.fromLTWH(-4, _ceiling - 8, w + 8, 8), _fill..color = _vaultBody);
    c.drawLine(Offset(0, _ceiling), Offset(w, _ceiling), _line..strokeWidth = 3);
  }

  void _brick(Canvas c, Rect rc, Brick b) {
    final col = _brickColor(b);
    final face = Rect.fromLTWH(rc.left, rc.top, rc.width, _brickH);
    final under = RRect.fromRectAndRadius(face.shift(const Offset(0, _faceH)), const Radius.circular(5));
    final front = RRect.fromRectAndRadius(face, const Radius.circular(5));
    c.drawRRect(under, _fill..color = _dark(col));
    c.drawRRect(under, _line..strokeWidth = 2.5);
    c.drawRRect(front, _fill..color = col);
    c.drawRect(Rect.fromLTWH(face.left + 5, face.top + 4, face.width - 10, 4), _fill..color = _light(col));
    c.drawRRect(front, _line..strokeWidth = 2.5);
    final m = face.center;
    switch (b.type) {
      case BrickType.normal:
        break;
      case BrickType.steel:
        for (final dx in [-face.width / 2 + 7, face.width / 2 - 7]) {
          c.drawCircle(Offset(m.dx + dx, m.dy + 2), 2.2, _fill..color = _dark(col));
        }
        if (b.hp < 2) _crack(c, face, 1);
      case BrickType.gold:
        c.drawCircle(m.translate(0, 2), 7, _fill..color = _light(col));
        c.drawCircle(m.translate(0, 2), 7, _line..strokeWidth = 2);
        _text(c, '₹', m.translate(0, 2), 10, _ink, outline: false);
      case BrickType.vault:
        c.drawCircle(m.translate(0, 2), 9.5, _fill..color = AppColors.yellow);
        c.drawCircle(m.translate(0, 2), 9.5, _line..strokeWidth = 2.2);
        for (var i = 0; i < 4; i++) {
          final a = i * pi / 2 + pi / 4;
          c.drawLine(m.translate(0, 2), m.translate(cos(a) * 9.5, 2 + sin(a) * 9.5), _line..strokeWidth = 2);
        }
        c.drawCircle(m.translate(0, 2), 2.5, _fill..color = _ink);
        if (b.hp < 3) _crack(c, face, 4 - b.hp);
    }
  }

  void _crack(Canvas c, Rect f, int n) {
    final p = Path()
      ..moveTo(f.left + f.width * 0.55, f.top + 1)
      ..lineTo(f.left + f.width * 0.45, f.top + f.height * 0.4)
      ..lineTo(f.left + f.width * 0.6, f.top + f.height * 0.65)
      ..lineTo(f.left + f.width * 0.5, f.bottom - 1);
    if (n > 1) {
      p
        ..moveTo(f.left + f.width * 0.45, f.top + f.height * 0.4)
        ..lineTo(f.left + f.width * 0.2, f.top + f.height * 0.55)
        ..moveTo(f.left + f.width * 0.6, f.top + f.height * 0.65)
        ..lineTo(f.left + f.width * 0.85, f.top + f.height * 0.45);
    }
    c.drawPath(p, _line..strokeWidth = 2);
  }

  void _paddle(Canvas c) {
    final sx = 1 + 0.16 * _squash, sy = 1 - 0.4 * _squash;
    c.save();
    c.translate(_px, _paddleY + _paddleH);
    c.scale(sx, sy);
    final r = Rect.fromLTWH(-_pw / 2, -_paddleH, _pw, _paddleH);
    final under = RRect.fromRectAndRadius(r.shift(const Offset(0, 5)), const Radius.circular(8));
    final top = RRect.fromRectAndRadius(r, const Radius.circular(8));
    c.drawRRect(under, _fill..color = _dark(AppColors.blue));
    c.drawRRect(under, _line..strokeWidth = 2.5);
    c.drawRRect(top, _fill..color = AppColors.blue);
    c.drawRect(Rect.fromLTWH(r.left + 8, r.top + 3, r.width - 16, 3), _fill..color = _light(AppColors.blue));
    c.drawRRect(top, _line..strokeWidth = 2.5);
    c.restore();
  }

  void _pickup(Canvas c, _Pickup p) {
    final o = Offset(p.x, p.y);
    final col = switch (p.kind) {
      _Kind.coin => AppColors.yellow,
      _Kind.wide => AppColors.green,
      _Kind.multi => AppColors.blue,
      _Kind.slow => AppColors.teal,
      _Kind.bolt => AppColors.orange,
    };
    if (p.kind == _Kind.bolt) {
      final pulse = 0.5 + 0.5 * sin(p.age * 8);
      c.drawCircle(o, 17 + 4 * pulse, _line..strokeWidth = 3);
      c.drawCircle(o, 17 + 4 * pulse, _fill..color = AppColors.yellow.withValues(alpha: 0.35));
    }
    c.drawCircle(o.translate(0, 3), 13, _fill..color = _ink);
    c.drawCircle(o, 13, _fill..color = col);
    c.drawCircle(o, 13, _line..strokeWidth = 2.5);
    final white = _fill..color = const Color(0xFFFFFFFF);
    switch (p.kind) {
      case _Kind.coin:
        _text(c, '₹', o.translate(0, 1), 14, _ink, outline: false);
      case _Kind.wide:
        c.drawLine(o.translate(-7, 0), o.translate(7, 0), _line..strokeWidth = 2.5);
        for (final s in [-1.0, 1.0]) {
          c.drawPath(
            Path()
              ..moveTo(o.dx + s * 8, o.dy)
              ..lineTo(o.dx + s * 3, o.dy - 4)
              ..lineTo(o.dx + s * 3, o.dy + 4)
              ..close(),
            _fill..color = const Color(0xFFFFFFFF),
          );
        }
      case _Kind.multi:
        for (final d in const [Offset(-5, 3), Offset(5, 3), Offset(0, -5)]) {
          c.drawCircle(o + d, 3.2, white);
          c.drawCircle(o + d, 3.2, _line..strokeWidth = 1.6);
        }
      case _Kind.slow:
        c.drawCircle(o, 7, _fill..color = const Color(0xFFFFFFFF));
        c.drawCircle(o, 7, _line..strokeWidth = 1.8);
        c.drawLine(o, o.translate(0, -5), _line..strokeWidth = 1.8);
        c.drawLine(o, o.translate(4, 1), _line..strokeWidth = 1.8);
      case _Kind.bolt:
        _piece(
          c,
          Path()
            ..moveTo(o.dx + 2, o.dy - 9)
            ..lineTo(o.dx - 5, o.dy + 1)
            ..lineTo(o.dx, o.dy + 1)
            ..lineTo(o.dx - 2, o.dy + 9)
            ..lineTo(o.dx + 5, o.dy - 2)
            ..lineTo(o.dx, o.dy - 2)
            ..close(),
          AppColors.yellow,
          2,
        );
    }
  }

  void _hud(Canvas c, double w) {
    // Hearts, top-left under the host HUD (the top 90px stay free).
    for (var i = 0; i < Lives.max; i++) {
      if (i >= max(3, lives.count)) break;
      final o = Offset(20.0 + i * 24, 106);
      const s = 7.5;
      final p = Path()
        ..moveTo(o.dx, o.dy + s * 0.95)
        ..cubicTo(o.dx - s * 1.7, o.dy - s * 0.1, o.dx - s * 0.8, o.dy - s * 1.2, o.dx, o.dy - s * 0.4)
        ..cubicTo(o.dx + s * 0.8, o.dy - s * 1.2, o.dx + s * 1.7, o.dy - s * 0.1, o.dx, o.dy + s * 0.95);
      _piece(c, p, i < lives.count ? AppColors.red : _wallDark, 2.2);
    }
    // Active timers, right-aligned on the same row.
    final chips = <(String, Color, double)>[
      if (_wideLeft > 0) ('WIDE', AppColors.green, _wideLeft),
      if (_slowLeft > 0) ('SLOW', AppColors.teal, _slowLeft),
      if (_magnetLeft > 0) ('MAGNET', AppColors.orange, _magnetLeft),
      if (_doubleLeft > 0) ('2X', AppColors.yellow, _doubleLeft),
    ];
    var x = w - 12;
    for (final (label, col, left) in chips.reversed) {
      final bw = 24.0 + label.length * 8.5;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x - bw, 96, bw, 22), const Radius.circular(11));
      c.drawRRect(r.shift(const Offset(0, 2)), _fill..color = _ink);
      c.drawRRect(r, _fill..color = col);
      c.drawRRect(r, _line..strokeWidth = 2);
      _text(c, '$label ${left.ceil()}', Offset(x - bw / 2, 107), 11.5, _ink, outline: false);
      x -= bw + 6;
    }
  }

  void _bannerPlate(Canvas c, double w, double h) {
    final k = Curves.easeOutBack.transform(min(1, (1.5 - _banner) / 0.3));
    final out = ((_banner) / 0.3).clamp(0.0, 1.0);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h * 0.42), width: 230 * k, height: 76 * k),
      const Radius.circular(18),
    );
    c.save();
    c.drawRRect(r.shift(const Offset(0, 6)), _fill..color = _ink.withValues(alpha: out));
    c.drawRRect(r, _fill..color = AppColors.yellow.withValues(alpha: out));
    c.drawRRect(r, _line..strokeWidth = 3);
    c.restore();
    if (k > 0.5) _text(c, 'LEVEL $level', Offset(w / 2, h * 0.42), 36 * k, _paper, alpha: out);
  }
}

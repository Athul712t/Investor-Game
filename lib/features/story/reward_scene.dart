import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'story_art.dart';
import 'story_data.dart';

/// Chapter-complete celebration: a chest drops in, its lid swings open and coins arc out.
/// The rewards are granted by the caller before this is shown.
class RewardScene extends StatefulWidget {
  const RewardScene({
    super.key,
    required this.node,
    required this.chapter,
    required this.number,
    required this.next,
    required this.firstTime,
  });
  final StoryNode node;
  final Chapter chapter;
  final int number;
  final Chapter? next;
  final bool firstTime;

  @override
  State<RewardScene> createState() => _RewardSceneState();
}

class _RewardSceneState extends State<RewardScene> with TickerProviderStateMixin {
  // One timeline for the whole moment; marks below are fractions of it.
  late final _show = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..addListener(_cue);
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  static const _lidAt = 0.24, _lidEnd = 0.42;
  bool _opened = false;
  final _landed = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.reduceMotion) {
        _show.value = 1;
      } else {
        _show.forward();
        _loop.repeat();
      }
    });
  }

  void _cue() {
    final t = _show.value;
    if (!_opened && t >= _lidAt) {
      _opened = true;
      if (_show.isAnimating) Sound.play(Sfx.levelUp);
    }
    for (var k = 0; k < _Coins.count; k++) {
      if (!_landed.contains(k) && _Coins.flight(k, t) >= 1) {
        _landed.add(k);
        if (_show.isAnimating) Sound.play(Sfx.coin, volume: 0.6);
      }
    }
  }

  @override
  void dispose() {
    _show.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chapter.color;
    final next = widget.next;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PaperBackground(),
          Positioned.fill(
            child: ExcludeSemantics(child: CustomPaint(painter: _CelebrationPainter(_loop, _show))),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AnimatedBuilder(
                    animation: _show,
                    builder: (context, _) {
                      final open = _show.value >= _lidEnd;
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: pieceDecoration(fill: AppColors.ink, radius: 999, depth: 0),
                            child: Text(
                              'CHAPTER ${widget.number} COMPLETE',
                              style: context.text.titleSmall!.copyWith(color: AppColors.card, letterSpacing: 2),
                            ),
                          ),
                          _ChestStage(t: _show.value),
                          Ribbon(
                            color: c,
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                            child: Text(
                              widget.chapter.title,
                              textAlign: TextAlign.center,
                              style: context.text.headlineSmall!.copyWith(color: AppColors.on(c)),
                            ),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          Text('New title earned', style: context.text.bodyMedium),
                          Text(widget.node.title, textAlign: TextAlign.center, style: context.text.headlineMedium),
                          const SizedBox(height: AppSpace.md),
                          Wrap(
                            spacing: AppSpace.sm,
                            runSpacing: AppSpace.sm,
                            alignment: WrapAlignment.center,
                            children: [
                              _Tally(
                                icon: const Icon(Icons.bolt_rounded, size: 20, color: AppColors.card),
                                color: AppColors.blue,
                                value: open ? widget.node.xp : 0,
                                suffix: ' XP',
                                semantic: '+${widget.node.xp} XP',
                              ),
                              _Tally(
                                icon: const Coin3D(size: 24),
                                value: open ? widget.node.coins : 0,
                                semantic: '+${widget.node.coins} coins',
                              ),
                            ],
                          ),
                          if (!widget.firstTime) ...[
                            const SizedBox(height: AppSpace.sm),
                            Text('Already collected on your first run', style: context.text.bodySmall),
                          ],
                          const SizedBox(height: AppSpace.lg),
                          Panel(
                            child: Row(
                              children: [
                                Badge3D(
                                  icon: next == null ? Icons.auto_stories_rounded : Icons.lock_open_rounded,
                                  color: next?.color ?? AppColors.teal,
                                  size: 44,
                                ),
                                const SizedBox(width: AppSpace.md),
                                Expanded(
                                  child: Text(
                                    next == null
                                        ? 'You finished the story so far. More chapters are on the way!'
                                        : 'Next up: ${next.title} is now unlocked.',
                                    style: context.text.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          ChunkyButton(
                            label: 'Back to map',
                            icon: Icons.map_rounded,
                            color: c,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reward count in a pill: icon on a block, then a number that rolls up.
class _Tally extends StatelessWidget {
  const _Tally({required this.icon, required this.value, required this.semantic, this.color, this.suffix = ''});
  final Widget icon;
  final Color? color;
  final int value;
  final String suffix, semantic;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semantic,
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
      decoration: pieceDecoration(radius: 999, depth: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: color == null ? null : BoxDecoration(color: color, shape: BoxShape.circle),
            child: icon,
          ),
          const SizedBox(width: 6),
          CountUp(value: value, prefix: '+', suffix: suffix, style: context.text.titleLarge),
        ],
      ),
    ),
  );
}

/// Where each coin flies. Pure timing so the scene can cue the landing sound.
abstract final class _Coins {
  static const count = 8;
  static const _spread = [-1.0, 0.62, -0.55, 1.0, -0.82, 0.8, -0.68, 0.5];

  /// 0 before launch, 1 once landed.
  static double flight(int k, double t) => ((t - 0.3 - k * 0.04) / 0.28).clamp(0.0, 1.0);

  static Offset at(int k, double t, Size stage, Offset mouth) {
    final s = flight(k, t);
    final land = Offset(stage.width / 2 + _spread[k] * (stage.width / 2 - 22), stage.height - 18 - (k % 3) * 6);
    final arc = 110 + (k % 3) * 25.0;
    return Offset.lerp(mouth, land, s)! - Offset(0, arc * 4 * s * (1 - s));
  }
}

class _ChestStage extends StatelessWidget {
  const _ChestStage({required this.t});
  final double t;

  static const _size = Size(300, 230), _chest = Size(140, 120);

  @override
  Widget build(BuildContext context) {
    final drop = Curves.bounceOut.transform((t / 0.2).clamp(0.0, 1.0));
    final lid = Curves.easeOutBack.transform(((t - _RewardSceneState._lidAt) / 0.18).clamp(0.0, 1.0));
    final angle = lid * 1.95; // swings past upright to show its inside
    final left = (_size.width - _chest.width) / 2;
    final top = _size.height - _chest.height - 14 - (1 - drop) * 160;
    final mouth = Offset(_size.width / 2, top + 40);
    return Semantics(
      label: 'Treasure chest',
      child: SizedBox.fromSize(
        size: _size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Hard shadow on the floor, growing as the chest lands.
            Positioned(
              left: left + 6 + (1 - drop) * 30,
              right: left + 6 + (1 - drop) * 30,
              top: _size.height - 22,
              height: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: CustomPaint(
                size: _chest,
                painter: _ChestPainter(open: angle > 0.05),
              ),
            ),
            // Lid hinged on its bottom edge, swinging back in perspective.
            Positioned(
              left: left - 4,
              top: top - 2,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.004)
                  ..rotateX(angle),
                child: CustomPaint(
                  size: const Size(148, 46),
                  painter: _LidPainter(inside: angle > pi / 2),
                ),
              ),
            ),
            for (var k = 0; k < _Coins.count; k++)
              if (_Coins.flight(k, t) > 0)
                Positioned(
                  left: _Coins.at(k, t, _size, mouth).dx - 13,
                  top: _Coins.at(k, t, _size, mouth).dy - 13,
                  child: const Coin3D(size: 26),
                ),
          ],
        ),
      ),
    );
  }
}

final _wood = Color.lerp(AppColors.orange, AppColors.ink, 0.42)!;

/// Chest body, 140x120: wooden box with gold bands and a lock plate. The lid is a separate piece.
class _ChestPainter extends CustomPainter {
  _ChestPainter({required this.open});
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    Path r(double l, double t, double rr, double b, [double rad = 4]) =>
        Path()..addRRect(RRect.fromLTRBR(l, t, rr, b, Radius.circular(rad)));
    if (open) {
      // The dark inside, with treasure peeking over the rim.
      piece(canvas, r(4, 30, 136, 50, 4), AppColors.ink);
      for (final x in [38.0, 58.0, 80.0, 100.0]) {
        piece(canvas, Path()..addOval(Rect.fromCircle(center: Offset(x, 40), radius: 9)), AppColors.yellow, stroke: 2);
      }
    }
    piece(canvas, r(0, 44, 140, 120, 8), _wood, shadow: 0);
    final plank = Paint()
      ..strokeWidth = 2
      ..color = side(_wood);
    canvas.drawLine(const Offset(4, 70), const Offset(136, 70), plank);
    canvas.drawLine(const Offset(4, 95), const Offset(136, 95), plank);
    piece(canvas, r(16, 44, 30, 120, 2), AppColors.yellow);
    piece(canvas, r(110, 44, 124, 120, 2), AppColors.yellow);
    piece(canvas, r(56, 52, 84, 84, 6), AppColors.yellow);
    canvas.drawCircle(const Offset(70, 64), 4, Paint()..color = AppColors.ink);
    canvas.drawRect(const Rect.fromLTWH(68.5, 64, 3, 11), Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_ChestPainter old) => old.open != open;
}

/// Rounded chest lid, 148x46. Past upright we see its plain inside.
class _LidPainter extends CustomPainter {
  _LidPainter({required this.inside});
  final bool inside;

  @override
  void paint(Canvas canvas, Size size) {
    final lid = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          0,
          0,
          size.width,
          size.height,
          topLeft: const Radius.circular(34),
          topRight: const Radius.circular(34),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
      );
    if (inside) {
      piece(canvas, lid, side(_wood));
      return;
    }
    piece(canvas, lid, _wood);
    canvas.save();
    canvas.clipPath(lid);
    for (final x in [20.0, 114.0]) {
      piece(canvas, Path()..addRect(Rect.fromLTWH(x, -4, 14, size.height + 8)), AppColors.yellow);
    }
    canvas.restore();
    canvas.drawPath(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSpace.outline
        ..color = AppColors.ink,
    );
    piece(canvas, Path()..addRRect(RRect.fromLTRBR(62, 28, 86, 50, const Radius.circular(5))), AppColors.yellow);
  }

  @override
  bool shouldRepaint(_LidPainter old) => old.inside != inside;
}

/// Slowly turning solid rays behind the chest, and outlined confetti once the lid is open.
class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.loop, this.show) : super(repaint: Listenable.merge([loop, show]));
  final Animation<double> loop, show;

  static const _colors = [AppColors.green, AppColors.yellow, AppColors.red, AppColors.blue, AppColors.teal];

  @override
  void paint(Canvas canvas, Size size) {
    final v = loop.value;
    final center = Offset(size.width / 2, size.height * 0.3);
    final ray = Paint()..color = AppColors.paperDeep;
    final reach = size.longestSide;
    for (var i = 0; i < 12; i++) {
      final a = v * 2 * pi / 3 + i * 2 * pi / 12;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + cos(a - 0.12) * reach, center.dy + sin(a - 0.12) * reach)
          ..lineTo(center.dx + cos(a + 0.12) * reach, center.dy + sin(a + 0.12) * reach)
          ..close(),
        ray,
      );
    }
    // Confetti starts falling when the lid opens. Fixed seed: each piece keeps its lane, speed and spin.
    final since = show.value - _RewardSceneState._lidAt;
    if (since <= 0 || !show.isAnimating && !loop.isAnimating) return;
    final rng = Random(3);
    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.ink;
    for (var i = 0; i < 46; i++) {
      final x = rng.nextDouble() * size.width;
      final speed = 0.6 + rng.nextDouble();
      final phase = rng.nextDouble();
      // First pass drops from above the screen; then the pieces loop.
      final y = ((v * speed * 3 + phase) % 1.15 - 0.1) * size.height;
      final sway = sin((v * 6 + phase) * 2 * pi) * 10;
      fill.color = _colors[i % _colors.length];
      canvas
        ..save()
        ..translate(x + sway, y)
        ..rotate((v * 8 * speed + phase) * 2 * pi);
      if (i.isEven) {
        const r = Rect.fromLTWH(-5, -5, 10, 10);
        canvas
          ..drawRect(r, fill)
          ..drawRect(r, edge);
      } else {
        canvas
          ..drawCircle(Offset.zero, 5, fill)
          ..drawCircle(Offset.zero, 5, edge);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => false;
}

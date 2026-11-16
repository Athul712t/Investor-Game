import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'story_data.dart';

/// Chapter-complete celebration: spinning rays, confetti, trophy, rewards.
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

class _RewardSceneState extends State<RewardScene> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _loop.stop() : _loop.repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chapter.color;
    final calm = MediaQuery.disableAnimationsOf(context);
    final next = widget.next;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.1,
                colors: [Color.lerp(c, AppColors.ink, 0.6)!, AppColors.ink],
              ),
            ),
          ),
          Positioned.fill(
            child: ExcludeSemantics(child: CustomPaint(painter: _CelebrationPainter(_loop, c))),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      Text(
                        'CHAPTER ${widget.number} COMPLETE',
                        style: context.text.titleSmall!.copyWith(color: c, letterSpacing: 2),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: calm ? 1 : 0.3, end: 1),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.elasticOut,
                        builder: (_, s, child) => Transform.scale(scale: s, child: child),
                        child: const Badge3D(emoji: '🏆', color: AppColors.yellow, size: 132),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      Text('New title earned', style: context.text.bodyMedium),
                      Text(
                        widget.node.title,
                        textAlign: TextAlign.center,
                        style: context.text.displaySmall!.copyWith(
                          shadows: [Shadow(color: c.withValues(alpha: 0.6), blurRadius: 18)],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Wrap(
                        spacing: AppSpace.sm,
                        alignment: WrapAlignment.center,
                        children: [
                          StatPill(icon: Icons.bolt_rounded, value: '+${widget.node.xp} XP', color: AppColors.blue),
                          StatPill(
                            icon: Icons.monetization_on_rounded,
                            value: '+${widget.node.coins}',
                            color: AppColors.yellow,
                            semantic: 'Coins',
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
                            Text(next == null ? '✨' : '🔓', style: const TextStyle(fontSize: 28)),
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

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.t, this.tint) : super(repaint: t);
  final Animation<double> t;
  final Color tint;

  static const _colors = [AppColors.green, AppColors.yellow, AppColors.red, AppColors.blue, AppColors.teal];

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final center = Offset(size.width / 2, size.height * 0.36);
    // Slowly turning sunburst behind the trophy.
    final ray = Paint()..color = tint.withValues(alpha: 0.10);
    final reach = size.longestSide;
    for (var i = 0; i < 14; i++) {
      final a = v * 2 * pi / 3 + i * 2 * pi / 14;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + cos(a - 0.09) * reach, center.dy + sin(a - 0.09) * reach)
          ..lineTo(center.dx + cos(a + 0.09) * reach, center.dy + sin(a + 0.09) * reach)
          ..close(),
        ray,
      );
    }
    // Confetti: fixed seed so each piece has a stable lane, speed and spin.
    final rng = Random(3);
    final p = Paint();
    for (var i = 0; i < 70; i++) {
      final x = rng.nextDouble() * size.width;
      final speed = 0.6 + rng.nextDouble();
      final y = ((v * speed * 3 + rng.nextDouble()) % 1.15 - 0.08) * size.height;
      final sway = sin((v * 6 + rng.nextDouble()) * 2 * pi) * 12;
      p.color = _colors[i % _colors.length];
      canvas.save();
      canvas.translate(x + sway, y);
      canvas.rotate((v * 8 * speed + rng.nextDouble()) * 2 * pi);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -3, 10, 6), const Radius.circular(2)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => old.tint != tint;
}

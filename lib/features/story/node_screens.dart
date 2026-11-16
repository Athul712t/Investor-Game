import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/game/game_types.dart';
import '../content/question_view.dart';
import '../games/_shared/games_registry.dart';
import 'story_art.dart';
import 'story_data.dart';

String gameUnit(String? gameId) => switch (gameId) {
  'runner' => 'metres',
  'stack' => 'blocks',
  _ => 'points',
};

/// Shows the goal, launches the game, and lets the player retry. After two
/// missed tries "Continue anyway" appears so nobody gets stuck. Pops true when passed or skipped.
class GameNodeScreen extends StatefulWidget {
  const GameNodeScreen({super.key, required this.node, required this.color});
  final StoryNode node;
  final Color color;

  @override
  State<GameNodeScreen> createState() => _GameNodeScreenState();
}

class _GameNodeScreenState extends State<GameNodeScreen> {
  int _misses = 0;
  GameResult? _last;

  bool get _passed => (_last?.score ?? -1) >= widget.node.target;

  Future<void> _launch() async {
    final r = await context.push<GameResult>('/play/${widget.node.gameId}?target=${widget.node.target}');
    if (!mounted || r == null) return;
    setState(() {
      _last = r;
      if (!_passed) _misses++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final spec = gameById(n.gameId ?? '');
    final unit = gameUnit(n.gameId);
    final last = _last;
    return AppScaffold(
      appBar: AppBar(title: Text(n.title)),
      // Toolbar gap sits outside the scroll view so content never scrolls under the transparent app bar.
      body: Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Panel(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                children: [
                  Badge3D(emoji: spec?.emoji ?? '🎮', color: spec?.color ?? widget.color, size: 88),
                  const SizedBox(height: AppSpace.md),
                  Text(spec?.title ?? 'Mini-game', style: context.text.headlineMedium),
                  const SizedBox(height: AppSpace.sm),
                  Text(n.intro, textAlign: TextAlign.center, style: context.text.bodyLarge),
                  const SizedBox(height: AppSpace.md),
                  _Goal(target: n.target, unit: unit),
                  if (last != null) ...[
                    const SizedBox(height: AppSpace.md),
                    Text(
                      _passed ? 'Goal reached with ${last.score}!' : 'You got ${last.score}. So close!',
                      style: context.text.titleMedium!.copyWith(color: _passed ? side(AppColors.green) : AppColors.red),
                    ),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  if (_passed)
                    ChunkyButton(
                      label: 'Continue story',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => Navigator.of(context).pop(true),
                    )
                  else ...[
                    ChunkyButton(
                      label: last == null ? 'Play' : 'Retry',
                      icon: last == null ? Icons.play_arrow_rounded : Icons.replay_rounded,
                      color: spec?.color ?? widget.color,
                      onPressed: _launch,
                    ),
                    if (_misses >= 2) ...[
                      const SizedBox(height: AppSpace.md),
                      ChunkyButton(
                        label: 'Continue anyway',
                        color: AppColors.paperDeep,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline decision. Any answer continues the story; pops with whether it was the wise choice.
class ScenarioScreen extends StatelessWidget {
  const ScenarioScreen({super.key, required this.node, required this.color});
  final StoryNode node;
  final Color color;

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Decision time')),
    body: Padding(
      padding: const EdgeInsets.only(top: kToolbarHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Badge3D(icon: Icons.call_split_rounded, color: AppColors.yellow, size: 48),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(node.title, style: context.text.headlineSmall)),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Panel(
              accent: color,
              padding: const EdgeInsets.all(AppSpace.lg),
              child: QuestionView(question: node.question!, onAnswered: (wise) => Navigator.of(context).pop(wise)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The goal as a game piece: a painted target beside a big outlined number.
class _Goal extends StatelessWidget {
  const _Goal({required this.target, required this.unit});
  final int target;
  final String unit;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Goal: $target $unit',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
      decoration: pieceDecoration(fill: AppColors.paperDeep, radius: 16, depth: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CustomPaint(size: Size.square(52), painter: _TargetPainter()),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GOAL', style: context.text.labelSmall!.copyWith(color: AppColors.ink, letterSpacing: 1.5)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    OutlinedText('$target', fill: AppColors.yellow, style: context.text.displaySmall),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(unit, style: context.text.titleMedium),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TargetPainter extends CustomPainter {
  const _TargetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    Path ring(double radius) => Path()..addOval(Rect.fromCircle(center: c, radius: radius));
    canvas.drawPath(ring(r).shift(const Offset(0, 3)), Paint()..color = AppColors.ink);
    for (final (f, color) in [(1.0, AppColors.red), (0.68, AppColors.card), (0.36, AppColors.red)]) {
      piece(canvas, ring(r * f), color);
    }
    // A dart stuck in the bullseye.
    final dart = Paint()
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.ink;
    canvas.drawLine(c, c + Offset(r * 0.8, -r * 0.8), dart);
    piece(
      canvas,
      Path()
        ..moveTo(c.dx + r * 0.6, c.dy - r * 0.8)
        ..lineTo(c.dx + r * 0.95, c.dy - r * 0.95)
        ..lineTo(c.dx + r * 0.8, c.dy - r * 0.6)
        ..close(),
      AppColors.blue,
      stroke: 2,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

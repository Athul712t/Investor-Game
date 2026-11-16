import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/game/game_types.dart';
import '../content/question_view.dart';
import '../games/_shared/games_registry.dart';
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
      glow: spec?.color ?? widget.color,
      appBar: AppBar(title: Text(n.title)),
      // Toolbar gap sits outside the scroll view so content never scrolls under the transparent app bar.
      body: Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Panel(
              accent: spec?.color ?? widget.color,
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                children: [
                  Badge3D(emoji: spec?.emoji ?? '🎮', color: spec?.color ?? widget.color, size: 88),
                  const SizedBox(height: AppSpace.md),
                  Text(spec?.title ?? 'Mini-game', style: context.text.headlineMedium),
                  const SizedBox(height: AppSpace.sm),
                  Text(n.intro, textAlign: TextAlign.center, style: context.text.bodyLarge),
                  const SizedBox(height: AppSpace.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '🎯  Goal: ${n.target} $unit',
                      style: context.text.titleLarge!.copyWith(color: AppColors.amber),
                    ),
                  ),
                  if (last != null) ...[
                    const SizedBox(height: AppSpace.md),
                    Text(
                      _passed ? 'Goal reached with ${last.score}!' : 'You got ${last.score}. So close!',
                      style: context.text.titleMedium!.copyWith(color: _passed ? AppColors.mint : AppColors.coral),
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
                        color: AppColors.surfaceHi,
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
    glow: color,
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
                const Badge3D(emoji: '🤔', color: AppColors.amber, size: 48),
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

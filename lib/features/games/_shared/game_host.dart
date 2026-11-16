import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content_repo.dart';
import '../../../core/profile.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../domain/entities/question.dart';
import '../../../domain/game/game_types.dart';
import '../../content/question_view.dart';
import 'arcade_game.dart';
import 'games_registry.dart';

enum _Phase { intro, playing, paused, boost, revive, results }

/// Runs any [ArcadeGame]: intro, HUD, pause, boost questions, one revive, results.
/// Pops with the last [GameResult] (or null if the player left before finishing).
class GameHostScreen extends ConsumerStatefulWidget {
  const GameHostScreen({super.key, required this.gameId, this.targetScore});
  final String gameId;
  final int? targetScore; // set by Story Mode

  @override
  ConsumerState<GameHostScreen> createState() => _GameHostState();
}

class _GameHostState extends ConsumerState<GameHostScreen> {
  late final GameSpec spec = gameById(widget.gameId)!;
  late ArcadeGame game;
  var _phase = _Phase.intro;
  final _rng = Random();
  final _watch = Stopwatch();
  Question? _question;
  PowerupType? _toast;
  bool _reviveUsed = false, _isBest = false;
  int _asked = 0, _correct = 0;
  GameResult? _result;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    game = spec.create(const GameConfig())
      ..onBoostRequested = _onBoost
      ..onGameOver = _onGameOver
      ..paused = true; // starts on the intro card
    _reviveUsed = false;
    _asked = _correct = 0;
    _watch.reset();
  }

  Question? _pickQuestion() => ref.read(contentProvider).value?.randomQuick(_rng);

  void _start() {
    setState(() => _phase = _Phase.playing);
    _watch.start();
    game.resumeEngine();
  }

  static const _headStartCost = 30;

  /// Spend coins to begin the run with a random power-up.
  void _headStart() {
    if (game.boosts.isEmpty || !ref.read(profileProvider.notifier).spend(_headStartCost)) return;
    final p = game.boosts[_rng.nextInt(game.boosts.length)];
    _start();
    game.applyPowerup(p);
    _showToast(p);
  }

  void _showToast(PowerupType p) {
    setState(() => _toast = p);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _pause() {
    if (_phase != _Phase.playing) return;
    game.pauseEngine();
    _watch.stop();
    setState(() => _phase = _Phase.paused);
  }

  void _resume() {
    setState(() => _phase = _Phase.playing);
    _watch.start();
    game.resumeEngine();
  }

  void _onBoost() {
    final q = _pickQuestion();
    if (q == null || _phase != _Phase.playing) return;
    game.pauseEngine();
    _watch.stop();
    setState(() {
      _question = q;
      _phase = _Phase.boost;
    });
  }

  void _onGameOver() {
    _watch.stop();
    final q = _reviveUsed ? null : _pickQuestion();
    if (q == null) return _finish();
    setState(() {
      _question = q;
      _phase = _Phase.revive;
    });
  }

  void _answered(bool correct) {
    _asked++;
    if (correct) _correct++;
    final wasRevive = _phase == _Phase.revive;
    if (wasRevive) {
      _reviveUsed = true;
      if (!correct) return _finish();
      setState(() => _phase = _Phase.playing);
      _watch.start();
      game.continueAfterRevive();
      return;
    }
    if (correct && game.boosts.isNotEmpty) {
      final p = game.boosts[_rng.nextInt(game.boosts.length)];
      game.applyPowerup(p);
      HapticFeedback.mediumImpact();
      _showToast(p);
    }
    _resume();
  }

  void _finish() {
    final r = GameResult(
      gameId: spec.id,
      score: game.score.value,
      durationMs: _watch.elapsedMilliseconds,
      coinsEarned: game.coins.value,
      xpEarned: 10 + 5 * _correct,
      questionsAnswered: _asked,
      questionsCorrect: _correct,
    );
    _isBest = ref.read(profileProvider.notifier).recordGame(r);
    setState(() {
      _result = r;
      _phase = _Phase.results;
    });
  }

  void _again() => setState(() {
    _newGame();
    _result = null;
    _phase = _Phase.intro;
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.intro || _phase == _Phase.results,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(key: ObjectKey(game), game: game),
            if (_phase == _Phase.playing || _phase == _Phase.paused) SafeArea(child: _hud(context)),
            if (_toast != null) SafeArea(child: _PowerupToast(_toast!)),
            if (_phase != _Phase.playing) _overlay(context),
          ],
        ),
      ),
    );
  }

  Widget _hud(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpace.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          onPressed: _pause,
          tooltip: 'Pause',
          style: IconButton.styleFrom(backgroundColor: AppColors.surface.withValues(alpha: 0.8)),
          icon: const Icon(Icons.pause_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              ValueListenableBuilder(
                valueListenable: game.score,
                builder: (_, v, _) => Text(
                  '$v',
                  style: context.text.displaySmall!.copyWith(
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
              ),
              if (widget.targetScore != null) Text('Goal ${widget.targetScore}', style: context.text.labelSmall),
            ],
          ),
        ),
        ValueListenableBuilder(
          valueListenable: game.coins,
          builder: (_, v, _) =>
              StatPill(icon: Icons.monetization_on_rounded, value: '$v', color: AppColors.amber, semantic: 'Coins'),
        ),
      ],
    ),
  );

  Widget _overlay(BuildContext context) {
    final Widget card = switch (_phase) {
      _Phase.intro => _card(context, [
        Badge3D(emoji: spec.emoji, color: spec.color, size: 72),
        const SizedBox(height: AppSpace.md),
        Text(spec.title, style: context.text.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.sm),
        Text(spec.howTo, style: context.text.bodyLarge, textAlign: TextAlign.center),
        if (widget.targetScore != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            'Reach ${widget.targetScore} to pass',
            style: context.text.titleMedium!.copyWith(color: AppColors.amber),
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        ChunkyButton(label: 'Start', icon: Icons.play_arrow_rounded, color: spec.color, onPressed: _start),
        if (ref.watch(profileProvider.select((p) => p.coins)) >= _headStartCost) ...[
          const SizedBox(height: AppSpace.md),
          ChunkyButton(
            label: 'Head start  ·  $_headStartCost coins',
            icon: Icons.bolt_rounded,
            color: AppColors.amber,
            onPressed: _headStart,
          ),
        ],
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
      ]),
      _Phase.paused => _card(context, [
        Text('Paused', style: context.text.headlineMedium),
        const SizedBox(height: AppSpace.lg),
        ChunkyButton(label: 'Resume', icon: Icons.play_arrow_rounded, onPressed: _resume),
        const SizedBox(height: AppSpace.md),
        ChunkyButton(label: 'End run', color: AppColors.surfaceHi, onPressed: _finish),
      ]),
      _Phase.boost || _Phase.revive => _card(context, [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_phase == _Phase.revive ? '❤️' : '⚡', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              _phase == _Phase.revive ? 'Answer to keep going' : 'Answer for a power-up',
              style: context.text.titleMedium!.copyWith(
                color: _phase == _Phase.revive ? AppColors.coral : AppColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        QuestionView(question: _question!, onAnswered: _answered, compact: true),
      ]),
      _Phase.results => _results(context),
      _Phase.playing => const SizedBox.shrink(),
    };
    return ColoredBox(
      color: AppColors.ink.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.md),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: card),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) => Panel(
    padding: const EdgeInsets.all(AppSpace.lg),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );

  Widget _results(BuildContext context) {
    final r = _result!;
    final target = widget.targetScore;
    final passed = target == null || r.score >= target;
    final best = ref.watch(profileProvider).highScores[spec.id] ?? r.score;
    return _card(context, [
      Text(
        target == null ? (_isBest ? 'New best!' : 'Run over') : (passed ? 'Goal reached!' : 'So close'),
        style: context.text.headlineMedium!.copyWith(
          color: passed && (_isBest || target != null) ? AppColors.mint : AppColors.text,
        ),
      ),
      const SizedBox(height: AppSpace.sm),
      Text('${r.score}', style: context.text.displaySmall!.copyWith(fontSize: 64, color: spec.color)),
      Text('Best $best', style: context.text.bodyMedium),
      const SizedBox(height: AppSpace.md),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          StatPill(
            icon: Icons.monetization_on_rounded,
            value: '+${r.coinsEarned}',
            color: AppColors.amber,
            semantic: 'Coins earned',
          ),
          StatPill(icon: Icons.bolt_rounded, value: '+${r.xpEarned} XP', color: AppColors.violet),
          if (r.questionsAnswered > 0)
            StatPill(
              icon: Icons.school_rounded,
              value: '${r.questionsCorrect}/${r.questionsAnswered}',
              color: AppColors.sky,
              semantic: 'Questions correct',
            ),
        ],
      ),
      const SizedBox(height: AppSpace.lg),
      ChunkyButton(label: 'Play again', icon: Icons.replay_rounded, color: spec.color, onPressed: _again),
      const SizedBox(height: AppSpace.md),
      ChunkyButton(label: 'Done', color: AppColors.surfaceHi, onPressed: () => Navigator.of(context).pop(r)),
    ]);
  }
}

class _PowerupToast extends StatelessWidget {
  const _PowerupToast(this.type);
  final PowerupType type;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.6),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: AppMotion.base,
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(999)),
        child: Text('${type.emoji}  ${type.label}!', style: context.text.titleLarge!.copyWith(color: AppColors.ink)),
      ),
    ),
  );
}

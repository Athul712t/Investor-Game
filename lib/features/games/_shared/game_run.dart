import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content_repo.dart';
import '../../../core/profile.dart';
import '../../../core/sfx.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../../domain/entities/question.dart';
import '../../../domain/game/game_types.dart';
import '../../content/question_view.dart';
import '../arcade_screen.dart' show todaysPick;
import 'arcade_game.dart';
import 'games_registry.dart';

enum _Phase { intro, playing, paused, revive, results }

/// One game flow: intro, HUD, pause, quiz chip, results. No Scaffold or navigation,
/// so Arcade and Story (via GameHostScreen) and the Reel share it.
///
/// Education never stops the run (docs/DESIGN.md, Arcade rules):
///  - a boost shows a quiz chip while the game keeps running,
///  - dying goes straight to results, where a second chance question is optional (not in the reel),
///  - explanations wait for the results screen.
class GameRun extends ConsumerStatefulWidget {
  const GameRun({
    super.key,
    required this.gameId,
    this.targetScore,
    this.reel = false,
    this.active = true,
    this.onFinished,
    this.onLeave,
    this.chips = true,
  });
  final String gameId;
  final int? targetScore; // set by Story Mode

  /// Reel card: one run, no second chance, no replay, best score always shown, engine built on Start.
  final bool reel;

  /// False: a static intro only, no engine and no sound.
  final bool active;

  /// Fires each time the run reaches the results screen.
  final void Function(GameResult result)? onFinished;

  /// "Back" and "Done" call it; null hides them.
  final VoidCallback? onLeave;

  /// False (Reel mode "Games only"): no quiz chip, boosts are ignored, no "What you learned".
  final bool chips;

  @override
  ConsumerState<GameRun> createState() => GameRunState();
}

class GameRunState extends ConsumerState<GameRun> {
  late final GameSpec spec = gameById(widget.gameId)!;
  ArcadeGame? _game; // null until needed: the reel builds it on Start
  ArcadeGame get game => _game!;
  var _phase = _Phase.intro;
  final _rng = Random();
  final _watch = Stopwatch();
  Question? _chip; // quiz chip on screen while playing
  Question? _reviveQuestion;
  PowerupType? _toast;
  bool _died = false, _reviveUsed = false, _isBest = false;
  int _paidCoins = 0, _paidXp = 0; // already added to the profile this run
  final _learned = <(Question, bool)>[]; // answered this run, shown on results
  GameResult? _result;
  int? _prevBest; // best before this run's first finish
  final _newLevels = <int>[]; // mastery levels paid during this run

  /// On the intro or results card, where back means leave rather than pause.
  bool get atRest => _phase == _Phase.intro || _phase == _Phase.results;

  @override
  void initState() {
    super.initState();
    if (!widget.reel) _newGame(); // standalone shows the paused canvas behind the intro
  }

  @override
  void didUpdateWidget(GameRun old) {
    super.didUpdateWidget(old);
    if (!widget.active) pause();
  }

  @override
  void dispose() {
    _game
      ?..onBoostRequested = null
      ..onGameOver = null
      ..pauseEngine();
    super.dispose();
  }

  void _newGame() {
    _game = spec.create(const GameConfig())
      ..onBoostRequested = _onBoost
      ..onGameOver = _onGameOver
      ..paused = true; // starts on the intro card
    _died = _reviveUsed = _isBest = false;
    _result = null;
    _paidCoins = _paidXp = 0;
    _prevBest = null;
    _newLevels.clear();
    _learned.clear();
    _chip = null;
    _watch.reset();
  }

  List<Question> get _quick => ref.read(contentProvider).value?.quickQuestions ?? const [];

  /// Two-button statements only: readable at a glance while playing.
  Question? _pickChip() {
    final pool = _quick.where((q) => q.type != QuestionType.mcq).toList();
    return pool.isEmpty ? null : pool[_rng.nextInt(pool.length)];
  }

  void _start() {
    if (_game == null) _newGame();
    setState(() => _phase = _Phase.playing);
    _watch.start();
    game.resumeEngine();
  }

  static const _headStartCost = 30;

  /// Today's pick pays double coins.
  bool get _doubleCoins => todaysPick(DateTime.now()).id == spec.id;

  /// Begin the run with a random power-up: free with a token, else for coins.
  void _headStart({bool token = false}) {
    if (_phase != _Phase.intro) return; // a second tap in the same frame
    if (_game == null) _newGame();
    final g = game;
    final c = ref.read(profileProvider.notifier);
    if (g.boosts.isEmpty) return;
    if (token) {
      if (ref.read(profileProvider).headStarts <= 0) return;
      c.mutate((p) => p.copyWith(headStarts: p.headStarts - 1));
    } else if (!c.spend(_headStartCost)) {
      return;
    }
    final p = g.boosts[_rng.nextInt(g.boosts.length)];
    _start();
    // A game built just now has not loaded its world yet.
    g.loaded.then((_) {
      if (mounted && _game == g) _grant(p);
    });
  }

  void _grant(PowerupType p) {
    game.applyPowerup(p);
    Sound.play(Sfx.powerup);
    Haptics.medium();
    setState(() => _toast = p);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void pause() {
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

  /// The game earned a boost: offer a quiz chip. The run keeps going.
  void _onBoost() {
    if (!widget.chips || _phase != _Phase.playing || _chip != null) return;
    final q = _pickChip();
    if (q != null) setState(() => _chip = q);
  }

  void _chipAnswered(bool correct) {
    ref.read(profileProvider.notifier).noteAnswer(_chip!, correct);
    _learned.add((_chip!, correct));
    if (correct && game.boosts.isNotEmpty && _phase == _Phase.playing) {
      _grant(game.boosts[_rng.nextInt(game.boosts.length)]);
    } else if (!correct) {
      Sound.play(Sfx.wrong);
    }
  }

  void _onGameOver() {
    _died = true;
    _finish();
  }

  void _finish() {
    _watch.stop();
    game.pauseEngine();
    final score = game.score.value;
    final correct = _learned.where((e) => e.$2).length;
    final r = GameResult(
      gameId: spec.id,
      score: score,
      durationMs: _watch.elapsedMilliseconds,
      coinsEarned: game.coins.value * (_doubleCoins ? 2 : 1),
      xpEarned: (score > 0 ? 10 : 0) + 5 * correct, // no base XP for ending an empty run
      questionsAnswered: _learned.length,
      questionsCorrect: correct,
    );
    // A run can reach results twice (second chance), so pay only what is new.
    final c = ref.read(profileProvider.notifier);
    _prevBest ??= ref.read(profileProvider).highScores[spec.id];
    final again = _result != null; // finishing again after a second chance
    final best = c.recordGame(
      GameResult(
        gameId: r.gameId,
        score: r.score,
        durationMs: r.durationMs,
        coinsEarned: r.coinsEarned - _paidCoins,
        xpEarned: r.xpEarned - _paidXp,
      ),
      again: again,
      bestCounted: _isBest,
    );
    _isBest = best || (again && _isBest);
    _paidCoins = r.coinsEarned;
    _paidXp = r.xpEarned;
    final paid = payMastery(c, ref.read(profileProvider).masteryClaimed, spec, score);
    if (paid.isNotEmpty) _newLevels.addAll(paid);
    final target = widget.targetScore;
    Sound.play(_isBest || (target != null && score >= target) ? Sfx.win : Sfx.lose);
    setState(() {
      _chip = null;
      _result = r;
      _phase = _Phase.results;
    });
    widget.onFinished?.call(r);
  }

  bool get _canRevive => !widget.reel && _died && !_reviveUsed && _quick.isNotEmpty;

  void _askRevive() => setState(() {
    _reviveQuestion = _quick[_rng.nextInt(_quick.length)];
    _phase = _Phase.revive;
  });

  void _reviveAnswered(bool correct) {
    ref.read(profileProvider.notifier).noteAnswer(_reviveQuestion!, correct);
    _reviveUsed = true;
    _learned.add((_reviveQuestion!, correct));
    if (!correct) return _finish();
    _died = false;
    setState(() => _phase = _Phase.playing);
    _watch.start();
    game.continueAfterRevive();
  }

  void _again() => setState(() {
    _newGame();
    _phase = _Phase.intro;
  });

  int? get _best => ref.watch(profileProvider.select((p) => p.highScores[spec.id]));

  @override
  Widget build(BuildContext context) {
    ref.watch(contentProvider); // keep questions loaded for the chip and the second chance
    final g = widget.active ? _game : null;
    return Material(
      color: AppColors.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The canvas has no semantics of its own.
          if (g != null)
            Semantics(
              label: '${spec.title}. ${spec.howTo}',
              child: GameWidget(key: ObjectKey(g), game: g),
            ),
          if (_phase == _Phase.playing || _phase == _Phase.paused) SafeArea(child: _hud(context)),
          if (_toast != null) SafeArea(child: _PowerupToast(_toast!)),
          if (_chip != null && _phase == _Phase.playing)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _QuizChip(
                  key: ValueKey(_chip!.id),
                  question: _chip!,
                  onAnswered: _chipAnswered,
                  onClosed: () => setState(() => _chip = null),
                ),
              ),
            ),
          if (_phase != _Phase.playing) _overlay(context),
        ],
      ),
    );
  }

  Widget _hud(BuildContext context) {
    final best = widget.reel ? _best ?? 0 : null;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: pause,
            label: 'Pause',
            builder: (_, down) => Container(
              width: 48,
              height: 48,
              decoration: pieceDecoration(radius: 14, depth: down ? 0 : 3),
              child: const Icon(Icons.pause_rounded, color: AppColors.ink),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: game.score,
              builder: (_, v, _) => Column(
                children: [
                  OutlinedText('$v', textAlign: TextAlign.center),
                  if (best != null)
                    OutlinedText(
                      'Best ${max(best, v)}',
                      style: context.text.titleMedium,
                      fill: AppColors.paper,
                      stroke: 3,
                    ),
                  if (widget.targetScore != null)
                    OutlinedText(
                      'Goal ${widget.targetScore}',
                      style: context.text.titleLarge,
                      fill: AppColors.yellow,
                      stroke: 4,
                    ),
                ],
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: game.coins,
            builder: (_, v, _) =>
                StatPill(icon: Icons.currency_rupee_rounded, value: '$v', color: AppColors.yellow, semantic: 'Coins'),
          ),
        ],
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final Widget card = switch (_phase) {
      _Phase.intro => _intro(context),
      _Phase.paused => _card(context, [
        Text('Paused', style: context.text.headlineMedium),
        const SizedBox(height: AppSpace.lg),
        ChunkyButton(label: 'Resume', icon: Icons.play_arrow_rounded, onPressed: _resume),
        const SizedBox(height: AppSpace.sm),
        ChunkyButton(label: 'End run', color: AppColors.card, onPressed: _finish),
      ]),
      _Phase.revive => _card(context, [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_rounded, color: AppColors.red),
            const SizedBox(width: 8),
            Text('Second chance', style: context.text.titleLarge),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        QuestionView(question: _reviveQuestion!, onAnswered: _reviveAnswered, compact: true),
      ]),
      _Phase.results => _results(context),
      _Phase.playing => const SizedBox.shrink(),
    };
    // Opaque so taps and swipes beside the card never reach the game underneath.
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: AppColors.ink.withValues(alpha: 0.6),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: PopIn(key: ValueKey(_phase), child: card),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) => Panel(
    padding: const EdgeInsets.all(AppSpace.lg),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );

  Widget _intro(BuildContext context) {
    final on = widget.active;
    final best = _best;
    return _card(context, [
      Badge3D(emoji: spec.emoji, color: spec.color, size: 76),
      const SizedBox(height: AppSpace.md),
      Text(spec.title, style: context.text.headlineMedium, textAlign: TextAlign.center),
      const SizedBox(height: AppSpace.xs),
      Text(spec.howTo, style: context.text.bodyLarge, textAlign: TextAlign.center),
      if (widget.reel) ...[
        const SizedBox(height: AppSpace.sm),
        Text(best == null ? 'No best yet' : 'Best $best', style: context.text.titleMedium),
      ],
      if (_doubleCoins) ...[
        const SizedBox(height: AppSpace.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: pieceDecoration(fill: AppColors.yellow, radius: 999, depth: 0),
          child: Text('2x coins today', style: context.text.labelMedium!.copyWith(color: AppColors.ink)),
        ),
      ],
      if (widget.targetScore != null) ...[
        const SizedBox(height: AppSpace.sm),
        Text('Reach ${widget.targetScore} to pass', style: context.text.titleMedium),
      ],
      const SizedBox(height: AppSpace.lg),
      ChunkyButton(label: 'Start', icon: Icons.play_arrow_rounded, color: spec.color, onPressed: on ? _start : null),
      if (on && ref.watch(profileProvider.select((p) => p.headStarts)) > 0) ...[
        const SizedBox(height: AppSpace.sm),
        ChunkyButton(
          label: 'Head start (${ref.watch(profileProvider.select((p) => p.headStarts))} left)',
          icon: Icons.bolt_rounded,
          color: AppColors.yellow,
          onPressed: () => _headStart(token: true),
        ),
      ] else if (on && ref.watch(profileProvider.select((p) => p.coins)) >= _headStartCost) ...[
        const SizedBox(height: AppSpace.sm),
        ChunkyButton(
          label: 'Head start  ·  $_headStartCost coins',
          icon: Icons.bolt_rounded,
          color: AppColors.yellow,
          onPressed: _headStart,
        ),
      ],
      if (widget.onLeave != null && !widget.reel) ...[
        const SizedBox(height: AppSpace.sm),
        ChunkyButton(label: 'Back', color: AppColors.card, onPressed: widget.onLeave),
      ],
    ]);
  }

  /// Medal for the highest level just paid, near-miss line, and progress toward the next level.
  List<Widget> _masteryLines(BuildContext context, GameResult r) {
    final claimed = ref.watch(profileProvider.select((p) => p.masteryClaimed));
    final prev = _prevBest;
    final lines = <Widget>[];
    if (_newLevels.isNotEmpty) {
      final l = _newLevels.last;
      lines.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MedalPip(color: masteryColors[l - 1], size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${masteryNames[l - 1]} reached! +${masteryCoins[l - 1]} coins and a ${masteryChests[l - 1]} chest',
                style: context.text.titleSmall,
              ),
            ),
          ],
        ),
      );
    } else if (prev != null && r.score < prev && r.score * 10 >= prev * 7) {
      lines.add(Text('${prev - r.score} away from your best', style: context.text.titleSmall));
    }
    final next = [
      for (var l = 1; l <= 3; l++)
        if (!claimed.contains('${spec.id}:$l')) l,
    ].firstOrNull;
    final text = next == null
        ? 'Gold mastered'
        : 'Next: ${masteryNames[next - 1]} at ${spec.levels[next - 1]}, ${max(0, spec.levels[next - 1] - r.score)} to go';
    lines.add(Text(text, style: context.text.bodyMedium, textAlign: TextAlign.center));
    return [
      for (final w in lines)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm),
          child: w,
        ),
    ];
  }

  Widget _results(BuildContext context) {
    final r = _result!;
    final target = widget.targetScore;
    final passed = target == null || r.score >= target;
    final best = ref.watch(profileProvider).highScores[spec.id] ?? r.score;
    return _card(context, [
      Text(
        target == null ? (_isBest ? 'New best!' : 'Run over') : (passed ? 'Goal reached!' : 'So close'),
        style: context.text.headlineMedium,
      ),
      CountUp(value: r.score, style: context.text.displaySmall!.copyWith(fontSize: 72)),
      Text('Best $best', style: widget.reel ? context.text.titleMedium : context.text.bodyMedium),
      ..._masteryLines(context, r),
      const SizedBox(height: AppSpace.md),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          StatPill(
            icon: Icons.currency_rupee_rounded,
            value: '+${r.coinsEarned}${_doubleCoins ? ' (2x)' : ''}',
            color: AppColors.yellow,
            semantic: 'Coins earned',
          ),
          StatPill(icon: Icons.bolt_rounded, value: '+${r.xpEarned} XP', color: AppColors.blue),
        ],
      ),
      if (!widget.reel) ...[
        const SizedBox(height: AppSpace.lg),
        if (_canRevive) ...[
          Panel(
            accent: AppColors.red,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: AppColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Second chance: answer one question to keep this run going.',
                        style: context.text.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                ChunkyButton(label: 'Answer and continue', color: AppColors.red, onPressed: _askRevive),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],
        ChunkyButton(label: 'Play again', icon: Icons.replay_rounded, color: spec.color, onPressed: _again),
        if (widget.onLeave != null) ...[
          const SizedBox(height: AppSpace.sm),
          ChunkyButton(label: 'Done', color: AppColors.card, onPressed: widget.onLeave),
        ],
      ],
      if (widget.chips && _learned.isNotEmpty) ...[
        const SizedBox(height: AppSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('What you learned this run', style: context.text.titleLarge),
        ),
        for (final (q, ok) in _learned)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: ok ? AppColors.green : AppColors.red,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(q.explanation, style: context.text.bodyMedium)),
              ],
            ),
          ),
      ],
      if (widget.reel) ...[
        const SizedBox(height: AppSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.inkDim),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Swipe up for the next card',
                style: context.text.bodyMedium!.copyWith(color: AppColors.inkDim),
              ),
            ),
          ],
        ),
      ],
    ]);
  }
}

/// A true/false or myth/fact statement shown over the running game.
/// Closes itself after an answer or when its timer runs out.
class _QuizChip extends StatefulWidget {
  const _QuizChip({super.key, required this.question, required this.onAnswered, required this.onClosed});
  final Question question;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onClosed;

  @override
  State<_QuizChip> createState() => _QuizChipState();
}

class _QuizChipState extends State<_QuizChip> with SingleTickerProviderStateMixin {
  late final _timer = AnimationController(vsync: this, duration: const Duration(seconds: 10))
    ..forward()
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && _correct == null) widget.onClosed();
    });
  bool? _correct;

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _answer(int index) {
    if (_correct != null) return;
    final p = widget.question.payload;
    final right = widget.question.type == QuestionType.trueFalse
        ? (p['answer'] == true ? 0 : 1)
        : (p['answer'] == 'myth' ? 0 : 1);
    setState(() => _correct = index == right);
    widget.onAnswered(_correct!);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) widget.onClosed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final labels = q.type == QuestionType.trueFalse ? const ['True', 'False'] : const ['Myth', 'Fact'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: PopIn(
          child: Panel(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.orange, size: 20),
                    Text('Quick quiz for a power-up', style: context.text.labelSmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _timer,
                        builder: (_, _) => FatProgress(value: 1 - _timer.value, color: AppColors.orange, height: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  q.payload['statement']! as String,
                  style: context.text.titleSmall,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (_correct == null)
                  Row(
                    children: [
                      for (var i = 0; i < 2; i++) ...[
                        if (i == 1) const SizedBox(width: 8),
                        Expanded(
                          child: ChunkyButton(
                            label: labels[i],
                            color: i == 0 ? AppColors.yellow : AppColors.teal,
                            onPressed: () => _answer(i),
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    _correct! ? 'Correct! Power-up granted' : 'Not this time. See why after the run',
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium!.copyWith(color: _correct! ? AppColors.green : AppColors.red),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerupToast extends StatelessWidget {
  const _PowerupToast(this.type);
  final PowerupType type;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.55),
    child: PopIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: pieceDecoration(fill: AppColors.yellow, radius: 999, depth: 4),
        child: Text('${type.emoji}  ${type.label}!', style: context.text.titleLarge),
      ),
    ),
  );
}

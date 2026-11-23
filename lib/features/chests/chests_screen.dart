import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/game/game_types.dart';
import 'chest_art.dart';
import 'chest_logic.dart';

/// Your unopened chests, their odds, and the opening moment. [rng] is injectable so tests can seed it.
class ChestsScreen extends ConsumerStatefulWidget {
  const ChestsScreen({super.key, this.rng});
  final Random? rng;

  @override
  ConsumerState<ChestsScreen> createState() => _ChestsScreenState();
}

class _ChestsScreenState extends ConsumerState<ChestsScreen> {
  late final Random _rng = widget.rng ?? Random();
  ({ChestType type, ChestReward reward})? _opening;

  /// The chest is removed and the reward saved here, in one step; the animation after it is only the show.
  void _open(ChestType type) {
    if (_opening != null) return; // double tap
    final lessons = ref.read(contentProvider).value?.lessons ?? const [];
    final reward = openChest(
      ref.read(profileProvider),
      ref.read(profileProvider.notifier),
      type,
      _rng,
      lessonIds: [for (final l in lessons) l.id],
    );
    if (reward != null) setState(() => _opening = (type: type, reward: reward));
  }

  @override
  Widget build(BuildContext context) {
    final chests = ref.watch(profileProvider.select((p) => p.chests));
    ref.watch(contentProvider); // keep the lessons loading for study boosts
    final stage = _opening;
    return AppScaffold(
      appBar: AppBar(title: const Text('Chests')),
      body: Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight),
        child: stage != null
            ? _OpenStage(type: stage.type, reward: stage.reward, onDone: () => setState(() => _opening = null))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (chests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Panel(
                          accent: AppColors.yellow,
                          child: Text(
                            'No chests yet. Finish all three daily quests, hit a streak milestone or level up a '
                            'game mastery to earn one. Here is what each kind can hold.',
                            style: context.text.bodyLarge,
                          ),
                        ),
                      ),
                    for (final (i, t) in ChestType.values.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: PopIn.at(
                          i,
                          _TypeCard(type: t, count: chests.where((c) => c == t.name).length, onOpen: () => _open(t)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

String _name(ChestType t) => '${t.name[0].toUpperCase()}${t.name.substring(1)} chest';

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type, required this.count, required this.onOpen});
  final ChestType type;
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = chestAccent(type);
    return Panel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                label: '$count ${_name(type)}',
                child: SizedBox(
                  width: 84,
                  height: 66,
                  child: CustomPaint(painter: ChestPicto(type, stack: count)),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name(type), style: context.text.titleLarge),
                    Text(count == 0 ? 'None yet' : 'x$count to open', style: context.text.labelLarge),
                  ],
                ),
              ),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(height: AppSpace.sm),
            ChunkyButton(
              key: Key('open-${type.name}'),
              label: 'Open',
              icon: Icons.lock_open_rounded,
              onPressed: onOpen,
            ),
          ],
          const SizedBox(height: AppSpace.md),
          _OddsTable(type: type),
        ],
      ),
    );
  }
}

class _OddsTable extends StatelessWidget {
  const _OddsTable({required this.type});
  final ChestType type;

  @override
  Widget build(BuildContext context) {
    final rows = chestOdds[type]!;
    return Container(
      key: Key('odds-${type.name}'),
      padding: const EdgeInsets.all(AppSpace.sm + 2),
      decoration: pieceDecoration(fill: AppColors.card, radius: 12, depth: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What can be inside', style: context.text.labelLarge),
          const SizedBox(height: AppSpace.xs),
          for (final o in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(o.label, style: context.text.bodyMedium)),
                  const SizedBox(width: AppSpace.sm),
                  Text('${o.percent}%', style: context.text.labelLarge),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'One reward per chest. A study boost adds 3 mastery credits to one lesson.'
            '${rows.any((o) => o.kind == RewardKind.freeze) ? ' You can hold one streak freeze; if you already have one you get coins.' : ''}',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---- the opening moment ----

class _OpenStage extends ConsumerStatefulWidget {
  const _OpenStage({required this.type, required this.reward, required this.onDone});
  final ChestType type;
  final ChestReward reward;
  final VoidCallback onDone;

  @override
  ConsumerState<_OpenStage> createState() => _OpenStageState();
}

class _OpenStageState extends ConsumerState<_OpenStage> with SingleTickerProviderStateMixin {
  static const _lidAt = 0.12, _revealAt = 0.62;
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..addListener(_cue);
  bool _lidDone = false, _revealed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.reduceMotion ? _c.value = 1 : _c.forward();
    });
  }

  void _cue() {
    final t = _c.value;
    if (!_lidDone && t >= _lidAt) {
      _lidDone = true;
      Sound.play(Sfx.levelUp);
      Haptics.heavy();
    }
    if (!_revealed && t >= _revealAt) {
      _revealed = true;
      if (widget.reward.kind == RewardKind.coins) Sound.play(Sfx.coin);
      Haptics.medium();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpace.md),
    child: Column(
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _ChestStage(type: widget.type, reward: widget.reward, t: _c.value),
        ),
        const SizedBox(height: AppSpace.md),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _c.value >= _revealAt
              ? PopIn(
                  child: _RevealCard(reward: widget.reward, type: widget.type, onDone: widget.onDone),
                )
              : const SizedBox(height: 220),
        ),
      ],
    ),
  );
}

class _ChestStage extends StatelessWidget {
  const _ChestStage({required this.type, required this.reward, required this.t});
  final ChestType type;
  final ChestReward reward;
  final double t;

  static const _size = Size(300, 220), _chest = Size(140, 120);

  @override
  Widget build(BuildContext context) {
    // Lid swings up past upright (spring overshoot), and stays open.
    final lid = Curves.easeOutBack.transform(((t - _OpenStageState._lidAt) / 0.2).clamp(0.0, 1.0));
    final angle = lid * 2.2;
    final shake = t < _OpenStageState._lidAt ? sin(t * 140) * 3 * (t / _OpenStageState._lidAt) : 0.0;
    final pop = ((t - 0.3) / 0.3).clamp(0.0, 1.0);
    final left = (_size.width - _chest.width) / 2 + shake;
    final top = _size.height - _chest.height - 12;
    final lift = Curves.easeOut.transform(pop) * 104;
    return Semantics(
      label: '${_name(type)}, opening',
      child: SizedBox.fromSize(
        size: _size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left + 6,
              right: _size.width - left - _chest.width + 6,
              top: _size.height - 20,
              height: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: CustomPaint(
                size: _chest,
                painter: ChestBodyPainter(type, open: angle > 0.05),
              ),
            ),
            // Lid hinged on its back edge: the front swings toward the viewer and up over the hinge.
            Positioned(
              left: left - 4,
              top: top - 2,
              child: Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.004)
                  ..rotateX(-angle),
                child: CustomPaint(
                  size: const Size(148, 46),
                  painter: ChestLidPainter(type, inside: angle > pi / 2),
                ),
              ),
            ),
            if (pop > 0)
              Positioned(
                left: _size.width / 2 - 32,
                top: top + 8 - lift,
                child: Transform.scale(
                  scale: Curves.elasticOut.transform(pop),
                  child: _RewardIcon(reward: reward, size: 64),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

(IconData, Color) _look(RewardKind k) => switch (k) {
  RewardKind.coins => (Icons.paid_rounded, AppColors.yellow),
  RewardKind.headStart => (Icons.rocket_launch_rounded, AppColors.green),
  RewardKind.studyBoost => (Icons.menu_book_rounded, AppColors.blue),
  RewardKind.powerup => (Icons.bolt_rounded, AppColors.orange),
  RewardKind.freeze => (Icons.ac_unit_rounded, AppColors.teal),
};

class _RewardIcon extends StatelessWidget {
  const _RewardIcon({required this.reward, required this.size});
  final ChestReward reward;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (reward.kind == RewardKind.coins) return Coin3D(size: size);
    final (icon, color) = _look(reward.kind);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: pieceDecoration(fill: color, radius: size / 2, depth: 3),
        child: Icon(icon, size: size * 0.56, color: AppColors.on(color)),
      ),
    );
  }
}

class _RevealCard extends ConsumerWidget {
  const _RevealCard({required this.reward, required this.type, required this.onDone});
  final ChestReward reward;
  final ChestType type;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reward;
    final lesson = r.kind == RewardKind.studyBoost ? ref.read(contentProvider).value?.lesson(r.lessonId) : null;
    final (title, sub) = switch (r.kind) {
      RewardKind.coins => ('+${r.coins} coins', 'Added to your wallet.'),
      RewardKind.headStart => (
        '+${r.count} head-start token${r.count > 1 ? 's' : ''}',
        'Use one free at a game\'s intro.',
      ),
      RewardKind.studyBoost => (
        'Study boost',
        '+${boostCredits * r.count} mastery credits for ${lesson?.title ?? r.lessonId}.',
      ),
      RewardKind.powerup => (r.powerups.map((p) => p.label).join(' and '), 'Added to your power-ups.'),
      RewardKind.freeze => ('Streak freeze', 'Protects your streak on one missed day.'),
    };
    return Panel(
      accent: chestAccent(type),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('You got', textAlign: TextAlign.center, style: context.text.bodyMedium),
          Text(title, key: const Key('reveal-title'), textAlign: TextAlign.center, style: context.text.headlineSmall),
          const SizedBox(height: AppSpace.xs),
          Text(sub, textAlign: TextAlign.center, style: context.text.bodyMedium),
          const SizedBox(height: AppSpace.md),
          ChunkyButton(key: const Key('awesome'), label: 'Awesome', onPressed: onDone),
        ],
      ),
    );
  }
}

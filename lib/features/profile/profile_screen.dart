import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud.dart';
import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../games/_shared/games_registry.dart';
import '../home_hub/pictograms.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final cloud = ref.watch(cloudProvider);
    final ladder = [...games]..sort((a, b) => (p.highScores[b.id] ?? 0).compareTo(p.highScores[a.id] ?? 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xl),
      children: [
        // Player card.
        Container(
          margin: const EdgeInsets.only(bottom: AppSpace.depth),
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: pieceDecoration(fill: AppColors.blue),
          child: Row(
            children: [
              LevelMedal(level: p.level, size: 76),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title.toUpperCase(),
                      style: context.text.labelSmall!.copyWith(color: AppColors.card, letterSpacing: 1.5),
                    ),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall!.copyWith(color: AppColors.card),
                    ),
                    const SizedBox(height: 8),
                    FatProgress(value: p.levelProgress, color: AppColors.yellow),
                    const SizedBox(height: 2),
                    CountUp(
                      value: p.xp % Profile.xpPerLevel,
                      suffix: '/${Profile.xpPerLevel} XP to level ${p.level + 1}',
                      style: context.text.labelSmall!.copyWith(color: AppColors.card),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Pressable(
                label: 'Edit name',
                onTap: () => _rename(context, ref, p.name),
                builder: (_, down) => Container(
                  width: 48,
                  height: 48,
                  transform: Matrix4.translationValues(0, down ? 3 : 0, 0),
                  decoration: pieceDecoration(fill: AppColors.yellow, radius: 999, depth: down ? 0 : 3),
                  child: const Icon(Icons.edit_rounded, color: AppColors.ink, size: 22),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Stat(
                  icon: const Pictogram(Pic.flame, size: 30, color: AppColors.red),
                  value: p.streak,
                  label: 'Day streak',
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _Stat(icon: const Coin3D(size: 30), value: p.coins, label: 'Coins', color: AppColors.yellow),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _Stat(
                  icon: const Pictogram(Pic.learn, size: 30, color: AppColors.yellow),
                  value: p.completedLessons.length,
                  label: 'Lessons',
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text('High scores', style: context.text.titleLarge),
        const SizedBox(height: AppSpace.sm),
        Container(
          margin: const EdgeInsets.only(bottom: AppSpace.depth),
          decoration: pieceDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, g) in ladder.indexed)
                _Rung(rank: i + 1, game: g, score: p.highScores[g.id] ?? 0, last: i == ladder.length - 1),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        const _SoundToggle(),
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            Icon(
              cloud.state == CloudState.synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              size: 18,
              color: cloud.state == CloudState.synced ? AppColors.green : AppColors.inkDim,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(switch (cloud.state) {
                CloudState.synced => 'Progress backed up',
                CloudState.offline => 'Offline. Progress is saved on this device',
                CloudState.idle => 'Progress is saved on this device',
              }, style: context.text.bodySmall),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String current) async {
    final c = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: c, autofocus: true, maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null) ref.read(profileProvider.notifier).rename(name);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, required this.color});
  final Widget icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    excludeSemantics: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: AppSpace.depth),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: pieceDecoration(fill: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUp(
              value: value,
              style: context.text.headlineMedium!.copyWith(color: AppColors.on(color)),
            ),
          ),
          Text(label, style: context.text.labelSmall!.copyWith(color: AppColors.on(color))),
        ],
      ),
    ),
  );
}

/// One step of the high-score ladder. The top rung is the gold one.
class _Rung extends StatelessWidget {
  const _Rung({required this.rank, required this.game, required this.score, required this.last});
  final int rank;
  final GameSpec game;
  final int score;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final top = rank == 1 && score > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: top ? AppColors.tint(AppColors.yellow, 0.5) : AppColors.card,
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.track, width: 2)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: pieceDecoration(fill: top ? AppColors.yellow : AppColors.paperDeep, radius: 999, depth: 0),
            child: Text('$rank', style: context.text.titleLarge!.copyWith(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Text(game.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(child: Text(game.title, style: context.text.titleMedium)),
          Text(
            score == 0 ? '-' : '$score',
            style: context.text.titleLarge!.copyWith(color: score == 0 ? AppColors.inkDim : AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _SoundToggle extends StatefulWidget {
  const _SoundToggle();

  @override
  State<_SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends State<_SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final on = !Sound.muted;
    return Semantics(
      toggled: on,
      label: 'Sound',
      excludeSemantics: true,
      onTap: _flip,
      child: Pressable(
        onTap: _flip,
        builder: (_, _) => Container(
          margin: const EdgeInsets.only(bottom: AppSpace.depth),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 12),
          decoration: pieceDecoration(),
          child: Row(
            children: [
              Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: AppColors.ink),
              const SizedBox(width: 10),
              Expanded(child: Text('Sound', style: context.text.titleMedium)),
              AnimatedContainer(
                duration: AppMotion.fast,
                width: 58,
                height: 32,
                padding: const EdgeInsets.all(3),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                decoration: pieceDecoration(fill: on ? AppColors.green : AppColors.track, radius: 999, depth: 0),
                child: Container(width: 22, height: 22, decoration: pieceDecoration(radius: 999, depth: 0)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _flip() => setState(() => Sound.setMuted(!Sound.muted));
}

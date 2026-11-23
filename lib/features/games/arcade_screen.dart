import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../home_hub/board_tile.dart';
import '_shared/games_registry.dart';

/// The game featured on [day]: rotates through the shelf, the same for everyone that date.
GameSpec todaysPick(DateTime day) =>
    games[DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay %
        games.length];

/// Play tab: the arcade shelf. Pure game, no lessons required.
class ArcadeScreen extends ConsumerWidget {
  const ArcadeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(profileProvider.select((p) => p.highScores));
    final claimed = ref.watch(profileProvider.select((p) => p.masteryClaimed));
    final pick = todaysPick(DateTime.now());
    void play(GameSpec g) => context.push('/play/${g.id}');
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xl),
      children: [
        Text('Arcade', style: context.text.headlineMedium),
        Text('Just play. Answer a question mid-run for a power-up.', style: context.text.bodyMedium),
        const SizedBox(height: AppSpace.md),
        PopIn.at(0, _Featured(g: pick, best: scores[pick.id] ?? 0, claimed: claimed, onTap: () => play(pick))),
        const SizedBox(height: AppSpace.lg),
        Text('All games', style: context.text.titleLarge),
        const SizedBox(height: AppSpace.sm),
        for (var r = 0; r < games.length; r += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (k, g) in games.skip(r).take(2).indexed) ...[
                    if (k > 0) const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: PopIn.at(
                        r + k + 1,
                        _Cartridge(g: g, best: scores[g.id] ?? 0, claimed: claimed, onTap: () => play(g)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Cartridge ridges along the top edge: what makes a tile read as a game cart.
class _Ridges extends StatelessWidget {
  const _Ridges();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 5; i++) ...[
        if (i > 0) const SizedBox(width: 5),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ],
    ],
  );
}

class _BestLabel extends StatelessWidget {
  const _BestLabel(this.g, this.best, this.claimed);
  final GameSpec g;
  final int best;
  final Set<String> claimed;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: pieceDecoration(radius: 999, depth: 0),
        child: Text(best == 0 ? 'New' : 'Best $best', style: context.text.labelSmall!.copyWith(color: AppColors.ink)),
      ),
      Semantics(
        label:
            'Mastery ${[for (var l = 1; l <= 3; l++)
              if (claimed.contains('${g.id}:$l')) l].length} of 3',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var l = 1; l <= 3; l++) ...[
              if (l > 1) const SizedBox(width: 3),
              MedalPip(color: claimed.contains('${g.id}:$l') ? masteryColors[l - 1] : null),
            ],
          ],
        ),
      ),
    ],
  );
}

class _Cartridge extends StatelessWidget {
  const _Cartridge({required this.g, required this.best, required this.claimed, required this.onTap});
  final GameSpec g;
  final int best;
  final Set<String> claimed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BoardTile(
    fill: g.color,
    onTap: onTap,
    label: '${g.title}. ${best == 0 ? 'Not played yet' : 'Best $best'}',
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Ridges(),
        const SizedBox(height: 10),
        Text(g.emoji, style: const TextStyle(fontSize: 44, height: 1.1)),
        const SizedBox(height: 4),
        Text(g.title, style: context.text.titleLarge!.copyWith(color: AppColors.on(g.color))),
        const Spacer(),
        const SizedBox(height: 8),
        _BestLabel(g, best, claimed),
      ],
    ),
  );
}

class _Featured extends StatelessWidget {
  const _Featured({required this.g, required this.best, required this.claimed, required this.onTap});
  final GameSpec g;
  final int best;
  final Set<String> claimed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.on(g.color);
    return BoardTile(
      fill: g.color,
      onTap: onTap,
      label: "Today's pick: ${g.title}. ${g.tagline}",
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 12, AppSpace.md, AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Ridges(),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: pieceDecoration(radius: 16, depth: 4),
                child: Text(g.emoji, style: const TextStyle(fontSize: 56, height: 1.1)),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: pieceDecoration(fill: AppColors.ink, radius: 999, depth: 0),
                      child: Text(
                        "TODAY'S PICK",
                        style: context.text.labelSmall!.copyWith(color: AppColors.yellow, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(g.title, style: context.text.headlineMedium!.copyWith(color: fg)),
                    Text(g.tagline, style: context.text.bodyMedium!.copyWith(color: fg)),
                    const SizedBox(height: 6),
                    _BestLabel(g, best, claimed),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

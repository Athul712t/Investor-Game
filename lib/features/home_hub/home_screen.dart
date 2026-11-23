import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'board_tile.dart';
import 'daily_card.dart';
import 'loop_section.dart';
import 'pictograms.dart';
import 'shell.dart';
import 'town.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    void tab(int i) => ref.read(tabProvider.notifier).go(i);
    final onTeal = AppColors.on(AppColors.teal);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xl),
      children: [
        _Header(p: p),
        const SizedBox(height: AppSpace.lg),
        _TownHero(p: p),
        const SizedBox(height: AppSpace.lg),
        Text('Choose your mode', style: context.text.titleLarge),
        const SizedBox(height: AppSpace.sm),
        PopIn.at(1, const _ReelTile()),
        const SizedBox(height: AppSpace.sm),
        PopIn.at(
          2,
          BoardTile(
            fill: AppColors.teal,
            onTap: () => context.push('/story'),
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STORY', style: context.text.labelSmall!.copyWith(color: onTeal, letterSpacing: 1.5)),
                          Text('Story Mode', style: context.text.headlineMedium!.copyWith(color: onTeal)),
                          const SizedBox(height: 2),
                          Text(
                            'From pocket money to portfolio. Learn, play, unlock chapters.',
                            style: context.text.bodyMedium!.copyWith(color: onTeal),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    const Pictogram(Pic.story, size: 92),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                ChunkyButton(
                  label: 'Continue story',
                  color: AppColors.yellow,
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => context.push('/story'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PopIn.at(
                  3,
                  _MiniMode(
                    pic: Pic.arcade,
                    picColor: AppColors.blue,
                    color: AppColors.yellow,
                    title: 'Arcade',
                    body: 'Pure game',
                    onTap: () => tab(2),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: PopIn.at(
                  4,
                  _MiniMode(
                    pic: Pic.learn,
                    picColor: AppColors.red,
                    color: AppColors.blue,
                    title: 'Learn',
                    body: 'Pure knowledge',
                    onTap: () => tab(1),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        PopIn.at(5, const DailyCard()),
        const SizedBox(height: AppSpace.lg),
        const LoopSection(),
        const SizedBox(height: AppSpace.lg),
        Text(
          'For education only. Not investment advice.\nMutual fund investments are subject to market risks.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.p});
  final Profile p;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LevelMedal(level: p.level, size: 58),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.headlineSmall),
            Text(p.title, style: context.text.labelSmall!.copyWith(color: AppColors.blue)),
            const SizedBox(height: 6),
            FatProgress(value: p.levelProgress, color: AppColors.blue, height: 14),
            const SizedBox(height: 2),
            CountUp(
              value: p.xp % Profile.xpPerLevel,
              suffix: '/${Profile.xpPerLevel} XP',
              style: context.text.labelSmall!.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Pill(
            semantic: 'Day streak ${p.streak}',
            icon: const Pictogram(Pic.flame, size: 22, color: AppColors.orange),
            value: p.streak,
          ),
          const SizedBox(height: 8),
          _Pill(semantic: 'Coins ${p.coins}', icon: const Coin3D(size: 22), value: p.coins),
        ],
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.semantic, required this.icon, required this.value});
  final String semantic;
  final Widget icon;
  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semantic,
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 10, 3),
      decoration: pieceDecoration(radius: 999, depth: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          CountUp(value: value, style: context.text.titleLarge!.copyWith(fontSize: 16)),
        ],
      ),
    ),
  );
}

class _TownHero extends StatelessWidget {
  const _TownHero({required this.p});
  final Profile p;

  @override
  Widget build(BuildContext context) {
    final plan = TownPlan.of(p);
    return Tilt3D(
      maxDegrees: 5,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.depth),
        decoration: pieceDecoration(fill: AppColors.tint(AppColors.blue, 0.8)),
        child: Stack(
          children: [
            SizedBox(
              height: (MediaQuery.sizeOf(context).width * 0.66).clamp(230.0, 300.0),
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.outline),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpace.radius - AppSpace.outline),
                  child: PortfolioTown(plan: plan),
                ),
              ),
            ),
            Positioned(
              left: AppSpace.md,
              top: 12,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Portfolio Town', style: context.text.titleLarge),
                    Text(
                      plan.buildings == 0 ? 'Empty plot' : '${plan.buildings}/${TownPlan.lots.length} built',
                      style: context.text.labelSmall!.copyWith(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelTile extends StatelessWidget {
  const _ReelTile();

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.on(AppColors.orange);
    return BoardTile(
      fill: AppColors.orange,
      onTap: () => context.push('/reel'),
      label: 'Reel. Play, read, learn. Keep scrolling.',
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NONSTOP', style: context.text.labelSmall!.copyWith(color: fg, letterSpacing: 1.5)),
                Text('Reel', style: context.text.headlineMedium!.copyWith(color: fg)),
                const SizedBox(height: 2),
                Text('Play, read, learn. Keep scrolling.', style: context.text.bodyMedium!.copyWith(color: fg)),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          const Pictogram(Pic.reel, size: 92),
        ],
      ),
    );
  }
}

class _MiniMode extends StatelessWidget {
  const _MiniMode({
    required this.pic,
    required this.picColor,
    required this.color,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final Pic pic;
  final Color picColor, color;
  final String title, body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.on(color);
    return BoardTile(
      fill: color,
      onTap: onTap,
      label: '$title. $body',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pictogram(pic, size: 56, color: picColor),
          const SizedBox(height: AppSpace.sm),
          Text(title, style: context.text.headlineSmall!.copyWith(color: fg)),
          Text(body, style: context.text.bodyMedium!.copyWith(color: fg)),
        ],
      ),
    );
  }
}

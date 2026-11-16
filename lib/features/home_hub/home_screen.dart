import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'daily_card.dart';
import 'shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    void tab(int i) => ref.read(tabProvider.notifier).go(i);
    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hi, ${p.name}', style: context.text.headlineMedium),
                  Text('Ready to grow today?', style: context.text.bodyMedium),
                ],
              ),
            ),
            StatPill(
              icon: Icons.local_fire_department_rounded,
              value: '${p.streak}',
              color: AppColors.red,
              semantic: 'Day streak',
            ),
            const SizedBox(width: 8),
            StatPill(
              icon: Icons.monetization_on_rounded,
              value: '${p.coins}',
              color: AppColors.yellow,
              semantic: 'Coins',
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Level ${p.level}', style: context.text.titleLarge),
                  const SizedBox(width: 8),
                  Text(p.title, style: context.text.titleSmall!.copyWith(color: AppColors.blue)),
                  const Spacer(),
                  Text('${p.xp % Profile.xpPerLevel}/${Profile.xpPerLevel} XP', style: context.text.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              FatProgress(value: p.levelProgress, color: AppColors.blue),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        const DailyCard(),
        const SizedBox(height: AppSpace.lg),
        Text('Choose your mode', style: context.text.titleLarge),
        const SizedBox(height: AppSpace.sm),
        _ModeCard(
          emoji: '📖',
          color: AppColors.teal,
          title: 'Story Mode',
          body: 'From pocket money to portfolio. Learn, play, unlock chapters.',
          cta: 'Continue story',
          onTap: () => context.push('/story'),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MiniMode(
                emoji: '🎮',
                color: AppColors.yellow,
                title: 'Arcade',
                body: 'Pure game',
                onTap: () => tab(2),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: _MiniMode(
                emoji: '🎓',
                color: AppColors.blue,
                title: 'Learn',
                body: 'Pure knowledge',
                onTap: () => tab(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          'For education only. Not investment advice.\nMutual fund investments are subject to market risks.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.emoji,
    required this.color,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });
  final String emoji, title, body, cta;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
    accent: color,
    padding: const EdgeInsets.all(AppSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Badge3D(emoji: emoji, color: color, size: 60),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.headlineSmall),
                  Text(body, style: context.text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        ChunkyButton(label: cta, color: color, icon: Icons.play_arrow_rounded, onPressed: onTap),
      ],
    ),
  );
}

class _MiniMode extends StatelessWidget {
  const _MiniMode({
    required this.emoji,
    required this.color,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final String emoji, title, body;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
    accent: color,
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Badge3D(emoji: emoji, color: color),
        const SizedBox(height: AppSpace.md),
        Text(title, style: context.text.titleLarge),
        Text(body, style: context.text.bodyMedium),
      ],
    ),
  );
}

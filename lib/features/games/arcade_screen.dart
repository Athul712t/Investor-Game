import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '_shared/games_registry.dart';

/// Play tab: the arcade. Pure game, no lessons required.
class ArcadeScreen extends ConsumerWidget {
  const ArcadeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(profileProvider.select((p) => p.highScores));
    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        Text('Arcade', style: context.text.headlineMedium),
        Text('Just play. Answer a question mid-run for a power-up.', style: context.text.bodyMedium),
        const SizedBox(height: AppSpace.md),
        for (final g in games)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Panel(
              accent: g.color,
              onTap: () => context.push('/play/${g.id}'),
              child: Row(
                children: [
                  Badge3D(emoji: g.emoji, color: g.color, size: 64),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.title, style: context.text.titleLarge),
                        Text(g.tagline, style: context.text.bodyMedium),
                        const SizedBox(height: 6),
                        Text('Best ${scores[g.id] ?? 0}', style: context.text.titleSmall!.copyWith(color: g.color)),
                      ],
                    ),
                  ),
                  Icon(Icons.play_circle_fill_rounded, color: g.color, size: 40),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

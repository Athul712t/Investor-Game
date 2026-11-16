import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../games/_shared/games_registry.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final cloud = ref.watch(cloudProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        Panel(
          accent: AppColors.blue,
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              const Badge3D(emoji: '🦊', color: AppColors.blue, size: 72),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: context.text.headlineSmall),
                    Text('Level ${p.level} · ${p.title}', style: context.text.bodyMedium),
                    const SizedBox(height: 10),
                    FatProgress(value: p.levelProgress, color: AppColors.blue),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit name',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _rename(context, ref, p.name),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(child: _Stat('🔥', '${p.streak}', 'Day streak')),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: _Stat('⚡', '${p.xp}', 'Total XP')),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: _Stat('📘', '${p.completedLessons.length}', 'Lessons')),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        Text('High scores', style: context.text.titleLarge),
        const SizedBox(height: AppSpace.sm),
        Panel(
          child: Column(
            children: [
              for (final g in games)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(g.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(g.title, style: context.text.titleMedium)),
                      Text('${p.highScores[g.id] ?? 0}', style: context.text.titleMedium!.copyWith(color: g.color)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              cloud.state == CloudState.synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              size: 16,
              color: cloud.state == CloudState.synced ? AppColors.green : AppColors.inkDim,
            ),
            const SizedBox(width: 6),
            Text(switch (cloud.state) {
              CloudState.synced => 'Progress backed up',
              CloudState.offline => 'Offline. Progress is saved on this device',
              CloudState.idle => 'Progress is saved on this device',
            }, style: context.text.bodySmall),
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
  const _Stat(this.emoji, this.value, this.label);
  final String emoji, value, label;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        Text(value, style: context.text.headlineSmall),
        Text(label, style: context.text.bodySmall),
      ],
    ),
  );
}

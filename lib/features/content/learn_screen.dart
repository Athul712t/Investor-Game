import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entities/content.dart';

/// Learn tab (module list). No Scaffold: it lives inside the shell.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final Set<String> _open = {};
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final done = ref.watch(profileProvider.select((p) => p.completedLessons));
    return content.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📚', style: TextStyle(fontSize: 48)),
              const SizedBox(height: AppSpace.sm),
              Text('Lessons could not load', style: context.text.titleLarge),
              const SizedBox(height: AppSpace.md),
              ChunkyButton(label: 'Try again', expand: false, onPressed: () => ref.invalidate(contentProvider)),
            ],
          ),
        ),
      ),
      data: (c) {
        if (!_seeded) {
          _seeded = true;
          // Start with the module that holds the next lesson open.
          final next = c.lessons.where((l) => !done.contains(l.id)).firstOrNull;
          final m = next == null ? null : c.moduleOf(next.id);
          if (m != null) _open.add(m.id);
        }
        final total = c.lessons.length;
        final finished = c.lessons.where((l) => done.contains(l.id)).length;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpace.maxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xl),
              children: [
                _Header(finished: finished, total: total),
                const SizedBox(height: AppSpace.md),
                for (final m in c.modules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: _ModuleCard(
                      module: m,
                      done: done,
                      open: _open.contains(m.id),
                      onToggle: () => setState(() => _open.contains(m.id) ? _open.remove(m.id) : _open.add(m.id)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.finished, required this.total});
  final int finished, total;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Learn', style: context.text.headlineMedium),
      const SizedBox(height: 4),
      Text(
        finished == total && total > 0
            ? 'Everything finished. Replay any lesson!'
            : 'Short lessons, one step at a time.',
        style: context.text.bodyMedium,
      ),
      const SizedBox(height: AppSpace.md),
      Panel(
        accent: AppColors.blue,
        child: Row(
          children: [
            const Badge3D(emoji: '🎓', color: AppColors.blue, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$finished of $total lessons', style: context.text.titleMedium),
                  const SizedBox(height: 8),
                  FatProgress(value: total == 0 ? 0 : finished / total, color: AppColors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.done, required this.open, required this.onToggle});
  final Module module;
  final Set<String> done;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.named(module.color);
    final n = module.lessons.where((l) => done.contains(l.id)).length;
    final total = module.lessons.length;
    final next = module.lessons.where((l) => !done.contains(l.id)).firstOrNull;
    return Panel(
      accent: color,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: '${module.title}, $n of $total lessons',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpace.radius),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Row(
                  children: [
                    Badge3D(emoji: module.emoji, color: color, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(module.title, style: context.text.titleLarge),
                          if (module.subtitle.isNotEmpty) Text(module.subtitle, style: context.text.bodyMedium),
                          const SizedBox(height: 10),
                          FatProgress(value: total == 0 ? 0 : n / total, color: color, height: 10),
                          const SizedBox(height: 6),
                          Text('$n of $total lessons', style: context.text.labelSmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      duration: AppMotion.base,
                      turns: open ? 0.5 : 0,
                      child: const Icon(Icons.expand_more_rounded, color: AppColors.inkDim),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.base,
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.sm),
                    child: Column(
                      children: [
                        for (var i = 0; i < module.lessons.length; i++)
                          _LessonRow(
                            lesson: module.lessons[i],
                            index: i,
                            color: color,
                            completed: done.contains(module.lessons[i].id),
                            isNext: module.lessons[i] == next,
                            locked: !done.contains(module.lessons[i].id) && module.lessons[i] != next,
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.index,
    required this.color,
    required this.completed,
    required this.isNext,
    required this.locked,
  });
  final Lesson lesson;
  final int index;
  final Color color;
  final bool completed, isNext, locked;

  @override
  Widget build(BuildContext context) {
    final c = locked ? AppColors.inkDim : color;
    final VoidCallback? open = locked ? null : () => context.push<bool>('/lesson/${lesson.id}');
    return Semantics(
      button: !locked,
      enabled: !locked,
      label:
          '${lesson.title}, ${lesson.minutes} minutes, ${completed
              ? 'completed'
              : locked
              ? 'locked'
              : 'next'}',
      excludeSemantics: true,
      onTap: open, // excludeSemantics drops the InkWell's own tap action
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: open,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isNext ? color.withValues(alpha: 0.16) : AppColors.ink.withValues(alpha: 0.35),
              border: Border.all(color: isNext ? color : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed ? color : Colors.transparent,
                    border: Border.all(color: c, width: 2),
                  ),
                  child: completed
                      ? const Icon(Icons.check_rounded, color: AppColors.ink, size: 22)
                      : locked
                      ? const Icon(Icons.lock_rounded, color: AppColors.inkDim, size: 18)
                      : Text('${index + 1}', style: context.text.labelLarge!.copyWith(color: color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: context.text.titleSmall!.copyWith(fontSize: 15)),
                      Text('${lesson.minutes} min', style: context.text.bodySmall),
                    ],
                  ),
                ),
                if (isNext)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                    child: Text('START', style: context.text.labelSmall!.copyWith(color: AppColors.ink)),
                  )
                else if (completed)
                  const Icon(Icons.replay_rounded, color: AppColors.inkDim, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

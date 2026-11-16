import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entities/content.dart';
import 'art.dart';

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
                _Header(modules: c.modules, done: done, finished: finished, total: total),
                const SizedBox(height: AppSpace.lg),
                for (final (i, m) in c.modules.indexed)
                  PopIn.at(
                    i,
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: _ModuleFolder(
                        module: m,
                        number: i + 1,
                        done: done,
                        open: _open.contains(m.id),
                        onToggle: () => setState(() => _open.contains(m.id) ? _open.remove(m.id) : _open.add(m.id)),
                      ),
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

/// Title plus a trophy shelf: one mini medal per lesson, filled in as lessons are finished.
class _Header extends StatelessWidget {
  const _Header({required this.modules, required this.done, required this.finished, required this.total});
  final List<Module> modules;
  final Set<String> done;
  final int finished, total;

  @override
  Widget build(BuildContext context) {
    final all = finished == total && total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Learn', style: context.text.headlineMedium),
        const SizedBox(height: 2),
        Text(
          all ? 'Everything finished. Replay any lesson!' : 'Short lessons, one step at a time.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AppSpace.md),
        Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: pieceDecoration(fill: AppColors.tint(AppColors.blue, 0.82)),
          child: Column(
            children: [
              Row(
                children: [
                  Medal(
                    size: 78,
                    core: AppColors.blue,
                    child: Text(
                      '$finished',
                      style: context.text.titleLarge!.copyWith(color: AppColors.card, fontSize: 24, height: 1),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$finished of $total lessons', style: context.text.titleLarge),
                        Text(all ? 'Trophy shelf is full' : 'Fill your trophy shelf', style: context.text.bodySmall),
                        const SizedBox(height: 10),
                        FatProgress(value: total == 0 ? 0 : finished / total, color: AppColors.blue),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              MedalShelf(
                groups: [
                  for (final m in modules) (AppColors.named(m.color), [for (final l in m.lessons) done.contains(l.id)]),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A chunky folder: colour tab and spine, title in display type, progress, and the stepping stones when open.
class _ModuleFolder extends StatelessWidget {
  const _ModuleFolder({
    required this.module,
    required this.number,
    required this.done,
    required this.open,
    required this.onToggle,
  });
  final Module module;
  final int number;
  final Set<String> done;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.named(module.color);
    final ink = AppColors.on(color);
    final n = module.lessons.where((l) => done.contains(l.id)).length;
    final total = module.lessons.length;
    final next = module.lessons.where((l) => !done.contains(l.id)).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          label: '${module.title}, $n of $total lessons',
          onTap: onToggle,
          builder: (_, down) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.depth),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              transform: Matrix4.translationValues(0, down ? AppSpace.depth : 0, 0),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: pieceDecoration(fill: AppColors.card, depth: down ? 0 : AppSpace.depth),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 62,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color,
                                border: const Border(
                                  right: BorderSide(color: AppColors.ink, width: AppSpace.outline),
                                ),
                              ),
                              child: ExcludeSemantics(child: Text(module.emoji, style: const TextStyle(fontSize: 32))),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(module.title, style: context.text.titleLarge!.copyWith(fontSize: 21)),
                                    if (module.subtitle.isNotEmpty)
                                      Text(
                                        module.subtitle,
                                        style: context.text.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Text('$n / $total', style: context.text.titleLarge!.copyWith(fontSize: 17)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: FatProgress(
                                            value: total == 0 ? 0 : n / total,
                                            color: color,
                                            height: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        AnimatedRotation(
                                          duration: AppMotion.base,
                                          turns: open ? 0.5 : 0,
                                          child: const Icon(Icons.expand_more_rounded, color: AppColors.ink),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 0,
                    child: Container(
                      height: 29,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        border: const Border(
                          top: BorderSide(color: AppColors.ink, width: AppSpace.outline),
                          left: BorderSide(color: AppColors.ink, width: AppSpace.outline),
                          right: BorderSide(color: AppColors.ink, width: AppSpace.outline),
                        ),
                      ),
                      child: Text(
                        n == total && total > 0 ? 'MODULE $number  DONE' : 'MODULE $number',
                        style: context.text.labelSmall!.copyWith(color: ink, letterSpacing: 0.6),
                      ),
                    ),
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
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pieceDecoration(fill: AppColors.paperDeep),
                    child: _Path(module: module, color: color, done: done, next: next),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Lessons as numbered stepping stones on a short zig-zag path.
class _Path extends StatelessWidget {
  const _Path({required this.module, required this.color, required this.done, required this.next});
  final Module module;
  final Color color;
  final Set<String> done;
  final Lesson? next;

  static const rowH = 114.0;

  @override
  Widget build(BuildContext context) {
    final lessons = module.lessons;
    Offset centre(int i) => Offset(i.isEven ? 38 : 76, i * rowH + rowH / 2);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _TrailPainter(
              [for (var i = 0; i < lessons.length; i++) centre(i)],
              [for (var i = 0; i < lessons.length - 1; i++) done.contains(lessons[i].id)],
              color,
            ),
          ),
        ),
        Column(
          children: [
            for (var i = 0; i < lessons.length; i++)
              SizedBox(
                height: rowH,
                child: _Step(
                  lesson: lessons[i],
                  index: i,
                  color: color,
                  centreX: centre(i).dx,
                  completed: done.contains(lessons[i].id),
                  isNext: lessons[i] == next,
                  locked: !done.contains(lessons[i].id) && lessons[i] != next,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.points, this.reached, this.color);
  final List<Offset> points;
  final List<bool> reached; // segment i joins stone i and i + 1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final len = (b - a).distance;
      final dot = Paint()..color = reached[i] ? color : AppColors.inkDim;
      final ring = Paint()..color = AppColors.ink;
      for (var d = 36.0; d < len - 34; d += 13) {
        final p = Offset.lerp(a, b, d / len)!;
        if (reached[i]) canvas.drawCircle(p, 5.5, ring);
        canvas.drawCircle(p, reached[i] ? 3.5 : 2.6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => true;
}

class _Step extends StatefulWidget {
  const _Step({
    required this.lesson,
    required this.index,
    required this.color,
    required this.centreX,
    required this.completed,
    required this.isNext,
    required this.locked,
  });
  final Lesson lesson;
  final int index;
  final Color color;
  final double centreX;
  final bool completed, isNext, locked;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isNext && !context.reduceMotion) {
      if (!_bob.isAnimating) _bob.repeat(reverse: true);
    } else {
      _bob.stop();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final color = widget.color;
    final left = widget.index.isEven;
    final VoidCallback? open = widget.locked ? null : () => context.push<bool>('/lesson/${lesson.id}');
    final label =
        '${lesson.title}, ${lesson.minutes} minutes, ${widget.completed
            ? 'completed'
            : widget.locked
            ? 'locked'
            : 'next'}';
    final textBlock = Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: left ? 0 : 0, right: 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall!.copyWith(
                fontSize: 15,
                color: widget.locked ? AppColors.inkDim : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${lesson.minutes} min', style: context.text.bodySmall),
                if (widget.isNext)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: pieceDecoration(fill: color, radius: 999, depth: 0),
                    child: Text(
                      'Start',
                      style: context.text.labelLarge!.copyWith(color: AppColors.on(color), fontSize: 13),
                    ),
                  )
                else if (widget.completed)
                  const Icon(Icons.replay_rounded, color: AppColors.inkDim, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
    return Pressable(
      label: label,
      onTap: open,
      builder: (_, down) => Row(
        children: [
          SizedBox(width: widget.centreX - 32 < 0 ? 0 : widget.centreX - 32),
          AnimatedBuilder(
            animation: _bob,
            builder: (_, child) =>
                Transform.translate(offset: Offset(0, -5 * Curves.easeInOut.transform(_bob.value)), child: child),
            child: _Stone(
              down: down,
              color: color,
              completed: widget.completed,
              isNext: widget.isNext,
              locked: widget.locked,
              number: widget.index + 1,
            ),
          ),
          const SizedBox(width: 12),
          textBlock,
        ],
      ),
    );
  }
}

class _Stone extends StatelessWidget {
  const _Stone({
    required this.down,
    required this.color,
    required this.completed,
    required this.isNext,
    required this.locked,
    required this.number,
  });
  final bool down, completed, isNext, locked;
  final Color color;
  final int number;

  @override
  Widget build(BuildContext context) {
    final fill = completed ? AppColors.green : (locked ? AppColors.paperDeep : color);
    final size = isNext ? 66.0 : 58.0;
    final depth = locked ? 0.0 : (isNext ? 6.0 : 4.0);
    final fg = locked ? AppColors.inkDim : AppColors.on(fill);
    return SizedBox(
      width: 66,
      height: 66 + 6,
      child: Align(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: Matrix4.translationValues(0, down && !locked ? depth : 0, 0),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: locked ? AppColors.inkDim : AppColors.ink, width: AppSpace.outline),
            boxShadow: locked || (down) ? null : [BoxShadow(color: AppColors.ink, offset: Offset(0, depth))],
          ),
          child: completed
              ? Icon(Icons.check_rounded, color: fg, size: 32)
              : locked
              ? Icon(Icons.lock_rounded, color: fg, size: 24)
              : Text('$number', style: context.text.headlineSmall!.copyWith(color: fg)),
        ),
      ),
    );
  }
}

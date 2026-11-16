import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'chapter_screen.dart';
import 'story_data.dart';

/// Story Mode home: a winding board-game path of chapter medallions. Route /story.
class StoryMapScreen extends ConsumerWidget {
  const StoryMapScreen({super.key});

  Future<void> _open(BuildContext context, Story story, int i) async {
    final finished = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChapterScreen(story: story, index: i),
      ),
    );
    if (finished == true && context.mounted && i + 1 < story.chapters.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.paperDeep,
          content: Text('🔓  ${story.chapters[i + 1].title} unlocked!', style: context.text.titleMedium),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(storyProvider);
    final profile = ref.watch(profileProvider);
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Story Mode'),
        actions: [
          StatPill(icon: Icons.bolt_rounded, value: '${profile.xp}', color: AppColors.blue, semantic: 'XP'),
          const SizedBox(width: AppSpace.md),
        ],
      ),
      body: story.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the story', style: context.text.bodyLarge)),
        // Map scrolls under a soft fade instead of sliding behind the app bar title.
        data: (s) => Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.ink.withValues(alpha: 0), AppColors.ink],
              stops: [0, AppSpace.lg / r.height],
            ).createShader(r),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xl),
              children: [
                Text(
                  'From Pocket Money\nto Portfolio',
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${profile.name}, your first job in the city starts now',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpace.md),
                _MapPath(story: s, done: profile.storyDone, onOpen: (i) => _open(context, s, i)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPath extends StatelessWidget {
  const _MapPath({required this.story, required this.done, required this.onOpen});
  final Story story;
  final Set<String> done;
  final ValueChanged<int> onOpen;

  static const _row = 210.0, _top = 40.0, _medal = 108.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final n = story.chapters.length;
      // Stops: start flag, one per chapter (zig-zag), then the "coming soon" sign.
      final points = [
        Offset(w * 0.5, _top),
        for (var i = 0; i < n; i++) Offset(w * (i.isEven ? 0.24 : 0.76), _top + (i + 1) * _row),
        Offset(w * 0.5, _top + (n + 1) * _row - 30),
      ];
      final unlocked = [for (var i = 0; i < n; i++) story.isUnlocked(i, done)];
      final current = unlocked.lastIndexWhere((u) => u);
      final allDone = story.chapters.last.isComplete(done);
      return SizedBox(
        height: points.last.dy + 90,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PathPainter(points: points, litSegments: unlocked.where((u) => u).length + (allDone ? 1 : 0)),
              ),
            ),
            for (var i = 0; i < n + 1; i++) _scenery(i, w, points),
            Positioned(
              left: 0,
              right: 0,
              top: points.first.dy - 20,
              child: Center(
                child: _Flag(emoji: '🏁', text: 'Start: first job'),
              ),
            ),
            for (var i = 0; i < n; i++)
              Positioned(
                left: 0,
                right: 0,
                top: points[i + 1].dy - _medal / 2,
                child: _ChapterStop(
                  index: i,
                  chapter: story.chapters[i],
                  done: done,
                  unlocked: unlocked[i],
                  current: i == current && !story.chapters[i].isComplete(done),
                  leftSide: i.isEven,
                  width: w,
                  prevTitle: i == 0 ? '' : story.chapters[i - 1].title,
                  onTap: () => onOpen(i),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: points.last.dy - 24,
              child: Center(
                child: _Flag(emoji: '🚧', text: 'More chapters coming soon', dim: true),
              ),
            ),
          ],
        ),
      );
    },
  );

  // Little decorations on the empty side of each bend.
  Widget _scenery(int i, double w, List<Offset> points) {
    const items = ['🌴', '🏙️', '☁️', '🌳', '🪙', '🏦'];
    final y = (points[i].dy + points[i + 1].dy) / 2;
    final left = i.isOdd;
    return Positioned(
      top: y - 18,
      left: left ? w * 0.04 : null,
      right: left ? null : w * 0.04,
      child: ExcludeSemantics(
        child: Opacity(opacity: 0.55, child: Text(items[i % items.length], style: const TextStyle(fontSize: 30))),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.emoji, required this.text, this.dim = false});
  final String emoji, text;
  final bool dim;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.paperDeep,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: dim ? AppColors.track : AppColors.teal.withValues(alpha: 0.5), width: 1.5),
      boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 4))],
    ),
    child: Text('$emoji  $text', style: context.text.titleSmall!.copyWith(color: dim ? AppColors.inkDim : null)),
  );
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.points, required this.litSegments});
  final List<Offset> points;
  final int litSegments;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final dy = (b.dy - a.dy) * 0.6;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, a.dy + dy, b.dx, b.dy - dy, b.dx, b.dy);
      final lit = i < litSegments;
      final last = i == points.length - 2;
      // Soft road underneath, then dots on top.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..color = (lit ? AppColors.green : AppColors.paperDeep).withValues(alpha: lit ? 0.10 : 0.6),
      );
      final dot = Paint()
        ..color = lit ? AppColors.green : (last ? AppColors.track : AppColors.inkDim.withValues(alpha: 0.5));
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 16) {
          canvas.drawCircle(m.getTangentForOffset(d)!.position, lit ? 4 : 3, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.litSegments != litSegments || old.points != points;
}

class _ChapterStop extends StatelessWidget {
  const _ChapterStop({
    required this.index,
    required this.chapter,
    required this.done,
    required this.unlocked,
    required this.current,
    required this.leftSide,
    required this.width,
    required this.prevTitle,
    required this.onTap,
  });
  final int index;
  final Chapter chapter;
  final Set<String> done;
  final bool unlocked, current, leftSide;
  final double width;
  final String prevTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = chapter.doneCount(done);
    final total = chapter.nodes.length;
    final complete = count == total;
    final status = !unlocked
        ? 'Finish $prevTitle to unlock'
        : complete
        ? 'Complete · tap to replay'
        : '$count of $total steps';
    final medal = _Medallion(
      emoji: chapter.emoji,
      color: chapter.color,
      progress: count / total,
      unlocked: unlocked,
      current: current,
      complete: complete,
    );
    final text = Column(
      crossAxisAlignment: leftSide ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CHAPTER ${index + 1}',
          style: context.text.labelSmall!.copyWith(
            color: unlocked ? chapter.color : AppColors.inkDim,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          chapter.title,
          textAlign: leftSide ? TextAlign.left : TextAlign.right,
          style: context.text.titleLarge!.copyWith(color: unlocked ? null : AppColors.inkDim),
        ),
        Text(chapter.subtitle, textAlign: leftSide ? TextAlign.left : TextAlign.right, style: context.text.bodySmall),
        const SizedBox(height: 6),
        if (current)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
            decoration: BoxDecoration(
              color: chapter.color,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: Color.lerp(chapter.color, AppColors.ink, 0.5)!, offset: const Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == 0 ? 'START' : 'CONTINUE',
                  style: context.text.labelSmall!.copyWith(color: AppColors.ink, letterSpacing: 1),
                ),
                const Icon(Icons.play_arrow_rounded, size: 16, color: AppColors.ink),
              ],
            ),
          )
        else
          Text(
            status,
            textAlign: leftSide ? TextAlign.left : TextAlign.right,
            style: context.text.labelSmall!.copyWith(color: complete ? AppColors.green : AppColors.inkDim),
          ),
      ],
    );
    void tap() {
      if (unlocked) return onTap();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.paperDeep,
            content: Text('🔒  $status', style: context.text.titleSmall),
          ),
        );
    }

    return Semantics(
      button: true,
      label: 'Chapter ${index + 1}, ${chapter.title}. ${unlocked ? '$count of $total steps done' : status}',
      excludeSemantics: true,
      onTap: tap, // excludeSemantics drops the detector's own tap action
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        // Min, not fixed, height: large text may run below the medal into the gap before the next stop.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _MapPath._medal + 20),
          child: Row(
            textDirection: leftSide ? TextDirection.ltr : TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: width * 0.24 - _MapPath._medal / 2),
              medal,
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Padding(padding: const EdgeInsets.only(top: 8), child: text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big round chapter token with a progress ring, a raised edge, and a pulse when current.
class _Medallion extends StatefulWidget {
  const _Medallion({
    required this.emoji,
    required this.color,
    required this.progress,
    required this.unlocked,
    required this.current,
    required this.complete,
  });
  final String emoji;
  final Color color;
  final double progress;
  final bool unlocked, current, complete;

  @override
  State<_Medallion> createState() => _MedallionState();
}

class _MedallionState extends State<_Medallion> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Medallion old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate = widget.current && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) _pulse.repeat();
    if (!animate) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = _MapPath._medal;
    final c = widget.unlocked ? widget.color : AppColors.track;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.current)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) {
                final t = _pulse.value;
                return Container(
                  width: size * (1 + 0.35 * t),
                  height: size * (1 + 0.35 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.withValues(alpha: 0.6 * (1 - t)), width: 4),
                    color: c.withValues(alpha: 0.12 * (1 - t)),
                  ),
                );
              },
            ),
          CustomPaint(
            size: const Size.square(size),
            painter: _RingPainter(progress: widget.unlocked ? widget.progress : 0, color: c),
          ),
          // Raised token: darker edge below a glossy face.
          Container(
            width: size - 22,
            height: size - 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                colors: widget.unlocked
                    ? [Color.lerp(c, Colors.white, 0.35)!, c, Color.lerp(c, AppColors.ink, 0.35)!]
                    : const [AppColors.paperDeep, AppColors.card],
                stops: widget.unlocked ? const [0, 0.55, 1] : null,
              ),
              boxShadow: [
                BoxShadow(color: Color.lerp(c, AppColors.ink, 0.6)!, offset: const Offset(0, 6)),
                if (widget.unlocked) BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 22),
              ],
            ),
            alignment: Alignment.center,
            child: widget.unlocked
                ? Text(widget.emoji, style: const TextStyle(fontSize: 42))
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Opacity(opacity: 0.3, child: Text(widget.emoji, style: const TextStyle(fontSize: 42))),
                  ),
          ),
          if (!widget.unlocked)
            _corner(AppColors.paperDeep, const Icon(Icons.lock_rounded, size: 18, color: AppColors.inkDim)),
          if (widget.complete)
            _corner(AppColors.green, const Icon(Icons.check_rounded, size: 20, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _corner(Color bg, Widget icon) => Positioned(
    right: 2,
    bottom: 2,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 3),
      ),
      child: icon,
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(4);
    canvas.drawCircle(rect.center, size.width / 2 - 4, Paint()..color = AppColors.ink.withValues(alpha: 0.7));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * pi, false, stroke..color = AppColors.track);
    if (progress > 0) canvas.drawArc(r, -pi / 2, 2 * pi * progress, false, stroke..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

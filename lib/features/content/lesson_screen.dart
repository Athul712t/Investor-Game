import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entities/content.dart';
import 'question_view.dart';

enum _Phase { cards, questions, summary }

/// Full-screen lesson: cards, then questions, then a summary. Pops `true` when completed.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final lesson = content.value?.lesson(lessonId);
    if (lesson != null) {
      final color = AppColors.named(content.value!.moduleOf(lessonId)?.color);
      return _LessonFlow(key: ValueKey(lessonId), lesson: lesson, color: color);
    }
    return AppScaffold(
      body: Center(
        child: content.isLoading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🧭', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      content.hasError ? 'Lessons could not load' : 'We could not find that lesson',
                      style: context.text.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    ChunkyButton(
                      label: 'Go back',
                      expand: false,
                      onPressed: () => Navigator.of(context).maybePop(false),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _LessonFlow extends ConsumerStatefulWidget {
  const _LessonFlow({super.key, required this.lesson, required this.color});
  final Lesson lesson;
  final Color color;

  @override
  ConsumerState<_LessonFlow> createState() => _LessonFlowState();
}

class _LessonFlowState extends ConsumerState<_LessonFlow> {
  final _pages = PageController();
  _Phase _phase = _Phase.cards;
  int _card = 0;
  int _q = 0;
  int _correct = 0;
  int _xp = 0;

  Lesson get _lesson => widget.lesson;
  int get _steps => _lesson.cards.length + _lesson.questions.length;

  double get _progress => switch (_phase) {
    _Phase.cards => _card / _steps,
    _Phase.questions => (_lesson.cards.length + _q) / _steps,
    _Phase.summary => 1,
  };

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _nextCard() {
    if (_card < _lesson.cards.length - 1) {
      _pages.nextPage(duration: AppMotion.base, curve: AppMotion.curve);
    } else {
      setState(() => _phase = _lesson.questions.isEmpty ? _finish() : _Phase.questions);
    }
  }

  void _answered(bool ok) {
    if (ok) _correct++;
    if (_q < _lesson.questions.length - 1) {
      setState(() => _q++);
    } else {
      setState(() => _phase = _finish());
    }
  }

  _Phase _finish() {
    final xp = 10 + 2 * _correct;
    final first = ref.read(profileProvider.notifier).completeLesson(_lesson.id, xp: xp);
    _xp = first ? xp : xp ~/ 4; // mirrors the profile's replay reward
    return _Phase.summary;
  }

  /// Pops with [done]; a reloaded deep link has no route below, so it goes home instead.
  void _leave(bool done) {
    final nav = Navigator.of(context);
    nav.canPop() ? nav.pop(done) : context.go('/');
  }

  Future<void> _close() async {
    if (_phase == _Phase.summary) return _leave(true);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpace.radius)),
        title: Text('Leave this lesson?', style: ctx.text.titleLarge),
        content: Text('Your progress in this lesson will be lost.', style: ctx.text.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep going')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) _leave(false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false, // system back on the summary must still pop true
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: AppScaffold(
      glow: widget.color,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, AppSpace.md, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FatProgress(value: _progress, color: widget.color),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.base,
              switchInCurve: AppMotion.curve,
              layoutBuilder: (cur, prev) => Stack(fit: StackFit.expand, children: [...prev, ?cur]),
              child: switch (_phase) {
                _Phase.cards => _cards(),
                _Phase.questions => _questions(),
                _Phase.summary => _Summary(
                  key: const ValueKey('summary'),
                  correct: _correct,
                  total: _lesson.questions.length,
                  xp: _xp,
                  color: widget.color,
                  onContinue: () => _leave(true),
                ),
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _cards() {
    final last = _card == _lesson.cards.length - 1;
    return Column(
      key: const ValueKey('cards'),
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: _lesson.cards.length,
            onPageChanged: (i) => setState(() => _card = i),
            itemBuilder: (_, i) {
              final c = _lesson.cards[i];
              return Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Panel(
                  accent: widget.color,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            tween: Tween(begin: 0.4, end: 1),
                            builder: (_, s, child) => Transform.scale(scale: s, child: child),
                            child: Text(c.emoji, style: const TextStyle(fontSize: 88)),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          Text(c.title, textAlign: TextAlign.center, style: context.text.headlineSmall),
                          const SizedBox(height: AppSpace.md),
                          Text(
                            c.body,
                            textAlign: TextAlign.center,
                            style: context.text.bodyLarge!.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _lesson.cards.length; i++)
              AnimatedContainer(
                duration: AppMotion.base,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _card ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: i == _card ? widget.color : AppColors.line,
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: ChunkyButton(label: last ? 'Start quiz' : 'Next', color: widget.color, onPressed: _nextCard),
        ),
      ],
    );
  }

  Widget _questions() => SingleChildScrollView(
    key: ValueKey('q$_q'),
    padding: const EdgeInsets.all(AppSpace.md),
    child: QuestionView(question: _lesson.questions[_q], onAnswered: _answered),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    super.key,
    required this.correct,
    required this.total,
    required this.xp,
    required this.color,
    required this.onContinue,
  });
  final int correct, total, xp;
  final Color color;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final perfect = correct == total;
    return Stack(
      children: [
        const Positioned.fill(child: IgnorePointer(child: _Confetti())),
        Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.elasticOut,
                        tween: Tween(begin: 0, end: 1),
                        builder: (_, s, child) => Transform.scale(scale: s, child: child),
                        child: Text(perfect ? '🏆' : '🎉', style: const TextStyle(fontSize: 96)),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(perfect ? 'Perfect!' : 'Lesson complete!', style: context.text.headlineMedium),
                      const SizedBox(height: AppSpace.sm),
                      Text('$correct of $total correct', style: context.text.titleLarge!.copyWith(color: color)),
                      const SizedBox(height: AppSpace.lg),
                      StatPill(icon: Icons.bolt_rounded, value: '+$xp XP', color: AppColors.violet, semantic: 'Earned'),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: ChunkyButton(label: 'Continue', color: color, onPressed: onContinue),
            ),
          ],
        ),
      ],
    );
  }
}

/// One-shot confetti burst drawn in code.
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  static const _palette = [AppColors.mint, AppColors.amber, AppColors.coral, AppColors.violet, AppColors.sky];
  late final _bits = () {
    final r = Random(7);
    return [
      for (var i = 0; i < 60; i++)
        (
          angle: -pi / 2 + (r.nextDouble() - 0.5) * pi * 1.1,
          speed: 380 + r.nextDouble() * 520,
          spin: r.nextDouble() * 12,
          size: 6 + r.nextDouble() * 6,
          color: _palette[i % _palette.length],
        ),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_bits, _c.value)),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);
  final List<({double angle, double speed, double spin, double size, Color color})> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.36);
    final secs = t * 2.6;
    for (final b in bits) {
      final p =
          origin +
          Offset(cos(b.angle) * b.speed * secs * 0.55, sin(b.angle) * b.speed * secs * 0.55 + 520 * secs * secs * 0.5);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(b.spin * secs);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 1.7),
          const Radius.circular(2),
        ),
        Paint()..color = b.color.withValues(alpha: (1 - t * t).clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

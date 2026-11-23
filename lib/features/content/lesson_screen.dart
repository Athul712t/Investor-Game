import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entities/content.dart';
import 'art.dart';
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

  void _nextCard() {
    if (_card < _lesson.cards.length - 1) {
      setState(() => _card++);
    } else {
      setState(() => _phase = _lesson.questions.isEmpty ? _finish() : _Phase.questions);
    }
  }

  void _answered(bool ok) {
    ref.read(profileProvider.notifier).noteAnswer(_lesson.questions[_q], ok);
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
        title: Text('Leave this lesson?', style: ctx.text.titleLarge),
        content: Text('Your progress in this lesson will be lost.', style: ctx.text.bodyMedium),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: ChunkyButton(label: 'Keep going', onPressed: () => Navigator.of(ctx).pop(false)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChunkyButton(label: 'Leave', color: AppColors.red, onPressed: () => Navigator.of(ctx).pop(true)),
              ),
            ],
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, 8, AppSpace.md, 0),
            child: Row(
              children: [
                Pressable(
                  label: 'Close',
                  onTap: _close,
                  builder: (_, down) => SizedBox(
                    width: 48,
                    height: 52,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 60),
                        transform: Matrix4.translationValues(0, down ? 3 : 0, 0),
                        width: 44,
                        height: 44,
                        decoration: pieceDecoration(radius: 14, depth: down ? 0 : 3),
                        child: const Icon(Icons.close_rounded, color: AppColors.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: FatProgress(value: _progress, color: widget.color, height: 20),
                  ),
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
          child: _CardDeck(cards: _lesson.cards, index: _card, color: widget.color, onThrow: _nextCard),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Tap the card to flip it', style: context.text.bodySmall),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _lesson.cards.length; i++)
              AnimatedContainer(
                duration: AppMotion.base,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _card ? 24 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: i == _card ? widget.color : (i < _card ? AppColors.ink : AppColors.track),
                  border: Border.all(color: AppColors.ink, width: 2),
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

/// The lesson cards as a deck: the current card sits on a stack, tapping flips it in 3D, advancing throws it off
/// and the next one rises. Both motions are springs, so another tap interrupts them.
class _CardDeck extends StatefulWidget {
  const _CardDeck({required this.cards, required this.index, required this.color, required this.onThrow});
  final List<LessonCard> cards;
  final int index;
  final Color color;
  final VoidCallback onThrow;

  @override
  State<_CardDeck> createState() => _CardDeckState();
}

class _CardDeckState extends State<_CardDeck> with TickerProviderStateMixin {
  late final _t = AnimationController.unbounded(vsync: this); // throw progress, 0 to 1
  late final _flip = AnimationController.unbounded(vsync: this); // 0 front, 1 back
  int? _thrown; // index of the card in the air
  double _thrownFlip = 0;
  double _dir = 1;
  bool _back = false;

  @override
  void didUpdateWidget(_CardDeck old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    final flipped = _flip.value;
    _back = false;
    _flip.stop();
    _flip.value = 0;
    if (context.reduceMotion || widget.index < old.index) {
      _thrown = null;
      return;
    }
    final mine = _thrown = old.index;
    _thrownFlip = flipped;
    _dir = old.index.isEven ? 1 : -1;
    _t.stop();
    _t.value = 0;
    _t.springTo(1, spring: const SpringDescription(mass: 1, stiffness: 260, damping: 30)).then((_) {
      if (mounted && _thrown == mine) setState(() => _thrown = null);
    });
  }

  @override
  void dispose() {
    _t.dispose();
    _flip.dispose();
    super.dispose();
  }

  void _toggle() {
    _back = !_back;
    if (context.reduceMotion) {
      _flip.value = _back ? 1 : 0;
    } else {
      _flip.springTo(_back ? 1 : 0, spring: const SpringDescription(mass: 1, stiffness: 380, damping: 30));
    }
  }

  Widget _card(int j, double depth, {required double flipValue}) {
    final lesson = widget.cards[j];
    final angle = flipValue.clamp(0.0, 1.0) * pi;
    final showBack = angle > pi / 2;
    final face = showBack
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(pi),
            child: _CardBack(card: lesson, color: widget.color),
          )
        : _CardFront(card: lesson, color: widget.color);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle),
      child: face,
    );
  }

  /// A blank card behind the top one, nudged and tilted so the stack reads as a deck.
  Widget _blank(int j, double depth) => DecoratedBox(
    decoration: pieceDecoration(fill: j.isEven ? AppColors.paperDeep : AppColors.card, radius: 22, depth: 0),
    child: const SizedBox.expand(),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => AnimatedBuilder(
      animation: Listenable.merge([_t, _flip]),
      builder: (context, _) {
        final i = widget.index;
        final rise = _thrown == null ? 0.0 : (1 - _t.value);
        final w = box.maxWidth;
        final children = <Widget>[];
        for (var j = min(widget.cards.length - 1, i + 2); j >= i; j--) {
          final d = ((j - i) + rise).clamp(0.0, 2.0);
          final sign = j.isOdd ? 1.0 : -1.0;
          final top = j == i;
          final body = top ? _card(j, d, flipValue: _flip.value) : _blank(j, d);
          children.add(
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, -10 * d),
                child: Transform.scale(
                  scale: 1 - 0.045 * d,
                  child: Transform.rotate(
                    angle: sign * 0.018 * d,
                    child: top
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggle,
                            onHorizontalDragEnd: (e) {
                              if ((e.primaryVelocity ?? 0).abs() > 380) widget.onThrow();
                            },
                            child: body,
                          )
                        : body,
                  ),
                ),
              ),
            ),
          );
        }
        final th = _thrown;
        if (th != null) {
          final t = _t.value;
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(_dir * t * w * 1.15, -t * 50 + t * t * 140),
                  child: Transform.rotate(
                    angle: _dir * t * 0.7,
                    child: _card(th, 0, flipValue: _thrownFlip),
                  ),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 26, AppSpace.lg, AppSpace.md),
          child: Center(
            child: SizedBox(
              height: min(box.maxHeight - 26 - AppSpace.md, 470),
              child: Stack(clipBehavior: Clip.none, children: children),
            ),
          ),
        );
      },
    ),
  );
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card, required this.color});
  final LessonCard card;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: pieceDecoration(radius: 22, depth: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 150,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            border: const Border(
              bottom: BorderSide(color: AppColors.ink, width: AppSpace.outline),
            ),
          ),
          child: ExcludeSemantics(child: Text(card.emoji, style: const TextStyle(fontSize: 80))),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title, style: context.text.headlineSmall),
                const SizedBox(height: 8),
                Text(card.body, style: context.text.bodyLarge!.copyWith(height: 1.45, fontSize: 17)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.card, required this.color});
  final LessonCard card;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.lg),
    decoration: pieceDecoration(fill: color, radius: 22, depth: 6),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: pieceDecoration(radius: 999, depth: 3),
          child: Text('IN SHORT', style: context.text.labelLarge!.copyWith(letterSpacing: 1.2)),
        ),
        const SizedBox(height: AppSpace.md),
        Flexible(
          child: SingleChildScrollView(
            child: OutlinedText(
              card.title,
              textAlign: TextAlign.center,
              style: context.text.headlineMedium!.copyWith(fontSize: 30),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text('Tap to flip back', style: context.text.bodySmall!.copyWith(color: AppColors.on(color))),
      ],
    ),
  );
}

/// Springs in once [show] turns true: a medal drops from above, stars pop from nothing.
class _SpringIn extends StatefulWidget {
  const _SpringIn({required this.show, required this.child, this.drop = 0});
  final bool show;
  final double drop;
  final Widget child;

  @override
  State<_SpringIn> createState() => _SpringInState();
}

class _SpringInState extends State<_SpringIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    if (widget.show) _run();
  }

  @override
  void didUpdateWidget(_SpringIn old) {
    super.didUpdateWidget(old);
    if (widget.show && !old.show) _run();
  }

  void _run() => context.reduceMotion ? _c.value = 1 : _c.springTo(1, spring: AppMotion.bouncy);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Visibility(
    visible: widget.show,
    maintainSize: true,
    maintainState: true,
    maintainAnimation: true,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, child) => widget.drop > 0
          ? Transform.translate(offset: Offset(0, -widget.drop * (1 - _c.value)), child: child)
          : Transform.scale(scale: max(0, _c.value), child: child),
      child: widget.child,
    ),
  );
}

class _Summary extends StatefulWidget {
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
  State<_Summary> createState() => _SummaryState();
}

class _SummaryState extends State<_Summary> {
  bool _medal = false;
  int _shown = 0;

  int get _stars {
    final r = widget.total == 0 ? 1.0 : widget.correct / widget.total;
    return r >= 0.99 ? 3 : (r >= 0.6 ? 2 : 1);
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _medal = true);
      Sound.play(Sfx.drop);
    });
    for (var i = 0; i < _stars; i++) {
      Future.delayed(Duration(milliseconds: 750 + 260 * i), () {
        if (!mounted) return;
        setState(() => _shown = i + 1);
        if (i == _stars - 1) Sound.play(_stars == 3 ? Sfx.perfect : Sfx.levelUp);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfect = widget.correct == widget.total;
    final color = widget.color;
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
                      _SpringIn(
                        show: _medal,
                        drop: 320,
                        child: Medal(size: 150, core: color),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(perfect ? 'Perfect!' : 'Lesson complete!', style: context.text.headlineMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.correct} of ${widget.total} correct',
                        style: context.text.titleLarge!.copyWith(color: AppColors.inkDim),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 6, top: i == 1 ? 0 : 14),
                              child: i < _stars
                                  ? _SpringIn(
                                      show: _shown > i,
                                      child: SizedBox.square(
                                        dimension: i == 1 ? 68 : 56,
                                        child: const CustomPaint(painter: StarPainter(AppColors.yellow)),
                                      ),
                                    )
                                  : SizedBox.square(
                                      dimension: i == 1 ? 68 : 56,
                                      child: const CustomPaint(painter: StarPainter(AppColors.paperDeep)),
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      Semantics(
                        label: 'Earned ${widget.xp} XP',
                        excludeSemantics: true,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 6, 18, 6),
                          decoration: pieceDecoration(fill: AppColors.blue, radius: 999),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: pieceDecoration(radius: 999, depth: 0),
                                child: const Icon(Icons.bolt_rounded, color: AppColors.ink, size: 22),
                              ),
                              const SizedBox(width: 10),
                              CountUp(
                                value: widget.xp,
                                prefix: '+',
                                suffix: ' XP',
                                style: context.text.headlineSmall!.copyWith(color: AppColors.card),
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
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: ChunkyButton(label: 'Continue', color: color, onPressed: widget.onContinue),
            ),
          ],
        ),
      ],
    );
  }
}

/// One-shot confetti burst of small outlined squares and circles in the palette.
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  static const _palette = [
    AppColors.green,
    AppColors.yellow,
    AppColors.red,
    AppColors.blue,
    AppColors.teal,
    AppColors.orange,
  ];
  late final _bits = () {
    final r = Random(7);
    return [
      for (var i = 0; i < 44; i++)
        (
          angle: -pi / 2 + (r.nextDouble() - 0.5) * pi * 1.2,
          speed: 380 + r.nextDouble() * 520,
          spin: r.nextDouble() * 12,
          size: 9 + r.nextDouble() * 6,
          round: i.isOdd,
          color: _palette[i % _palette.length],
        ),
    ];
  }();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!context.reduceMotion && !_c.isAnimating && _c.value == 0) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _c.forward();
      });
    }
  }

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
  final List<({double angle, double speed, double spin, double size, bool round, Color color})> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.34);
    final secs = t * 2.8;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.ink;
    for (final b in bits) {
      final p =
          origin +
          Offset(cos(b.angle) * b.speed * secs * 0.55, sin(b.angle) * b.speed * secs * 0.55 + 520 * secs * secs * 0.5);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(b.spin * secs);
      final fill = Paint()..color = b.color;
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2, fill);
        canvas.drawCircle(Offset.zero, b.size / 2, edge);
      } else {
        final r = Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, edge);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

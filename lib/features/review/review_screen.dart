import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entities/question.dart';
import '../content/question_view.dart';
import '../reel/reel_extra.dart';
import 'review_logic.dart';
import 'review_tile.dart';

/// Every question a review entry can point at: lesson questions plus the extra reel questions.
final reviewQuestionsProvider = Provider<Map<String, Question>>((ref) {
  final content = ref.watch(contentProvider).value;
  final extra = ref.watch(reelExtraProvider).value;
  return {
    for (final l in content?.lessons ?? const [])
      for (final q in l.questions) q.id: q,
    for (final qs in extra?.questions.values ?? const <List<Question>>[])
      for (final q in qs) q.id: q,
  };
});

enum _Phase { intro, session, summary }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> with SingleTickerProviderStateMixin {
  static const _xpPerAnswer = 5, _coinsPerAnswer = 1, _xpBonus = 10;

  // Soft timer: when it runs out the session ends after the current question.
  late final _clock =
      AnimationController(
        vsync: this,
        duration: const Duration(seconds: reviewSeconds),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _timeUp = true;
      });
  _Phase _phase = _Phase.intro;
  List<Question> _items = const [];
  final _results = <bool>[];
  var _graduated = 0;
  var _timeUp = false;
  String _next = '';

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  String get _today => dayKey(DateTime.now());

  void _start(Map<String, Question> byId) {
    final due = dueSession(ref.read(profileProvider).review, byId.keys.toSet(), _today);
    if (due.isEmpty) return;
    setState(() {
      _items = [for (final r in due) byId[r['id']]!];
      _results.clear();
      _graduated = 0;
      _timeUp = false;
      _phase = _Phase.session;
    });
    _clock.forward(from: 0);
  }

  void _answered(bool correct) {
    final q = _items[_results.length];
    final today = _today;
    final me = ref.read(profileProvider.notifier);
    me.noteAnswer(q, correct, fromReview: true); // mastery and quests; the queue is ours
    me.mutate((p) => p.copyWith(review: applyAnswer(p.review, q.id, correct, today)));
    if (correct) {
      me.reward(xp: _xpPerAnswer, coins: _coinsPerAnswer);
      Sound.play(Sfx.coin);
    }
    final graduated = correct && !ref.read(profileProvider).review.any((r) => r['id'] == q.id);
    _results.add(correct);
    if (graduated) _graduated++;
    if (_results.length >= _items.length || _timeUp) return _finish();
    setState(() {});
  }

  void _finish() {
    _clock.stop();
    final me = ref.read(profileProvider.notifier);
    me.reward(xp: _xpBonus);
    final review = ref.read(profileProvider).review;
    final ids = ref.read(reviewQuestionsProvider).keys.toSet();
    final today = _today;
    final waiting = dueCount(review, ids, today);
    final later = nextDue(review, ids, today);
    _next = waiting > 0
        ? 'now, $waiting more waiting'
        : later == null
        ? 'nothing left to review'
        : switch (daysBetween(today, later)) {
            1 => 'tomorrow',
            final n => 'in $n days',
          };
    Sound.play(Sfx.win);
    Haptics.heavy();
    setState(() => _phase = _Phase.summary);
  }

  @override
  Widget build(BuildContext context) {
    final byId = ref.watch(reviewQuestionsProvider);
    final loading = ref.watch(contentProvider).isLoading;
    final review = ref.watch(profileProvider.select((p) => p.review));
    final ids = byId.keys.toSet();
    return AppScaffold(
      body: switch (_phase) {
        _Phase.intro => _Intro(
          loading: loading,
          due: dueCount(review, ids, _today),
          coming: upcoming(review, ids, _today),
          next: nextDue(review, ids, _today),
          today: _today,
          onStart: () => _start(byId),
        ),
        _Phase.session => _Session(items: _items, results: _results, clock: _clock, onAnswered: _answered),
        _Phase.summary => _Summary(
          correct: _results.where((r) => r).length,
          total: _results.length,
          graduated: _graduated,
          next: _next,
          xp: _results.where((r) => r).length * _xpPerAnswer + _xpBonus,
          coins: _results.where((r) => r).length * _coinsPerAnswer,
        ),
      },
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) => Pressable(
    label: 'Close',
    onTap: () => Navigator.of(context).maybePop(),
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
  );
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.loading,
    required this.due,
    required this.coming,
    required this.next,
    required this.today,
    required this.onStart,
  });
  final bool loading;
  final int due;
  final ({int tomorrow, int in3, int in7}) coming;
  final String? next;
  final String today;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final ready = due > 0;
    final session = min(due, reviewSessionSize);
    final hint = loading
        ? 'Loading your questions...'
        : next == null
        ? 'All caught up. Questions you miss in lessons, games and the reel come back here to be learned for good.'
        : 'All caught up. Your next review is ${daysBetween(today, next!) == 1 ? 'tomorrow' : 'in ${daysBetween(today, next!)} days'}.';
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 8, AppSpace.md, AppSpace.sm),
      children: [
        const Align(alignment: Alignment.centerLeft, child: _CloseButton()),
        PopIn(
          child: Panel(
            accent: AppColors.blue,
            child: Column(
              children: [
                const ReviewPicto(size: 84),
                const SizedBox(height: AppSpace.sm),
                Text('Spaced review', style: t.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Missed questions return after 1, 3 and 7 days until they stick.',
                  style: t.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        PopIn.at(
          1,
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$due', style: t.displaySmall!.copyWith(color: ready ? AppColors.blue : AppColors.inkDim)),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: Text('due now', style: t.titleLarge)),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text('Coming up', style: t.labelSmall),
                const SizedBox(height: AppSpace.xs),
                Wrap(
                  spacing: AppSpace.md,
                  runSpacing: AppSpace.sm,
                  children: [
                    _Pips(label: 'Tomorrow', count: coming.tomorrow, color: AppColors.orange),
                    _Pips(label: 'In 3 days', count: coming.in3, color: AppColors.teal),
                    _Pips(label: 'In 7 days', count: coming.in7, color: AppColors.green),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          ready ? 'Up to $session questions, about 2 minutes. Each right answer pays 5 XP and 1 coin.' : hint,
          style: t.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
    return Column(
      children: [
        Expanded(child: list),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
          child: ChunkyButton(label: 'Start review', onPressed: ready ? onStart : null, icon: Icons.play_arrow_rounded),
        ),
      ],
    );
  }
}

/// Label, a row of small round pips (one per item, up to 6) and the exact count.
class _Pips extends StatelessWidget {
  const _Pips({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $count',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label  $count', style: context.text.titleSmall),
        const SizedBox(height: 4),
        SizedBox(
          height: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < count ? color : AppColors.track,
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Session extends StatelessWidget {
  const _Session({required this.items, required this.results, required this.clock, required this.onAnswered});
  final List<Question> items;
  final List<bool> results;
  final AnimationController clock;
  final ValueChanged<bool> onAnswered;

  @override
  Widget build(BuildContext context) {
    final i = results.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, 8, AppSpace.md, 0),
          child: Row(
            children: [
              const _CloseButton(),
              Expanded(
                child: Semantics(
                  label: 'Question ${i + 1} of ${items.length}',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      for (var k = 0; k < items.length; k++)
                        Expanded(
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.ink, width: 2),
                              color: k < i
                                  ? (results[k] ? AppColors.green : AppColors.red)
                                  : k == i
                                  ? AppColors.yellow
                                  : AppColors.track,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, 2, AppSpace.md, AppSpace.sm),
          child: Semantics(
            label: 'Time left',
            child: AnimatedBuilder(
              animation: clock,
              builder: (_, _) => FatProgress(value: 1 - clock.value, color: AppColors.blue, height: 10),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.lg),
            child: QuestionView(question: items[i], onAnswered: onAnswered),
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.correct,
    required this.total,
    required this.graduated,
    required this.next,
    required this.xp,
    required this.coins,
  });
  final int correct, total, graduated, xp, coins;
  final String next;

  int get _stars {
    if (correct == total) return 3;
    if (correct * 5 >= total * 3) return 2;
    return correct > 0 ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    Widget row(String big, String small, Color color) => Row(
      children: [
        Container(
          width: 48,
          height: 40,
          alignment: Alignment.center,
          decoration: pieceDecoration(fill: color, radius: 12, depth: 3),
          child: Text(big, style: t.titleLarge!.copyWith(color: AppColors.on(color))),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Text(small, style: t.titleMedium)),
      ],
    );
    final back = total - graduated;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 8, AppSpace.md, AppSpace.sm),
      children: [
        const SizedBox(height: AppSpace.md),
        Center(child: _Medal(stars: _stars)),
        const SizedBox(height: AppSpace.md),
        Text('Review done', style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.md),
        PopIn.at(
          2,
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row('$correct/$total', 'answered correctly', AppColors.green),
                const SizedBox(height: AppSpace.sm),
                row('$graduated', 'learned for good', AppColors.yellow),
                const SizedBox(height: AppSpace.sm),
                row('${back < 0 ? 0 : back}', 'will come back', AppColors.blue),
                const SizedBox(height: AppSpace.sm),
                Text('Next review: $next', style: t.bodyLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Center(
          child: Wrap(
            spacing: AppSpace.sm,
            children: [
              StatPill(icon: Icons.bolt_rounded, value: '+$xp XP', color: AppColors.blue),
              StatPill(icon: Icons.monetization_on_rounded, value: '+$coins', color: AppColors.yellow),
            ],
          ),
        ),
      ],
    );
    return Column(
      children: [
        Expanded(child: list),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
          child: ChunkyButton(label: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        ),
      ],
    );
  }
}

/// A medal that drops in on a spring, with up to three stars lit.
class _Medal extends StatelessWidget {
  const _Medal({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    final medal = Semantics(
      label: '$stars of 3 stars',
      child: CustomPaint(size: const Size(150, 170), painter: _MedalPainter(stars)),
    );
    if (context.reduceMotion) return medal;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, -220 * (1 - v)),
        child: Transform.rotate(angle: 0.25 * (1 - v), child: child),
      ),
      child: medal,
    );
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter(this.stars);
  final int stars;

  static Path _star(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final o = c + Offset(cos(a), sin(a)) * rad;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;
    Paint fill(Color c) => Paint()..color = c;
    final cx = size.width / 2;
    // Ribbon tails.
    for (final (dx, color) in [(-22.0, AppColors.red), (22.0, AppColors.blue)]) {
      final tail = Path()
        ..moveTo(cx + dx - 16, 0)
        ..lineTo(cx + dx + 16, 0)
        ..lineTo(cx + dx + 16, 80)
        ..lineTo(cx + dx, 68)
        ..lineTo(cx + dx - 16, 80)
        ..close();
      canvas
        ..drawPath(tail, fill(color))
        ..drawPath(tail, ink);
    }
    final c = Offset(cx, 100);
    canvas
      ..drawCircle(c + const Offset(0, 5), 56, fill(AppColors.ink))
      ..drawCircle(c, 56, fill(AppColors.yellow))
      ..drawCircle(c, 56, ink)
      ..drawCircle(c, 42, ink);
    for (var i = 0; i < 3; i++) {
      final pos = c + Offset((i - 1) * 30.0, i == 1 ? -4 : 6);
      final r = i == 1 ? 17.0 : 13.0;
      final path = _star(pos, r);
      canvas
        ..drawPath(path, fill(i < stars ? AppColors.card : AppColors.paperDeep))
        ..drawPath(path, ink..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.stars != stars;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/entities/question.dart';
import '../content/question_view.dart';
import 'streak_logic.dart';

const freezePrice = 60;
const _repairAnswers = 3;
const _pips = 5;

/// Streak, next milestone, freeze and repair.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final open = repairOpen(p, dayKey(DateTime.now()));
    final next = nextMilestone(p.streak, p.milestonesDone);
    return PopIn(
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (open) ...[_RepairPanel(lost: p.lostStreak), const SizedBox(height: AppSpace.md)],
            Semantics(
              label: '${p.streak} day streak',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 64,
                    child: CustomPaint(painter: FlamePainter(lit: p.streak > 0)),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CountUp(value: p.streak, style: context.text.displaySmall),
                        Text('day streak', style: context.text.titleSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            _MilestoneRow(streak: p.streak, next: next, done: p.milestonesDone),
            const SizedBox(height: AppSpace.md),
            _FreezeRow(coins: p.coins, held: p.streakFreezes > 0),
          ],
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.streak, required this.next, required this.done});
  final int streak;
  final int? next;
  final Set<int> done;

  @override
  Widget build(BuildContext context) {
    final n = next;
    if (n == null) return Text('Every streak reward collected.', style: context.text.bodyMedium);
    // Progress runs from the last milestone reached (or 0) to the next one.
    final base = streakMilestones.keys.where((m) => m <= streak).fold(0, math.max);
    final filled = ((streak - base) / (n - base) * _pips).floor().clamp(0, _pips - 1);
    final text = 'Next reward at $n days: ${streakMilestones[n]} chest';
    return Semantics(
      label: '$text, $filled of $_pips steps',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: context.text.titleSmall),
          const SizedBox(height: AppSpace.sm),
          Pips(filled: filled, total: _pips, color: AppColors.orange),
        ],
      ),
    );
  }
}

/// A row of chunky progress pips.
class Pips extends StatelessWidget {
  const Pips({super.key, required this.filled, required this.total, this.color = AppColors.green});
  final int filled, total;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < total; i++)
        Expanded(
          child: Container(
            height: 16,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: pieceDecoration(fill: i < filled ? color : AppColors.track, radius: 8, depth: 0),
          ),
        ),
    ],
  );
}

class _FreezeRow extends ConsumerWidget {
  const _FreezeRow({required this.coins, required this.held});
  final int coins;
  final bool held;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canBuy = !held && coins >= freezePrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: pieceDecoration(fill: held ? AppColors.blue : AppColors.paperDeep, radius: 12, depth: 0),
              child: CustomPaint(painter: SnowflakePainter(color: held ? AppColors.card : AppColors.inkDim)),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(held ? 'Freeze ready' : 'No freeze', style: context.text.titleMedium),
                  Text('Forgives one missed day', style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        ChunkyButton(
          label: 'Buy a freeze ($freezePrice coins)',
          color: AppColors.yellow,
          onPressed: canBuy
              ? () {
                  final n = ref.read(profileProvider.notifier);
                  if (!n.spend(freezePrice)) return;
                  n.mutate((p) => p.copyWith(streakFreezes: 1));
                  Sound.play(Sfx.powerup);
                  Haptics.medium();
                }
              : null,
        ),
      ],
    );
  }
}

class _RepairPanel extends StatelessWidget {
  const _RepairPanel({required this.lost});
  final int lost;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: pieceDecoration(fill: AppColors.red, radius: 14, depth: 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Streak lost: repair it', style: context.text.titleLarge!.copyWith(color: AppColors.card)),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Answer $_repairAnswers questions right to bring back your $lost day streak.',
          style: context.text.titleSmall!.copyWith(color: AppColors.card),
        ),
        const SizedBox(height: AppSpace.sm),
        ChunkyButton(
          label: 'Repair',
          color: AppColors.yellow,
          icon: Icons.build_rounded,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.card,
            showDragHandle: true,
            builder: (_) => const RepairSheet(),
          ),
        ),
      ],
    ),
  );
}

/// Three right answers in a row of quick questions restore the lost streak. Wrong answers just bring a new question.
class RepairSheet extends ConsumerStatefulWidget {
  const RepairSheet({super.key});

  @override
  ConsumerState<RepairSheet> createState() => _RepairSheetState();
}

class _RepairSheetState extends ConsumerState<RepairSheet> {
  List<Question>? _pool;
  int _asked = 0, _right = 0;
  int? _restored;

  Question? _question(Content c) {
    final pool = _pool ??= ([...c.quickQuestions]..shuffle());
    return pool.isEmpty ? null : pool[_asked % pool.length];
  }

  void _answered(Question q, bool correct) {
    final n = ref.read(profileProvider.notifier)..noteAnswer(q, correct);
    if (correct && _right + 1 >= _repairAnswers) {
      if (n.repairStreak()) {
        Sound.play(Sfx.levelUp);
        Haptics.heavy();
        setState(() => _restored = ref.read(profileProvider).streak);
      } else {
        Navigator.pop(context);
      }
      return;
    }
    setState(() {
      _asked++;
      if (correct) _right++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider).value;
    final q = content == null ? null : _question(content);
    final Widget body;
    if (_restored != null) {
      body = _Celebration(streak: _restored!, onDone: () => Navigator.pop(context));
    } else if (q == null) {
      body = Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Text('No questions available right now.', style: context.text.titleMedium),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: '$_right of $_repairAnswers correct',
            excludeSemantics: true,
            child: Pips(filled: _right, total: _repairAnswers, color: AppColors.green),
          ),
          const SizedBox(height: AppSpace.md),
          KeyedSubtree(
            key: ValueKey(_asked),
            child: QuestionView(question: q, compact: true, onAnswered: (c) => _answered(q, c)),
          ),
        ],
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: body,
      ),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.streak, required this.onDone});
  final int streak;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => PopIn(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(width: 84, height: 96, child: CustomPaint(painter: FlamePainter(lit: true))),
        ),
        const SizedBox(height: AppSpace.sm),
        Text('Streak restored!', textAlign: TextAlign.center, style: context.text.headlineSmall),
        Text('$streak day streak is back', textAlign: TextAlign.center, style: context.text.bodyLarge),
        const SizedBox(height: AppSpace.md),
        ChunkyButton(label: 'Keep going', onPressed: onDone),
      ],
    ),
  );
}

/// A flame: outer orange body, inner yellow tongue, ink outline. Grey when the streak is dead.
class FlamePainter extends CustomPainter {
  const FlamePainter({required this.lit});
  final bool lit;

  static Path _flame(double w, double h, double inset) {
    final cx = w / 2;
    return Path()
      ..moveTo(cx, h * (0.02 + inset * 0.5))
      ..cubicTo(cx + w * 0.10, h * 0.25, w * (0.98 - inset), h * 0.42, w * (0.92 - inset), h * 0.68)
      ..cubicTo(w * (0.88 - inset), h * 0.90, cx + w * 0.22, h * (0.98 - inset * 0.3), cx, h * (0.98 - inset * 0.3))
      ..cubicTo(cx - w * 0.22, h * (0.98 - inset * 0.3), w * (0.12 + inset), h * 0.90, w * (0.08 + inset), h * 0.68)
      ..cubicTo(w * (0.04 + inset), h * 0.50, w * 0.28, h * 0.42, w * 0.34, h * 0.26)
      ..cubicTo(w * 0.40, h * 0.34, w * 0.44, h * 0.30, cx, h * (0.02 + inset * 0.5))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final outer = _flame(w, h, 0);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.fill
        ..color = lit ? AppColors.orange : AppColors.track,
    );
    final inner = Matrix4.identity()
      ..translateByDouble(w * 0.5, h * 0.98, 0, 1)
      ..scaleByDouble(0.52, 0.52, 1, 1)
      ..translateByDouble(-w * 0.5, -h * 0.98, 0, 1);
    canvas.drawPath(
      _flame(w, h, 0).transform(inner.storage),
      Paint()
        ..style = PaintingStyle.fill
        ..color = lit ? AppColors.yellow : AppColors.paperDeep,
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSpace.outline
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(FlamePainter old) => old.lit != lit;
}

/// Six-armed snowflake with side twigs.
class SnowflakePainter extends CustomPainter {
  const SnowflakePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.34;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final dir = Offset(math.cos(a), math.sin(a));
      final tip = c + dir * r;
      canvas.drawLine(c, tip, paint);
      final mid = c + dir * (r * 0.62);
      for (final s in [-1, 1]) {
        final b = a + s * math.pi / 4;
        canvas.drawLine(mid, mid + Offset(math.cos(b), math.sin(b)) * (r * 0.32), paint);
      }
    }
  }

  @override
  bool shouldRepaint(SnowflakePainter old) => old.color != color;
}

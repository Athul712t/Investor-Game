import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/progress.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'quest_logic.dart';

Color _tierColor(QuestTier t) => switch (t) {
  QuestTier.easy => AppColors.green,
  QuestTier.medium => AppColors.blue,
  QuestTier.hard => AppColors.orange,
};

/// Today's three quests on Home: progress comes from the day's counters, the player claims each reward.
class QuestsCard extends ConsumerStatefulWidget {
  const QuestsCard({super.key});

  @override
  ConsumerState<QuestsCard> createState() => _QuestsCardState();
}

class _QuestsCardState extends ConsumerState<QuestsCard> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Rollover and pulse start/stop touch state, so they run after the frame, never during build.
  void _afterBuild(String today, bool pulsing) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cur = ref.read(profileProvider).quests;
      final rolled = rolledQuests(cur, today);
      if (!identical(rolled, cur)) ref.read(profileProvider.notifier).mutate((p) => p.copyWith(quests: rolled));
      if (pulsing && !context.reduceMotion) {
        if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      } else if (_pulse.isAnimating) {
        _pulse.stop();
      }
    });
  }

  void _claim(Quest q) {
    final n = ref.read(profileProvider.notifier);
    final p = ref.read(profileProvider);
    final day = dayKey(DateTime.now());
    final c = claimQuest(p.quests, q.id, p.statsFor(day), day);
    if (c == null) return; // already claimed or not complete: a double tap pays nothing
    n.mutate((p) => p.copyWith(quests: c.state)); // synchronous, so a second tap sees it claimed
    n.reward(xp: q.xp, coins: q.coins);
    Sound.play(Sfx.coin);
    Haptics.medium();
    if (c.chest) {
      n.grantChest('silver');
      Sound.play(Sfx.levelUp);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(profileProvider.select((p) => (p.quests, p.dayStats)));
    final p = ref.read(profileProvider);
    final now = DateTime.now();
    final today = dayKey(now);
    final state = rolledQuests(p.quests, today);
    final stats = p.statsFor(today);
    final quests = [for (final id in (state['ids'] as List)) questById('$id')!];
    final claimed = claimedOf(state);
    final done = claimed.length;
    final pulsing = quests.any((q) => q.isComplete(stats) && !claimed.contains(q.id));
    _afterBuild(today, pulsing);

    return PopIn(
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily quests', style: context.text.titleLarge),
            const SizedBox(height: AppSpace.xs),
            Wrap(
              spacing: AppSpace.md,
              children: [
                Text('$done of 3 done', style: context.text.titleSmall),
                Text('resets in ${resetsIn(now)}', style: context.text.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            for (final q in quests)
              _QuestRow(
                quest: q,
                stats: stats,
                claimed: claimed.contains(q.id),
                pulse: _pulse,
                onClaim: () => _claim(q),
              ),
            const SizedBox(height: AppSpace.xs),
            _ChestRow(earned: done == 3),
          ],
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.quest,
    required this.stats,
    required this.claimed,
    required this.pulse,
    required this.onClaim,
  });
  final Quest quest;
  final DayStats stats;
  final bool claimed;
  final Animation<double> pulse;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(quest.tier);
    final have = quest.progress(stats);
    final complete = quest.isComplete(stats);
    final status = claimed ? 'claimed' : (complete ? 'complete, ready to claim' : '$have of ${quest.target}');
    final reward = '+${quest.coins} coins, +${quest.xp} XP';
    return Semantics(
      container: true,
      label: '${quest.text}, ${quest.tier.name} quest, $status, reward ${reward.replaceAll('+', '')}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.tint(color, 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: CustomPaint(painter: _KindPainter(quest.kind, color)),
              ),
            ),
            const SizedBox(width: AppSpace.sm + 2),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest.text, style: context.text.labelLarge),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: FatProgress(value: have / quest.target, color: color, height: 12),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text('$have/${quest.target}', style: context.text.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(reward, style: context.text.labelSmall),
                  ],
                ),
              ),
            ),
            if (claimed || complete) ...[
              const SizedBox(width: AppSpace.sm),
              if (claimed)
                Semantics(
                  label: 'Claimed',
                  excludeSemantics: true,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: CustomPaint(size: Size(32, 32), painter: _DonePainter()),
                    ),
                  ),
                )
              else
                AnimatedBuilder(
                  animation: pulse,
                  builder: (_, child) =>
                      Transform.scale(scale: 1 + 0.07 * Curves.easeInOut.transform(pulse.value), child: child),
                  child: Pressable(
                    label: 'Claim ${quest.text}',
                    onTap: onClaim,
                    builder: (context, down) => ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 68, minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 60),
                          transform: Matrix4.translationValues(0, down ? 4 : 0, 0),
                          alignment: Alignment.center,
                          constraints: const BoxConstraints(minWidth: 68, minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: pieceDecoration(fill: color, radius: 12, depth: down ? 0 : 4),
                          child: Text('Claim', style: context.text.labelLarge!.copyWith(color: AppColors.on(color))),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChestRow extends StatelessWidget {
  const _ChestRow({required this.earned});
  final bool earned;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: earned ? 'Silver chest earned' : 'Finish all 3 quests for a silver chest',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm + 2, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: earned ? AppColors.tint(AppColors.yellow, 0.6) : AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, height: 34, child: CustomPaint(painter: _ChestPainter(earned))),
          const SizedBox(width: AppSpace.sm + 2),
          Expanded(
            child: Text(
              earned ? 'Silver chest earned' : 'Finish all 3 for a silver chest',
              style: context.text.labelLarge!.copyWith(color: earned ? AppColors.ink : AppColors.inkDim),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Quest pictograms on a 44x44 grid: ink strokes, tier colour fills.
class _KindPainter extends CustomPainter {
  _KindPainter(this.kind, this.color);
  final QuestKind kind;
  final Color color;

  final _ink = Paint()
    ..color = AppColors.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final _fill = Paint()..style = PaintingStyle.fill;

  void _shape(Canvas c, Path path, Color fill) {
    c.drawPath(path, _fill..color = fill);
    c.drawPath(path, _ink);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44;
    canvas.save();
    canvas.scale(s);
    switch (kind) {
      case QuestKind.controller:
        _shape(
          canvas,
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(7, 14, 30, 17), const Radius.circular(8))),
          AppColors.card,
        );
        canvas.drawLine(const Offset(14, 22.5), const Offset(20, 22.5), _ink);
        canvas.drawLine(const Offset(17, 19.5), const Offset(17, 25.5), _ink);
        canvas.drawCircle(const Offset(26.5, 24), 2.3, _fill..color = color);
        canvas.drawCircle(const Offset(26.5, 24), 2.3, _ink);
        canvas.drawCircle(const Offset(31.5, 20.5), 2.3, _fill..color = AppColors.yellow);
        canvas.drawCircle(const Offset(31.5, 20.5), 2.3, _ink);
      case QuestKind.cards:
        canvas.save();
        canvas.translate(17, 22);
        canvas.rotate(-0.22);
        _shape(
          canvas,
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -11, 16, 22), const Radius.circular(3))),
          AppColors.card,
        );
        canvas.restore();
        canvas.save();
        canvas.translate(26, 22);
        canvas.rotate(0.2);
        _shape(
          canvas,
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -11, 16, 22), const Radius.circular(3))),
          color,
        );
        canvas.drawLine(const Offset(-3, -4), const Offset(3, -4), _ink);
        canvas.drawLine(const Offset(-3, 1), const Offset(3, 1), _ink);
        canvas.restore();
      case QuestKind.check:
        canvas.drawCircle(const Offset(22, 22), 12, _fill..color = AppColors.card);
        canvas.drawCircle(const Offset(22, 22), 12, _ink);
        canvas.drawPath(
          Path()
            ..moveTo(16, 22.5)
            ..lineTo(20.5, 27)
            ..lineTo(28.5, 17),
          _ink
            ..strokeWidth = 3.4
            ..color = AppColors.ink,
        );
      case QuestKind.lesson:
        _shape(
          canvas,
          Path()
            ..moveTo(22, 15)
            ..quadraticBezierTo(15, 11, 7, 13)
            ..lineTo(7, 31)
            ..quadraticBezierTo(15, 29, 22, 33)
            ..quadraticBezierTo(29, 29, 37, 31)
            ..lineTo(37, 13)
            ..quadraticBezierTo(29, 11, 22, 15)
            ..close(),
          AppColors.card,
        );
        canvas.drawLine(const Offset(22, 15), const Offset(22, 33), _ink);
        canvas.drawLine(const Offset(11, 18), const Offset(18, 19), _ink);
        canvas.drawLine(const Offset(11, 23), const Offset(18, 24), _ink);
      case QuestKind.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 14.0 : 6.2;
          final a = -math.pi / 2 + i * math.pi / 5;
          final pt = Offset(22 + r * math.cos(a), 23 + r * math.sin(a));
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        _shape(canvas, path..close(), AppColors.yellow);
    }
    canvas.restore();
    _ink.strokeWidth = 2.2;
  }

  @override
  bool shouldRepaint(_KindPainter old) => old.kind != kind || old.color != color;
}

class _DonePainter extends CustomPainter {
  const _DonePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width / 2 - 1.5, Paint()..color = AppColors.green);
    canvas.drawCircle(
      c,
      size.width / 2 - 1.5,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.28, size.height * 0.52)
        ..lineTo(size.width * 0.44, size.height * 0.67)
        ..lineTo(size.width * 0.72, size.height * 0.34),
      Paint()
        ..color = AppColors.card
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Small chest: silver when [earned], a dull locked one with a padlock otherwise.
class _ChestPainter extends CustomPainter {
  _ChestPainter(this.earned);
  final bool earned;

  final _ink = Paint()
    ..color = AppColors.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeJoin = StrokeJoin.round;
  final _fill = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final body = earned ? AppColors.tint(AppColors.inkDim, 0.7) : AppColors.track;
    final lid = earned ? AppColors.tint(AppColors.inkDim, 0.45) : AppColors.tint(AppColors.track, 0.2);
    canvas.save();
    canvas.scale(size.width / 40, size.height / 34);
    final base = RRect.fromRectAndRadius(const Rect.fromLTWH(3, 14, 34, 18), const Radius.circular(3));
    final top = Path()
      ..moveTo(3, 14)
      ..lineTo(3, 10)
      ..quadraticBezierTo(20, -1, 37, 10)
      ..lineTo(37, 14)
      ..close();
    canvas.drawRRect(base, _fill..color = body);
    canvas.drawRRect(base, _ink);
    canvas.drawPath(top, _fill..color = lid);
    canvas.drawPath(top, _ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(16, 11, 8, 10), const Radius.circular(2)),
      _fill..color = earned ? AppColors.yellow : AppColors.inkDim,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(16, 11, 8, 10), const Radius.circular(2)), _ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChestPainter old) => old.earned != earned;
}

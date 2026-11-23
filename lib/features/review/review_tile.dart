import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../home_hub/loop_tile.dart';
import 'review_logic.dart';
import 'review_screen.dart';

/// Home tile: a clock with a loop arrow, how many reviews are due. Pulses while something is due.
class ReviewTile extends ConsumerWidget {
  const ReviewTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(reviewQuestionsProvider).keys.toSet();
    final due = ref.watch(profileProvider.select((p) => dueCount(p.review, ids, dayKey(DateTime.now()))));
    return LoopTile(
      color: AppColors.blue,
      picto: const ReviewPicto(size: 40),
      title: 'Review',
      status: due > 0 ? '$due due' : 'All caught up',
      pulse: due > 0,
      onTap: () => context.push('/review'),
    );
  }
}

/// A clock with a loop arrow around it, drawn in code.
class ReviewPicto extends StatelessWidget {
  const ReviewPicto({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: const _PictoPainter()),
  );
}

class _PictoPainter extends CustomPainter {
  const _PictoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = size.center(Offset.zero);
    final line = s * 0.07;
    Paint stroke(Color color, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // Loop arrow: 270 degrees clockwise around the clock, ink under green.
    final r = s * 0.42;
    const a0 = -pi / 2 + 0.55, sweep = pi * 1.45;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, a0, sweep, false, stroke(AppColors.ink, line * 2.6));
    canvas.drawArc(rect, a0, sweep, false, stroke(AppColors.green, line * 1.3));
    final a1 = a0 + sweep;
    final end = c + Offset(cos(a1), sin(a1)) * r;
    final tan = Offset(-sin(a1), cos(a1)), rad = Offset(cos(a1), sin(a1));
    final head = Path()
      ..moveTo((end + tan * s * 0.16).dx, (end + tan * s * 0.16).dy)
      ..lineTo((end + rad * s * 0.13).dx, (end + rad * s * 0.13).dy)
      ..lineTo((end - rad * s * 0.13).dx, (end - rad * s * 0.13).dy)
      ..close();
    canvas.drawPath(head, stroke(AppColors.ink, line));
    canvas.drawPath(head, Paint()..color = AppColors.green);

    // Clock face and hands.
    final face = s * 0.25;
    canvas.drawCircle(c, face, Paint()..color = AppColors.card);
    canvas.drawCircle(c, face, stroke(AppColors.ink, line));
    final hands = stroke(AppColors.ink, line * 0.9);
    canvas.drawLine(c, c + Offset(0, -face * 0.62), hands);
    canvas.drawLine(c, c + Offset(face * 0.45, face * 0.2), hands);
  }

  @override
  bool shouldRepaint(_PictoPainter old) => false;
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../content/question_view.dart';

/// One question a day, the same for everyone on that date.
class DailyCard extends ConsumerWidget {
  const DailyCard({super.key});
  static const xp = 15, coins = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayKey(DateTime.now());
    final done = ref.watch(profileProvider.select((p) => p.dailyDoneDay)) == today;
    final question = ref.watch(contentProvider).value?.randomQuick(Random(today.hashCode));
    if (question == null) return const SizedBox.shrink();
    final stub = done ? AppColors.green : AppColors.red;
    return Semantics(
      container: true,
      child: CustomPaint(
        painter: _TicketPainter(stub: stub),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.depth),
          child: Row(
            children: [
              SizedBox(
                width: _TicketPainter.stubWidth,
                child: Center(
                  child: ExcludeSemantics(
                    child: OutlinedText(done ? '✓' : '?', stroke: 6, style: context.text.displaySmall),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.md, 14, AppSpace.md, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TODAY ONLY',
                              style: context.text.labelSmall!.copyWith(letterSpacing: 1.5, color: stub),
                            ),
                            Text('Daily question', style: context.text.titleLarge),
                            Text(
                              done ? 'Done for today. Come back tomorrow!' : 'One answer a day. +$xp XP, +$coins coins',
                              style: context.text.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (!done)
                        ChunkyButton(
                          label: 'Go',
                          expand: false,
                          color: AppColors.red,
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: AppColors.card,
                            showDragHandle: true,
                            builder: (sheet) => SafeArea(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  AppSpace.lg,
                                  0,
                                  AppSpace.lg,
                                  AppSpace.lg + MediaQuery.viewInsetsOf(sheet).bottom,
                                ),
                                child: QuestionView(
                                  question: question,
                                  compact: true,
                                  onAnswered: (correct) {
                                    final n = ref.read(profileProvider.notifier)..markDailyDone();
                                    // Wrong answers still earn a little: showing up is the habit.
                                    n.reward(xp: correct ? xp : 5, coins: correct ? coins : 0);
                                    Navigator.pop(sheet);
                                  },
                                ),
                              ),
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
      ),
    );
  }
}

/// Ticket stub: solid card with a coloured stub, two half-moon notches and a dashed tear line.
class _TicketPainter extends CustomPainter {
  _TicketPainter({required this.stub});
  final Color stub;
  static const stubWidth = 76.0, notch = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width, size.height - AppSpace.depth);
    final outline = Path.combine(
      PathOperation.difference,
      Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(AppSpace.radius))),
      Path()
        ..addOval(Rect.fromCircle(center: Offset(stubWidth, 0), radius: notch))
        ..addOval(Rect.fromCircle(center: Offset(stubWidth, body.height), radius: notch)),
    );
    final ink = Paint()..color = AppColors.ink;
    canvas.drawPath(outline.shift(const Offset(0, AppSpace.depth)), ink); // hard shadow
    canvas.drawPath(outline, Paint()..color = AppColors.card);
    canvas
      ..save()
      ..clipPath(outline)
      ..drawRect(Rect.fromLTRB(0, 0, stubWidth, body.height), Paint()..color = stub)
      ..restore();
    for (var y = notch + 5; y < body.height - notch - 5; y += 10) {
      canvas.drawRect(Rect.fromLTWH(stubWidth - 1.25, y, 2.5, 5), ink);
    }
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSpace.outline
        ..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(_TicketPainter old) => old.stub != stub;
}

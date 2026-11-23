import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// The "Daily reminder" row in Profile: opt in to one local notification a day.
class NotifySection extends ConsumerWidget {
  const NotifySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final on = p.notify;
    final hours = p.hours;
    final subtitle = !on
        ? 'Off'
        : hours.any((h) => h > 0)
        ? 'At ${hourLabel(usualHour(hours))}, about when you usually play'
        : 'At ${hourLabel(usualHour(hours))}, a good time for a minute of play';

    Future<void> flip() async {
      final notifier = ref.read(profileProvider.notifier);
      if (on) {
        notifier.mutate((s) => s.copyWith(notify: false));
      } else {
        final granted = await ref.read(reminderSchedulerProvider).requestPermission();
        if (!granted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No problem. You can allow notifications in your phone settings later.')),
            );
          }
          return;
        }
        notifier.mutate((s) => s.copyWith(notify: true));
      }
      await ref.read(reminderServiceProvider).sync();
    }

    return Semantics(
      toggled: on,
      label: 'Daily reminder, $subtitle',
      excludeSemantics: true,
      onTap: flip,
      child: Pressable(
        onTap: flip,
        builder: (_, _) => Container(
          margin: const EdgeInsets.only(bottom: AppSpace.depth),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 12),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: pieceDecoration(),
          child: Row(
            children: [
              CustomPaint(size: const Size.square(24), painter: _BellPainter(on)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily reminder', style: context.text.titleMedium),
                    Text(subtitle, style: context.text.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: AppMotion.fast,
                width: 58,
                height: 32,
                padding: const EdgeInsets.all(3),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                decoration: pieceDecoration(fill: on ? AppColors.green : AppColors.track, radius: 999, depth: 0),
                child: Container(width: 22, height: 22, decoration: pieceDecoration(radius: 999, depth: 0)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellPainter extends CustomPainter {
  const _BellPainter(this.on);
  final bool on;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = Path()
      ..moveTo(w * .18, h * .78)
      ..quadraticBezierTo(w * .26, h * .66, w * .26, h * .42)
      ..cubicTo(w * .26, h * .16, w * .74, h * .16, w * .74, h * .42)
      ..quadraticBezierTo(w * .74, h * .66, w * .82, h * .78)
      ..close();
    final fill = Paint()..color = on ? AppColors.yellow : AppColors.track;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;
    canvas.drawCircle(Offset(w * .5, h * .14), w * .07, Paint()..color = AppColors.ink);
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);
    canvas.drawCircle(Offset(w * .5, h * .88), w * .09, fill);
    canvas.drawCircle(Offset(w * .5, h * .88), w * .09, line);
  }

  @override
  bool shouldRepaint(_BellPainter old) => old.on != on;
}

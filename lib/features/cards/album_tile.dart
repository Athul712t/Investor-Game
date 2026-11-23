import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'cards_data.dart';
import 'cards_logic.dart';

/// Home tile: a painted stack of cards, "Album" and "x / N".
class AlbumTile extends ConsumerWidget {
  const AlbumTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider).value ?? const <CardDef>[];
    final got = unlockedIds(cards, ref.watch(profileProvider)).length;
    return Panel(
      onTap: () => context.push('/album'),
      child: Row(
        children: [
          ExcludeSemantics(
            child: CustomPaint(size: const Size(44, 48), painter: const _StackPainter()),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Album', style: context.text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$got / ${cards.length}', style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three tilted cards fanned out.
class _StackPainter extends CustomPainter {
  const _StackPainter();

  static const _fills = [AppColors.green, AppColors.blue, AppColors.yellow];

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.56);
      canvas.rotate((i - 1) * 0.3);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 26, height: 36),
        const Radius.circular(5),
      );
      canvas.drawRRect(r, Paint()..color = _fills[i]);
      canvas.drawRRect(r, stroke);
      if (i == 2) canvas.drawCircle(const Offset(0, -2), 5, Paint()..color = AppColors.card);
      if (i == 2) canvas.drawCircle(const Offset(0, -2), 5, stroke..strokeWidth = 2);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StackPainter old) => false;
}

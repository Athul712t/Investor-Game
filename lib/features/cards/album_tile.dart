import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../home_hub/loop_tile.dart';
import 'cards_data.dart';
import 'cards_logic.dart';

/// Home tile: a painted stack of cards, "Album" and how many are collected.
class AlbumTile extends ConsumerWidget {
  const AlbumTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider).value;
    final got = ref.watch(profileProvider.select((p) => cards == null ? 0 : unlockedIds(cards, p).length));
    return LoopTile(
      color: AppColors.teal,
      picto: const CustomPaint(painter: _StackPainter()),
      title: 'Album',
      status: cards == null ? 'Loading' : '$got of ${cards.length}',
      onTap: () => context.push('/album'),
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
      canvas.translate(size.width / 2, size.height * 0.54);
      canvas.rotate((i - 1) * 0.3);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: size.width * 0.56, height: size.height * 0.78),
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

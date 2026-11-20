import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Small outlined label at the top of a reel card.
class ReelTag extends StatelessWidget {
  const ReelTag(this.label, {super.key, this.color = AppColors.card});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: pieceDecoration(fill: color, radius: 999, depth: 2),
    child: Text(label, style: context.text.labelLarge!.copyWith(color: AppColors.on(color))),
  );
}

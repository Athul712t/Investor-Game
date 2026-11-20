import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../reel_item.dart';

/// Placeholder. Replaced by the real card; keep this constructor.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.item, required this.active, required this.onDone});
  final ReelGame item;

  /// True only while this card is the one on screen. Do nothing heavy until then.
  final bool active;

  /// Call exactly once when the player may scroll on.
  final ReelDone onDone;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.id, style: context.text.titleLarge),
        const SizedBox(height: AppSpace.md),
        ChunkyButton(label: 'Done', expand: false, onPressed: active ? () => onDone(correct: true) : null),
      ],
    ),
  );
}

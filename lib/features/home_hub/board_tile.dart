import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// A solid colour board tile: leans toward the finger and sinks on touch-down.
class BoardTile extends StatelessWidget {
  const BoardTile({
    super.key,
    required this.fill,
    required this.onTap,
    required this.child,
    this.label,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });
  final Color fill;
  final VoidCallback onTap;
  final Widget child;
  final String? label;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Tilt3D(
    maxDegrees: 6,
    child: Pressable(
      onTap: onTap,
      label: label,
      builder: (_, down) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.depth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: Matrix4.translationValues(0, down ? AppSpace.depth : 0, 0),
          padding: padding,
          decoration: pieceDecoration(fill: fill, depth: down ? 0 : AppSpace.depth),
          child: child,
        ),
      ),
    ),
  );
}

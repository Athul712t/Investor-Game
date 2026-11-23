import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'chest_art.dart';
import 'chest_logic.dart';

/// Home tile: a painted chest and how many are waiting. Pulses gently when there is something to open.
class ChestsTile extends ConsumerStatefulWidget {
  const ChestsTile({super.key});

  @override
  ConsumerState<ChestsTile> createState() => _ChestsTileState();
}

class _ChestsTileState extends ConsumerState<ChestsTile> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chests = ref.watch(profileProvider.select((p) => p.chests));
    final n = chests.length;
    final type = chests.isEmpty
        ? ChestType.wood
        : ChestType.values.lastWhere((t) => chests.contains(t.name), orElse: () => ChestType.wood);
    final pulsing = n > 0 && !context.reduceMotion;
    if (pulsing && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!pulsing && _pulse.isAnimating) _pulse.stop();
    final label = n == 0 ? 'None yet' : '$n to open';
    return Semantics(
      label: 'Chests, $label',
      excludeSemantics: true,
      button: true,
      onTap: () => context.push('/chests'),
      child: Panel(
        onTap: () => context.push('/chests'),
        fill: n == 0 ? AppColors.card : AppColors.tint(AppColors.yellow, 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                child: SizedBox(width: 72, height: 62, child: CustomPaint(painter: ChestPicto(type))),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text('Chests', style: context.text.titleLarge),
            const SizedBox(height: AppSpace.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: pieceDecoration(fill: n == 0 ? AppColors.paperDeep : AppColors.green, radius: 999, depth: 0),
              child: Text(
                label,
                style: context.text.labelLarge!.copyWith(
                  color: AppColors.on(n == 0 ? AppColors.paperDeep : AppColors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../home_hub/loop_tile.dart';
import 'chest_art.dart';
import 'chest_logic.dart';

/// Home tile: a painted chest and how many are waiting. Pulses while there is something to open.
class ChestsTile extends ConsumerWidget {
  const ChestsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chests = ref.watch(profileProvider.select((p) => p.chests));
    final n = chests.length;
    final type = ChestType.values.lastWhere((t) => chests.contains(t.name), orElse: () => ChestType.wood);
    return LoopTile(
      color: AppColors.orange,
      picto: CustomPaint(painter: ChestPicto(type)),
      title: 'Chests',
      status: n == 0 ? 'None yet' : '$n to open',
      pulse: n > 0,
      onTap: () => context.push('/chests'),
    );
  }
}

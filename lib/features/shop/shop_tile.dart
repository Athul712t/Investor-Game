import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../home_hub/loop_tile.dart';
import 'shop_art.dart';

/// Home tile: a painted market stall, the word Shop and the coin balance. Opens /shop.
class ShopTile extends ConsumerWidget {
  const ShopTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(profileProvider.select((p) => p.coins));
    return LoopTile(
      color: AppColors.yellow,
      picto: const CustomPaint(painter: StallPainter()),
      title: 'Shop',
      status: '$coins coins',
      onTap: () => context.push('/shop'),
    );
  }
}

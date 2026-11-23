import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../home_hub/board_tile.dart';
import 'shop_art.dart';

/// Home tile: a painted market stall, the word Shop and the coin balance. Opens /shop.
class ShopTile extends ConsumerWidget {
  const ShopTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(profileProvider.select((p) => p.coins));
    return BoardTile(
      fill: AppColors.yellow,
      onTap: () => context.push('/shop'),
      label: 'Shop. You have $coins coins.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CustomPaint(size: const Size.square(44), painter: const StallPainter()),
          ),
          const SizedBox(height: AppSpace.sm),
          Text('Shop', style: context.text.headlineMedium),
          const SizedBox(height: 2),
          ExcludeSemantics(
            child: Row(
              children: [
                const Coin3D(size: 18, spin: false),
                const SizedBox(width: 6),
                Flexible(
                  child: CountUp(value: coins, style: context.text.titleLarge!.copyWith(fontSize: 17)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../cards/album_tile.dart';
import '../chests/chests_tile.dart';
import '../quests/quests_card.dart';
import '../review/review_tile.dart';
import '../shop/shop_tile.dart';
import '../streak/streak_card.dart';

/// The v1.5 retention loop on Home: quests, streak, and four tiles (chests, album, review, shop).
/// Each piece lives in its own feature folder; this file only lays them out.
class LoopSection extends StatelessWidget {
  const LoopSection({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Today', style: context.text.titleLarge),
      const SizedBox(height: AppSpace.sm),
      const QuestsCard(),
      const SizedBox(height: AppSpace.md),
      const StreakCard(),
      const SizedBox(height: AppSpace.md),
      const _TileRow(ChestsTile(), AlbumTile()),
      const SizedBox(height: AppSpace.md),
      const _TileRow(ReviewTile(), ShopTile()),
    ],
  );
}

/// Two loop tiles side by side, always the same height (the taller one's).
class _TileRow extends StatelessWidget {
  const _TileRow(this.left, this.right);
  final Widget left, right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpace.md),
        Expanded(child: right),
      ],
    ),
  );
}

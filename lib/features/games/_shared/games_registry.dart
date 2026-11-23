import 'package:flutter/material.dart';

import '../../../core/profile.dart';
import '../../../core/theme.dart';
import '../../../domain/game/game_types.dart';
import '../breaker/breaker_game.dart';
import '../candle/candle_game.dart';
import '../dunk/dunk_game.dart';
import '../flap/flap_game.dart';
import '../lock/lock_game.dart';
import '../merge/merge_game.dart';
import '../runner/runner_game.dart';
import '../slice/slice_game.dart';
import '../sort/sort_game.dart';
import '../stack/stack_game.dart';
import '../whack/whack_game.dart';
import 'arcade_game.dart';

class GameSpec {
  const GameSpec({
    required this.id,
    required this.title,
    required this.tagline,
    required this.howTo,
    required this.emoji,
    required this.color,
    required this.create,
  });
  final String id, title, tagline, howTo, emoji;
  final Color color;
  final ArcadeGame Function(GameConfig) create;

  /// Bronze, silver and gold score targets (ascending).
  List<int> get levels => masteryTargets[id]!;
}

/// Mastery score targets per game: the one place to tune them.
const masteryTargets = <String, List<int>>{
  'runner': [300, 800, 1500],
  'stack': [10, 25, 45],
  'merge': [500, 2000, 6000],
  'breaker': [400, 1500, 4000],
  'flap': [8, 20, 40],
  'slice': [40, 120, 300],
  'lock': [10, 25, 45],
  'sort': [15, 30, 50],
  'whack': [15, 35, 60],
  'candle': [2000, 3200, 4200],
  'dunk': [3, 8, 15],
};

const masteryNames = ['Bronze', 'Silver', 'Gold'];
const masteryCoins = [25, 50, 100];
const masteryChests = ['wood', 'silver', 'gold'];

/// Solid medal colours (bronze, silver, gold), shared by the arcade pips and the results card.
const masteryColors = [Color(0xFFC77B3A), Color(0xFFB8C0CC), AppColors.yellow];

/// Pays every level (1..3) that [score] reaches and [claimed] does not hold yet, in ascending order:
/// marks it claimed, adds its coins and grants its chest. Returns the levels paid.
List<int> payMastery(ProfileController c, Set<String> claimed, GameSpec spec, int score) {
  final paid = <int>[];
  for (var l = 1; l <= 3; l++) {
    final key = '${spec.id}:$l';
    if (score < spec.levels[l - 1] || claimed.contains(key)) continue;
    c.mutate((p) => p.copyWith(masteryClaimed: {...p.masteryClaimed, key}));
    c.reward(coins: masteryCoins[l - 1]);
    c.grantChest(masteryChests[l - 1]);
    paid.add(l);
  }
  return paid;
}

/// A solid medal disc with an ink outline; an empty outline while [color] is null.
class MedalPip extends StatelessWidget {
  const MedalPip({super.key, this.color, this.size = 14});
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.ink, width: 2),
    ),
  );
}

final games = <GameSpec>[
  GameSpec(
    id: 'runner',
    title: 'Bull Run',
    tagline: 'Dodge the dips, grab the coins',
    howTo: 'Swipe left or right to change lane. Swipe up to jump.',
    emoji: '🐂',
    color: AppColors.green,
    create: RunnerGame.new,
  ),
  GameSpec(
    id: 'stack',
    title: 'Sky Stack',
    tagline: 'Build your tower, block by block',
    howTo: 'Tap to drop the block. Line it up for a perfect streak.',
    emoji: '🏗️',
    color: AppColors.teal,
    create: StackGame.new,
  ),
  GameSpec(
    id: 'merge',
    title: 'Coin Merge',
    tagline: 'Merge small coins into big wealth',
    howTo: 'Swipe to slide the coins. Matching coins merge.',
    emoji: '🪙',
    color: AppColors.yellow,
    create: MergeGame.new,
  ),
  GameSpec(
    id: 'breaker',
    title: 'Brick Bank',
    tagline: 'Crack the vault, brick by brick',
    howTo: 'Drag to move the paddle. Keep the ball in play and break every brick.',
    emoji: '🧱',
    color: AppColors.red,
    create: BreakerGame.new,
  ),
  GameSpec(
    id: 'flap',
    title: 'Candle Hop',
    tagline: 'Fly through the market candles',
    howTo: 'Tap to fly up. Slip through the gaps between the candles.',
    emoji: '🚀',
    color: AppColors.teal,
    create: FlapGame.new,
  ),
  GameSpec(
    id: 'slice',
    title: 'Coin Slash',
    tagline: 'Slice the coins, dodge the scams',
    howTo: 'Swipe across coins to slice them. Never slice a scam bomb.',
    emoji: '⚔️',
    color: AppColors.orange,
    create: SliceGame.new,
  ),
  GameSpec(
    id: 'lock',
    title: 'Pop the Lock',
    tagline: 'Tap the second the pin hits the dot',
    howTo: 'Tap when the pin lines up with the dot. Every pop reverses it and speeds it up.',
    emoji: '🔐',
    color: AppColors.blue,
    create: LockGame.new,
  ),
  GameSpec(
    id: 'sort',
    title: 'Sort Rush',
    tagline: 'Swipe each card into the right bin',
    howTo: 'Swipe the card left or right into its bin. Build a streak before time runs out.',
    emoji: '🗂️',
    color: AppColors.green,
    create: SortGame.new,
  ),
  GameSpec(
    id: 'whack',
    title: 'Scam Whack',
    tagline: 'Grab the real deals, dodge the scams',
    howTo: 'Tap real coins and offers as they pop up. Never tap a scam.',
    emoji: '🔨',
    color: AppColors.red,
    create: WhackGame.new,
  ),
  GameSpec(
    id: 'candle',
    title: 'Green Candle',
    tagline: 'Tap the moment it turns green',
    howTo: 'Wait for the candle to turn green, then tap as fast as you can. Do not jump the gun.',
    emoji: '🕯️',
    color: AppColors.teal,
    create: CandleGame.new,
  ),
  GameSpec(
    id: 'dunk',
    title: 'Piggy Dunk',
    tagline: 'Flick the coin into the piggy bank',
    howTo: 'Drag back and release to flick the coin into the hoop. Swishes score double.',
    emoji: '🐷',
    color: AppColors.orange,
    create: DunkGame.new,
  ),
];

GameSpec? gameById(String id) => games.where((g) => g.id == id).firstOrNull;

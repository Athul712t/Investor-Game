import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../domain/game/game_types.dart';
import '../breaker/breaker_game.dart';
import '../flap/flap_game.dart';
import '../merge/merge_game.dart';
import '../runner/runner_game.dart';
import '../slice/slice_game.dart';
import '../stack/stack_game.dart';
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
];

GameSpec? gameById(String id) => games.where((g) => g.id == id).firstOrNull;

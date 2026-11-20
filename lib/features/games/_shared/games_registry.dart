import 'package:flutter/material.dart';

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

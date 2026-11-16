import 'arcade_colors.dart';

import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/game/game_types.dart';

/// Base class of every mini-game. The host (GameHostScreen) owns the HUD,
/// pause, boost questions, revive and the results screen. A game only:
///  - updates [score] and [coins],
///  - calls [requestBoost] when the player earns a question-for-a-powerup,
///  - calls [gameOver] when the run ends,
///  - implements [applyPowerup] and [revive].
abstract class ArcadeGame extends FlameGame {
  ArcadeGame(this.config);
  final GameConfig config;

  final score = ValueNotifier<int>(0);
  final coins = ValueNotifier<int>(0);

  /// Powerups this game understands. The host picks one per correct answer.
  List<PowerupType> get boosts;

  void applyPowerup(PowerupType type);

  /// Put the player back into a safe, playable state. Score is kept.
  void revive();

  // Wired by the host.
  VoidCallback? onBoostRequested;
  VoidCallback? onGameOver;
  bool _over = false;
  bool get isOver => _over;

  /// Ask the host to show a boost question. The host pauses and resumes the engine.
  void requestBoost() {
    if (!_over) onBoostRequested?.call();
  }

  void gameOver() {
    if (_over) return;
    _over = true;
    pauseEngine();
    onGameOver?.call();
  }

  /// Called by the host after a correct revive answer.
  void continueAfterRevive() {
    _over = false;
    revive();
    resumeEngine();
  }

  @override
  Color backgroundColor() => ArcadeColors.ink;
}

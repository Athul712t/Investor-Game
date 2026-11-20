import 'package:flutter/material.dart';

import '../../games/_shared/game_run.dart';
import '../reel_item.dart';

/// One game run in the reel. Unlocks scrolling once the run reaches its results.
class GameCard extends StatefulWidget {
  const GameCard({super.key, required this.item, required this.active, required this.onDone});
  final ReelGame item;

  /// True only while this card is the one on screen. Do nothing heavy until then.
  final bool active;

  /// Call exactly once when the player may scroll on.
  final ReelDone onDone;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => GameRun(
    gameId: widget.item.gameId,
    reel: true,
    active: widget.active,
    onFinished: (_) {
      if (_done) return;
      _done = true;
      widget.onDone(correct: true);
    },
  );
}

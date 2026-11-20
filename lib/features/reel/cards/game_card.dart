import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profile.dart';
import '../../games/_shared/game_run.dart';
import '../reel_item.dart';

/// One game run in the reel. Unlocks scrolling once the run reaches its results.
class GameCard extends ConsumerStatefulWidget {
  const GameCard({super.key, required this.item, required this.active, required this.onDone});
  final ReelGame item;

  /// True only while this card is the one on screen. Do nothing heavy until then.
  final bool active;

  /// Call exactly once when the player may scroll on.
  final ReelDone onDone;

  @override
  ConsumerState<GameCard> createState() => _GameCardState();
}

class _GameCardState extends ConsumerState<GameCard> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => GameRun(
    gameId: widget.item.gameId,
    reel: true,
    // "Games only" means no learning anywhere, including the quiz chip inside the run.
    chips: ref.watch(profileProvider.select((p) => p.reelMix)) != 0,
    active: widget.active,
    onFinished: (_) {
      if (_done) return;
      _done = true;
      widget.onDone(correct: true);
    },
  );
}

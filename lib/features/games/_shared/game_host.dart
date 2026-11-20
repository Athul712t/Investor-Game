import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../domain/game/game_types.dart';
import 'game_run.dart';

/// Full-screen [GameRun] for Arcade and Story.
/// Pops with the last [GameResult] (or null if the player left before finishing).
class GameHostScreen extends StatefulWidget {
  const GameHostScreen({super.key, required this.gameId, this.targetScore});
  final String gameId;
  final int? targetScore; // set by Story Mode

  @override
  State<GameHostScreen> createState() => _GameHostState();
}

class _GameHostState extends State<GameHostScreen> {
  final _run = GlobalKey<GameRunState>();
  GameResult? _result; // kept across "Play again", so leaving from the next intro still reports it

  void _leave() {
    final nav = Navigator.of(context);
    nav.canPop() ? nav.pop(_result) : context.go('/'); // a reloaded deep link has nothing to pop to
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false, // system back must still hand the run back to the caller
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      final run = _run.currentState!;
      run.atRest ? _leave() : run.pause();
    },
    child: Scaffold(
      backgroundColor: AppColors.ink,
      body: GameRun(
        key: _run,
        gameId: widget.gameId,
        targetScore: widget.targetScore,
        onFinished: (r) => _result = r,
        onLeave: _leave,
      ),
    ),
  );
}

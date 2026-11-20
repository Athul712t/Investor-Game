import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/features/reel/cards/game_card.dart';
import 'package:investor_game/features/reel/reel_item.dart';

import 'game_run_test.dart' show gameOf, pumpReel, settle;

void main() {
  testWidgets('game card calls onDone exactly once after the run ends', (tester) async {
    final done = <bool>[];
    await pumpReel(
      tester,
      (a) => GameCard(item: const ReelGame('merge', 0), active: a, onDone: ({required correct}) => done.add(correct)),
    );
    expect(done, isEmpty);
    gameOf(tester).gameOver();
    await settle(tester);
    expect(find.text('Swipe up for the next card'), findsOneWidget);
    expect(done, [true]);
    gameOf(tester).gameOver(); // a repeat end must not unlock twice
    await settle(tester);
    expect(done, [true]);
  });
}

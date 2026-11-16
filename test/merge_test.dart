import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/merge/merge_board.dart';
import 'package:investor_game/features/games/merge/merge_game.dart';

MergeBoard board(List<int> c) => MergeBoard(rng: Random(1), cells: [...c, ...List.filled(16 - c.length, 0)]);

void main() {
  test('slides and merges in all directions', () {
    expect((board([0, 2, 0, 2])..slide(MergeDir.left)).cells.take(4), [4, 0, 0, 0]);
    expect((board([2, 0, 2, 0])..slide(MergeDir.right)).cells.take(4), [0, 0, 0, 4]);
    expect((board([2, 0, 0, 0, 2, 0, 0, 0, 4])..slide(MergeDir.up)).cells.where((v) => v > 0), [4, 4]);
    final down = board([2, 0, 0, 0, 2])..slide(MergeDir.down);
    expect(down.cells[12], 4);
  });

  test('a tile merges once per move', () {
    expect((board([2, 2, 2, 2])..slide(MergeDir.left)).cells.take(4), [4, 4, 0, 0]);
    expect((board([4, 2, 2, 0])..slide(MergeDir.left)).cells.take(4), [4, 4, 0, 0]);
  });

  test('no spawn when nothing changes, spawn otherwise', () {
    final b = board([2, 4, 0, 0]);
    final r = b.move(MergeDir.left);
    expect(r.changed, isFalse);
    expect(r.spawnCell, -1);
    expect(b.cells.where((v) => v > 0).length, 2);
    final r2 = b.move(MergeDir.right);
    expect(r2.spawnCell, greaterThanOrEqualTo(0));
    expect(b.cells.where((v) => v > 0).length, 3);
  });

  test('game over detection and revive removal', () {
    final full = board([2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 8]);
    expect(full.canMove, isFalse);
    expect(full.removeLowest(4), hasLength(4));
    expect(full.cells.where((v) => v == 2), hasLength(3));
    expect(full.cells.where((v) => v == 0), hasLength(4));
    expect(full.canMove, isTrue);
  });

  test('game smoke', () async {
    final g = MergeGame(const GameConfig(seed: 3));
    g.onGameResize(Vector2(390, 844));
    await g.onLoad();
    for (var i = 0; i < 300; i++) {
      g.update(1 / 60);
    }
    g.applyPowerup(PowerupType.magnet);
    g.revive();
  });
}

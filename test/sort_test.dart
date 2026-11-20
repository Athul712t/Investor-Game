import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/_shared/quick_data.dart';
import 'package:investor_game/features/games/sort/sort_game.dart';
import 'package:investor_game/features/games/sort/sort_rules.dart';

SortDeck _deck([int n = 6]) => SortDeck('L', 'R', [for (var i = 0; i < n; i++) SortItem('item $i', left: i.isEven)]);

SortRules _rules([int n = 6]) => SortRules(_deck(n), Random(1));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a correct sort scores and advances', () {
    final r = _rules();
    final first = r.current;
    final o = r.sort(first.left);
    expect(o.correct, isTrue);
    expect(r.score, 1);
    expect(r.streak, 1);
    expect(identical(r.current, first), isFalse);
  });

  test('a wrong sort costs 2 s and resets the combo', () {
    final r = _rules();
    for (var i = 0; i < 3; i++) {
      r.sort(r.current.left);
    }
    final t = r.time;
    final o = r.sort(!r.current.left);
    expect(o.correct, isFalse);
    expect(r.streak, 0);
    expect(r.time, t - 2);
    expect(r.score, 3);
  });

  test('combo multiplier steps every 5 and caps at x4', () {
    expect([0, 4, 5, 10, 15, 40].map(sortMultiplier), [1, 1, 2, 3, 4, 4]);
    final r = _rules();
    var steps = 0;
    for (var i = 0; i < 5; i++) {
      if (r.sort(r.current.left).comboStep) steps++;
    }
    expect(steps, 1);
    expect(r.multiplier, 2);
    expect(r.sort(r.current.left).points, 2);
  });

  test('double score counts 8 sorts double, 5th correct gives a coin, 10th spawns a bolt card', () {
    final r = _rules()..doubleLeft = 8;
    var coins = 0;
    var boost = false;
    for (var i = 0; i < 12; i++) {
      final wasBolt = r.bolt;
      final o = r.sort(r.current.left);
      if (o.coin) coins++;
      if (o.boost) boost = true;
      expect(wasBolt, i == 10);
    }
    expect(coins, 2);
    expect(boost, isTrue);
    expect(r.doubleLeft, 0);
  });

  test('deck reshuffles when exhausted', () {
    final r = _rules(3);
    final seen = <String>[];
    for (var i = 0; i < 7; i++) {
      seen.add(r.current.text);
      r.sort(r.current.left);
    }
    expect(r.reshuffles, 2);
    expect(seen.toSet().length, 3);
  });

  test('commit threshold: 40 percent drag, or a fast flick in the same direction', () {
    expect(sortCommitSide(-50, 0, 100), -1);
    expect(sortCommitSide(39, 0, 100), 0);
    expect(sortCommitSide(40, 0, 100), 1);
    expect(sortCommitSide(15, 1200, 100), 1);
    expect(sortCommitSide(15, -1200, 100), 0);
    expect(sortCommitSide(3, 2000, 100), 0);
    expect(sortCommitSide(20, 500, 100), 0);
  });

  test('timer runs down, freezes with slow-mo and ends at 0', () {
    final r = _rules();
    r.tick(10);
    expect(r.time, 20);
    r.freeze = 4;
    r.tick(3);
    expect(r.time, 20);
    expect(r.freeze, 1);
    r.tick(1);
    r.tick(4);
    expect(r.time, 16);
    r.tick(100);
    expect(r.time, 0);
    expect(r.ended, isTrue);
  });

  test('smoke: runs, sorts, renders, revives', () async {
    final g = SortGame(const GameConfig(seed: 5))..onGameResize(Vector2(390, 844));
    await g.onLoad();
    var over = false;
    g.onGameOver = () => over = true;
    var boosts = 0;
    g.onBoostRequested = () => boosts++;
    for (var i = 0; i < 900; i++) {
      if (i % 12 == 0) {
        // Mostly right, sometimes wrong.
        final left = g.debugRules.current.left;
        g.debugSort(i % 60 == 0 ? !left : left);
      }
      g.update(1 / 60);
      if (i % 100 == 0) g.render(Canvas(PictureRecorder()));
    }
    g.render(Canvas(PictureRecorder()));
    expect(g.score.value, greaterThan(10));
    expect(g.coins.value, greaterThan(0));
    expect(boosts, greaterThan(0));
    expect(over, isTrue);
    expect(g.isOver, isTrue);

    g.continueAfterRevive();
    expect(g.debugRules.time, 8);
    g.applyPowerup(PowerupType.extraLife);
    expect(g.debugRules.time, 13);
    g.applyPowerup(PowerupType.slowMo);
    g.applyPowerup(PowerupType.doubleScore);
    expect(g.debugRules.freeze, 4);
    expect(g.debugRules.doubleLeft, 8);
    g.update(1 / 60);
    g.render(Canvas(PictureRecorder()));
    expect(g.isOver, isFalse);
  });
}

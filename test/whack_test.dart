import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/games/whack/whack_game.dart';
import 'package:investor_game/features/games/whack/whack_rules.dart';

WhackRules rules([int seed = 1]) =>
    WhackRules(Random(seed), offers: const ['Small SIP'], scams: const ['100% returns!']);

WhackTile put(WhackRules r, TileKind k, int hole) {
  final t = WhackTile(hole, k, 'x', 1);
  r.tiles.add(t);
  return t;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('spawn never exceeds 3 tiles or reuses a hole', () {
    final r = rules();
    for (var i = 0; i < 500; i++) {
      r.spawn();
      expect(r.tiles.length, lessThanOrEqualTo(3));
      expect({for (final t in r.tiles) t.hole}.length, r.tiles.length);
      if (r.tiles.length == 3) r.tiles.removeAt(r.rng.nextInt(3));
    }
    expect(r.spawn(), isNotNull);
    expect(r.spawn(), isNull);
    // stepping a whole run keeps the invariant too
    final s = rules(2);
    for (var i = 0; i < 1800 && !s.over; i++) {
      s.step(1 / 60);
      expect(s.tiles.length, lessThanOrEqualTo(3));
      expect({for (final t in s.tiles) t.hole}.length, s.tiles.length);
    }
  });

  test('lifetime and scam share ramps are monotonic and bounded', () {
    var life = 2.0, share = 0.0;
    for (var t = 0.0; t <= 40; t += 0.25) {
      expect(tileLifetime(t), lessThanOrEqualTo(life));
      expect(scamShare(t), greaterThanOrEqualTo(share));
      life = tileLifetime(t);
      share = scamShare(t);
      expect(life, inInclusiveRange(0.55, 1.1));
      expect(share, inInclusiveRange(0.25, 0.45));
    }
    expect(tileLifetime(0), closeTo(1.1, 1e-9));
    expect(tileLifetime(30), closeTo(0.55, 1e-9));
    expect(scamShare(30), closeTo(0.45, 1e-9));
  });

  test('a real tap scores, coins and bags are worth more, combo grows', () {
    final r = rules();
    put(r, TileKind.offer, 0);
    put(r, TileKind.coin, 1);
    put(r, TileKind.bag, 2);
    expect(r.tap(0)!.points, 1);
    expect(r.tap(1)!.points, 3);
    expect(r.tap(2)!.points, 5);
    expect((r.score, r.coins, r.combo, r.lives), (9, 1, 3, 3));
    expect(r.tap(4), isNull); // empty hole costs nothing
  });

  test('a scam tap costs a life and resets the combo', () {
    final r = rules();
    put(r, TileKind.offer, 0);
    r.tap(0);
    put(r, TileKind.scam, 3);
    final o = r.tap(3)!;
    expect((o.lifeLost, r.lives, r.combo, r.score), (true, 2, 0, 1));
  });

  test('missing a real tile only resets the combo, missing a scam is fine', () {
    final r = rules();
    r.combo = 4;
    put(r, TileKind.scam, 0).age = 0.99;
    r.step(0.02);
    expect((r.combo, r.lives), (4, 3));
    put(r, TileKind.offer, 1).age = 0.99;
    r.step(0.02);
    expect((r.combo, r.lives), (0, 3));
  });

  test('run ends after 30 seconds or at zero lives; revive resumes', () {
    final r = rules();
    while (!r.over) {
      r.step(0.1);
    }
    expect(r.time, greaterThanOrEqualTo(30));
    r.score = 7;
    r.revive();
    expect((r.over, r.score, r.lives, r.tiles.length), (false, 7, 4, 0));
    expect(r.remaining, closeTo(6, 0.2));
    final d = rules();
    for (var i = 0; i < 3; i++) {
      put(d, TileKind.scam, i);
      d.tap(i);
    }
    expect(d.over, isTrue);
    d.revive();
    expect((d.over, d.lives), (false, 1));
  });

  test('powerups: extra life caps at 5, double score doubles', () {
    final r = rules();
    for (var i = 0; i < 6; i++) {
      r.extraLife();
    }
    expect(r.lives, 5);
    r.doubleScore();
    put(r, TileKind.coin, 0);
    expect(r.tap(0)!.points, 6);
  });

  test('a boost tile appears about every 10 seconds', () {
    final r = rules(4);
    var boosts = 0;
    for (var i = 0; i < 1500 && !r.over; i++) {
      boosts += r.step(1 / 60).spawned.where((t) => t.kind == TileKind.boost).length;
      r.tiles.removeWhere((t) => t.kind == TileKind.scam);
    }
    expect(boosts, inInclusiveRange(1, 2));
  });

  test('smoke: runs, renders, revives and takes powerups', () async {
    final g = WhackGame(const GameConfig(seed: 5))..onGameResize(Vector2(390, 844));
    await g.onLoad();
    final rng = Random(3);
    for (var i = 0; i < 900; i++) {
      g.update(1 / 60);
      if (i % 12 == 0) g.tapHole(rng.nextInt(9));
    }
    g.render(Canvas(PictureRecorder()));
    g.applyPowerup(PowerupType.slowMo);
    g.applyPowerup(PowerupType.doubleScore);
    g.applyPowerup(PowerupType.extraLife);
    g.continueAfterRevive();
    expect(g.isOver, isFalse);
    for (var i = 0; i < 60; i++) {
      g.update(1 / 60);
    }
    g.render(Canvas(PictureRecorder()));
  });
}

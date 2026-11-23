import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/domain/game/game_types.dart';
import 'package:investor_game/features/chests/chest_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> container(Profile p) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  c.read(profileProvider.notifier).restore(p);
  return c;
}

void main() {
  test('each table sums to 100', () {
    for (final t in ChestType.values) {
      expect(chestOdds[t]!.fold<int>(0, (a, o) => a + o.percent), 100, reason: t.name);
    }
  });

  test('5000 draws match each table within 3 points and coins stay in range', () {
    for (final t in ChestType.values) {
      final rng = Random(42);
      final seen = <RewardKind, int>{};
      final coinLine = chestOdds[t]!.first;
      for (var i = 0; i < 5000; i++) {
        final r = rollChest(t, rng, lessonIds: ['a-1', 'b-2']);
        seen[r.kind] = (seen[r.kind] ?? 0) + 1;
        if (r.kind == RewardKind.coins) {
          expect(r.coins, inInclusiveRange(coinLine.min, coinLine.max));
        }
      }
      for (final o in chestOdds[t]!) {
        expect((seen[o.kind] ?? 0) / 50, closeTo(o.percent, 3), reason: '${t.name} ${o.kind}');
      }
    }
  });

  test('a freeze is never granted when one is held', () {
    final rng = Random(7);
    for (var i = 0; i < 3000; i++) {
      expect(rollChest(ChestType.gold, rng, holdsFreeze: true, lessonIds: ['a']).kind, isNot(RewardKind.freeze));
    }
  });

  test('same seed, same reward', () {
    ChestReward go() => rollChest(ChestType.silver, Random(5), lessonIds: ['a', 'b']);
    expect(go().kind, go().kind);
    expect(go().coins, go().coins);
  });

  test('study boost prefers lessons under 15 credits', () {
    final rng = Random(1);
    final credits = {'a': 15, 'b': 20, 'c': 2};
    var boosts = 0;
    for (var i = 0; i < 2000; i++) {
      final r = rollChest(ChestType.gold, rng, lessonIds: ['a', 'b', 'c'], credits: credits);
      if (r.kind == RewardKind.studyBoost) {
        boosts++;
        expect(r.lessonId, 'c');
      }
    }
    expect(boosts, greaterThan(0));
  });

  test('opening removes exactly one chest of that type and applies each reward', () async {
    final c = await container(const Profile(chests: ['wood', 'gold', 'wood'], coins: 10));
    final r = openChest(
      c.read(profileProvider),
      c.read(profileProvider.notifier),
      ChestType.wood,
      Random(3),
      lessonIds: ['a-1'],
    );
    expect(r, isNotNull);
    expect(c.read(profileProvider).chests, ['gold', 'wood']);

    Profile apply(ChestReward r) => applyChest(const Profile(chests: ['silver']), ChestType.silver, r);
    expect(apply(const ChestReward(RewardKind.coins, coins: 50)).coins, 50);
    expect(apply(const ChestReward(RewardKind.headStart, count: 2)).headStarts, 2);
    expect(apply(const ChestReward(RewardKind.freeze)).streakFreezes, 1);
    expect(apply(const ChestReward(RewardKind.studyBoost, count: 2, lessonId: 'a-1')).credits['a-1'], 6);
    final pu = apply(
      const ChestReward(RewardKind.powerup, count: 2, powerups: [PowerupType.shield, PowerupType.shield]),
    );
    expect(pu.powerups['shield'], 2);
    expect(apply(const ChestReward(RewardKind.coins, coins: 5)).chests, isEmpty);
  });

  test('an empty list opens nothing and grants nothing', () async {
    final c = await container(const Profile(coins: 3));
    expect(openChest(c.read(profileProvider), c.read(profileProvider.notifier), ChestType.gold, Random(1)), isNull);
    expect(c.read(profileProvider).coins, 3);
    const p = Profile(chests: ['wood']);
    expect(identical(applyChest(p, ChestType.gold, const ChestReward(RewardKind.coins, coins: 9)), p), isTrue);
  });
}

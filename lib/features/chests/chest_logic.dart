import 'dart:math';

import '../../core/profile.dart';
import '../../domain/game/game_types.dart';

enum ChestType { wood, silver, gold }

enum RewardKind { coins, headStart, studyBoost, powerup, freeze }

/// One line of an odds table. [percent] over a table adds to 100; [min]/[max] are coins, [count] is the multiplier.
class Odds {
  const Odds(this.kind, this.percent, {this.min = 0, this.max = 0, this.count = 1});
  final RewardKind kind;
  final int percent, min, max, count;

  String get label => switch (kind) {
    RewardKind.coins => '$min to $max coins',
    RewardKind.headStart => count > 1 ? 'Head-start tokens x$count' : 'Head-start token',
    RewardKind.studyBoost => count > 1 ? 'Study boost x$count' : 'Study boost',
    RewardKind.powerup => count > 1 ? 'Power-up x$count' : 'Power-up',
    RewardKind.freeze => 'Streak freeze',
  };
}

const chestOdds = {
  ChestType.wood: [
    Odds(RewardKind.coins, 60, min: 15, max: 30),
    Odds(RewardKind.headStart, 15),
    Odds(RewardKind.studyBoost, 15),
    Odds(RewardKind.powerup, 10),
  ],
  ChestType.silver: [
    Odds(RewardKind.coins, 45, min: 40, max: 80),
    Odds(RewardKind.headStart, 20),
    Odds(RewardKind.studyBoost, 20),
    Odds(RewardKind.powerup, 10),
    Odds(RewardKind.freeze, 5),
  ],
  ChestType.gold: [
    Odds(RewardKind.coins, 35, min: 100, max: 200),
    Odds(RewardKind.headStart, 20, count: 2),
    Odds(RewardKind.studyBoost, 20, count: 2),
    Odds(RewardKind.powerup, 15, count: 2),
    Odds(RewardKind.freeze, 10),
  ],
};

/// What one opening gives. Only the fields of its [kind] are used.
class ChestReward {
  const ChestReward(this.kind, {this.coins = 0, this.count = 1, this.lessonId = '', this.powerups = const []});
  final RewardKind kind;
  final int coins, count; // coins, or tokens / study boosts granted
  final String lessonId; // lesson that got the study boost
  final List<PowerupType> powerups;
}

const boostCredits = 3, boostCap = 15;

/// Rolls one reward. Pure: the same [rng] state and inputs give the same result.
/// A freeze is swapped for coins when one is held; a study boost with no lessons is too.
ChestReward rollChest(
  ChestType type,
  Random rng, {
  bool holdsFreeze = false,
  List<String> lessonIds = const [],
  Map<String, int> credits = const {},
}) {
  final table = chestOdds[type]!;
  var roll = rng.nextInt(100);
  var pick = table.last;
  for (final o in table) {
    if (roll < o.percent) {
      pick = o;
      break;
    }
    roll -= o.percent;
  }
  final line = table.first;
  ChestReward coins() => ChestReward(RewardKind.coins, coins: line.min + rng.nextInt(line.max - line.min + 1));
  switch (pick.kind) {
    case RewardKind.coins:
      return coins();
    case RewardKind.freeze:
      return holdsFreeze ? coins() : const ChestReward(RewardKind.freeze);
    case RewardKind.headStart:
      return ChestReward(RewardKind.headStart, count: pick.count);
    case RewardKind.powerup:
      return ChestReward(
        RewardKind.powerup,
        count: pick.count,
        powerups: [for (var i = 0; i < pick.count; i++) PowerupType.values[rng.nextInt(PowerupType.values.length)]],
      );
    case RewardKind.studyBoost:
      if (lessonIds.isEmpty) return coins();
      final low = [
        for (final id in lessonIds)
          if ((credits[id] ?? 0) < boostCap) id,
      ];
      final from = low.isEmpty ? lessonIds : low;
      return ChestReward(RewardKind.studyBoost, count: pick.count, lessonId: from[rng.nextInt(from.length)]);
  }
}

/// The profile after opening one [type] chest and getting [r]: chest removed and reward granted in one value.
/// Returns [p] unchanged when it holds no such chest.
Profile applyChest(Profile p, ChestType type, ChestReward r) {
  final i = p.chests.indexOf(type.name);
  if (i < 0) return p;
  final p2 = p.copyWith(chests: [...p.chests]..removeAt(i));
  switch (r.kind) {
    case RewardKind.coins:
      return p2.copyWith(coins: p2.coins + r.coins);
    case RewardKind.headStart:
      return p2.copyWith(headStarts: p2.headStarts + r.count);
    case RewardKind.studyBoost:
      return p2.copyWith(credits: {...p2.credits, r.lessonId: (p2.credits[r.lessonId] ?? 0) + boostCredits * r.count});
    case RewardKind.powerup:
      final pu = {...p2.powerups};
      for (final t in r.powerups) {
        pu[t.name] = (pu[t.name] ?? 0) + 1;
      }
      return p2.copyWith(powerups: pu);
    case RewardKind.freeze:
      return p2.copyWith(streakFreezes: 1);
  }
}

/// Opens the first chest of [type]: rolls, then removes the chest and grants the reward in one save.
/// Null when the player has none.
ChestReward? openChest(
  Profile p,
  ProfileController ctl,
  ChestType type,
  Random rng, {
  List<String> lessonIds = const [],
}) {
  if (!p.chests.contains(type.name)) return null;
  final r = rollChest(type, rng, holdsFreeze: p.streakFreezes > 0, lessonIds: lessonIds, credits: p.credits);
  ctl.mutate((cur) => applyChest(cur, type, r));
  return r;
}

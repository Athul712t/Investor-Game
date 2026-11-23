import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/features/streak/streak_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final d0 = DateTime(2026, 3, 1, 12);
  DateTime day(int n) => DateTime(2026, 3, 1 + n, 12);

  Future<ProviderContainer> make([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues({if (seed.isNotEmpty) 'profile_v1': jsonEncode(seed)});
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(await SharedPreferences.getInstance())]);
    addTearDown(c.dispose);
    return c;
  }

  test('pure functions', () {
    expect(daysBetween('2026-02-28', '2026-03-02'), 2);
    expect(daysBetween('2026-03-02', '2026-03-02'), 0);
    expect(daysBetween('2026-03-03', '2026-03-02'), -1);
    expect(nextMilestone(0, {}), 3);
    expect(nextMilestone(3, {3}), 7);
    expect(nextMilestone(5, {3, 7}), 14);
    expect(nextMilestone(2, {3}), 7); // done ones are skipped
    expect(nextMilestone(30, {3, 7, 14, 30}), isNull);
    const p = Profile(lostStreak: 5, lostDay: '2026-03-10');
    expect(repairOpen(p, '2026-03-10'), isTrue);
    expect(repairOpen(p, '2026-03-11'), isTrue);
    expect(repairOpen(p, '2026-03-12'), isFalse);
    expect(repairOpen(const Profile(), '2026-03-10'), isFalse);
  });

  test('first activity, same day, next day', () async {
    final c = await make();
    final n = c.read(profileProvider.notifier);
    n.touchStreak(d0);
    expect(c.read(profileProvider).streak, 1);
    n.touchStreak(d0);
    expect(c.read(profileProvider).streak, 1);
    n.touchStreak(day(1));
    expect(c.read(profileProvider).streak, 2);
  });

  test('a freeze forgives exactly one missed day and is consumed', () async {
    final c = await make({'streak': 4, 'lastActiveDay': '2026-03-01', 'streakFreezes': 1});
    final n = c.read(profileProvider.notifier);
    n.touchStreak(day(1)); // gap 1: freeze untouched
    expect(c.read(profileProvider).streak, 5);
    expect(c.read(profileProvider).streakFreezes, 1);
    n.touchStreak(day(3)); // gap 2: freeze used
    expect(c.read(profileProvider).streak, 6);
    expect(c.read(profileProvider).streakFreezes, 0);
    n.touchStreak(day(5)); // gap 2 again, no freeze: breaks
    expect(c.read(profileProvider).streak, 1);
    expect(c.read(profileProvider).lostStreak, 6);
  });

  test('gap 2 without a freeze and longer gaps break; lost streak only from 2+', () async {
    var c = await make({'streak': 5, 'lastActiveDay': '2026-03-01'});
    c.read(profileProvider.notifier).touchStreak(day(2));
    var p = c.read(profileProvider);
    expect((p.streak, p.lostStreak, p.lostDay), (1, 5, '2026-03-03'));
    c = await make({'streak': 5, 'lastActiveDay': '2026-03-01', 'streakFreezes': 1});
    c.read(profileProvider.notifier).touchStreak(day(9)); // a freeze does not cover a long gap
    p = c.read(profileProvider);
    expect((p.streak, p.lostStreak, p.streakFreezes), (1, 5, 1));
    c = await make({'streak': 1, 'lastActiveDay': '2026-03-01'});
    c.read(profileProvider.notifier).touchStreak(day(4));
    p = c.read(profileProvider);
    expect((p.streak, p.lostStreak, p.lostDay), (1, 0, ''));
  });

  test('milestones pay once each, also after a break', () async {
    final c = await make();
    final n = c.read(profileProvider.notifier);
    for (var i = 0; i < 3; i++) {
      n.touchStreak(day(i));
    }
    expect(c.read(profileProvider).chests, ['wood']);
    expect(c.read(profileProvider).milestonesDone, {3});
    n.touchStreak(day(10)); // break
    for (var i = 11; i < 13; i++) {
      n.touchStreak(day(i));
    }
    expect(c.read(profileProvider).streak, 3);
    expect(c.read(profileProvider).chests, ['wood']); // not paid again
    for (var i = 13; i < 17; i++) {
      n.touchStreak(day(i));
    }
    expect(c.read(profileProvider).streak, 7);
    expect(c.read(profileProvider).chests, ['wood', 'silver']);
  });

  test('30 days grants gold', () async {
    final c = await make({
      'streak': 29,
      'lastActiveDay': '2026-03-01',
      'milestonesDone': [3, 7, 14],
    });
    c.read(profileProvider.notifier).touchStreak(day(1));
    expect(c.read(profileProvider).chests, ['gold']);
  });

  test('repair window: open on the day and the day after, closed after, lazily cleared', () async {
    final seed = {'streak': 8, 'lastActiveDay': '2026-03-01'};
    var c = await make(seed);
    var n = c.read(profileProvider.notifier);
    n.touchStreak(day(5)); // breaks on 03-06
    expect(repairOpen(c.read(profileProvider), '2026-03-06'), isTrue);
    expect(repairOpen(c.read(profileProvider), '2026-03-07'), isTrue);
    expect(repairOpen(c.read(profileProvider), '2026-03-08'), isFalse);
    expect(n.repairStreak(day(7)), isFalse); // too late, nothing changes
    expect(c.read(profileProvider).streak, 1);
    n.touchStreak(day(7)); // the stale offer is cleared on the next activity
    expect(c.read(profileProvider).lostStreak, 0);
    expect(c.read(profileProvider).lostDay, '');

    c = await make(seed);
    n = c.read(profileProvider.notifier);
    n.touchStreak(day(5));
    expect(n.repairStreak(day(5)), isTrue);
    final p = c.read(profileProvider);
    expect((p.streak, p.lostStreak, p.lostDay), (9, 0, ''));
    expect(n.repairStreak(day(5)), isFalse); // offer is gone
  });

  test('repair can hit a milestone, also the day after the break', () async {
    final c = await make({'streak': 2, 'lastActiveDay': '2026-03-01'});
    final n = c.read(profileProvider.notifier);
    n.touchStreak(day(4));
    expect(c.read(profileProvider).lostStreak, 2);
    n.touchStreak(day(5)); // plays on the next day, streak 2
    expect(n.repairStreak(day(5)), isTrue);
    expect(c.read(profileProvider).streak, 3);
    expect(c.read(profileProvider).chests, ['wood']);
  });
}

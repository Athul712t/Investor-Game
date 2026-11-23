import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/features/games/_shared/games_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(await SharedPreferences.getInstance())]);
    addTearDown(c.dispose);
  });

  List<int> pay(String id, int score) =>
      payMastery(c.read(profileProvider.notifier), c.read(profileProvider).masteryClaimed, gameById(id)!, score);

  test('every game has three ascending targets', () {
    for (final g in games) {
      expect(g.levels, hasLength(3), reason: g.id);
      expect(g.levels[0], lessThan(g.levels[1]), reason: g.id);
      expect(g.levels[1], lessThan(g.levels[2]), reason: g.id);
    }
    expect(gameById('merge')!.levels, [500, 2000, 6000]);
    expect(gameById('candle')!.levels, [2000, 3200, 4200]);
  });

  test('crossing a threshold pays coins, a chest and the marker, once', () {
    expect(pay('merge', 499), isEmpty);
    expect(pay('merge', 500), [1]);
    var p = c.read(profileProvider);
    final coins = p.coins;
    expect(p.chests, ['wood']);
    expect(p.masteryClaimed, {'merge:1'});
    expect(pay('merge', 1500), isEmpty, reason: 'level 1 never pays twice');
    expect(c.read(profileProvider).coins, coins);
    expect(pay('merge', 2000), [2]);
    p = c.read(profileProvider);
    expect(p.coins, coins + 50);
    expect(p.chests, ['wood', 'silver']);
  });

  test('a run crossing several levels pays them all in ascending order', () {
    final before = c.read(profileProvider).coins;
    expect(pay('dunk', 15), [1, 2, 3]);
    final p = c.read(profileProvider);
    expect(p.chests, ['wood', 'silver', 'gold']);
    expect(p.coins, before + 175);
    expect(p.masteryClaimed, {'dunk:1', 'dunk:2', 'dunk:3'});
    expect(pay('dunk', 100), isEmpty);
    expect(c.read(profileProvider).chests, hasLength(3));
  });
}

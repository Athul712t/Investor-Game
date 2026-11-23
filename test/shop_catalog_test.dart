import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/profile.dart';
import 'package:investor_game/core/theme.dart';
import 'package:investor_game/features/shop/shop_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> boot(Profile p) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  c.read(profileProvider.notifier).mutate((_) => p);
  return c;
}

void main() {
  bool buy(ProviderContainer c, String id) =>
      buyItem(c.read(profileProvider.notifier), c.read(profileProvider), shopItem(id)!);

  test('catalog has the agreed ids and prices', () {
    expect(
      {for (final i in shopItems) i.id: i.price},
      {
        'freeze': 60,
        'headstart3': 70,
        'tree': 80,
        'lamp': 100,
        'flag': 60,
        'fountain': 150,
        'windmill': 220,
        'statue': 300,
        'pawn_red': 120,
        'pawn_orange': 120,
        'pawn_teal': 120,
        'pawn_ink': 120,
      },
    );
  });

  test('buy deducts coins and records ownership', () async {
    final c = await boot(const Profile(coins: 100));
    expect(buy(c, 'tree'), isTrue);
    final p = c.read(profileProvider);
    expect(p.coins, 20);
    expect(p.owned, {'tree'});
  });

  test('cannot buy without coins; nothing changes', () async {
    final c = await boot(const Profile(coins: 79));
    expect(buy(c, 'tree'), isFalse);
    final p = c.read(profileProvider);
    expect(p.coins, 79);
    expect(p.owned, isEmpty);
  });

  test('cannot buy twice', () async {
    final c = await boot(const Profile(coins: 500));
    expect(buy(c, 'lamp'), isTrue);
    expect(buy(c, 'lamp'), isFalse);
    expect(c.read(profileProvider).coins, 400);
    expect(buyState(c.read(profileProvider), shopItem('lamp')!), BuyState.owned);
  });

  test('freeze sets one and is unavailable while held', () async {
    final c = await boot(const Profile(coins: 200));
    expect(buy(c, 'freeze'), isTrue);
    expect(c.read(profileProvider).streakFreezes, 1);
    expect(buyState(c.read(profileProvider), shopItem('freeze')!), BuyState.held);
    expect(buy(c, 'freeze'), isFalse);
    expect(c.read(profileProvider).coins, 140);
  });

  test('headstart3 adds three and is repeatable', () async {
    final c = await boot(const Profile(coins: 200, headStarts: 1));
    expect(buy(c, 'headstart3'), isTrue);
    expect(buy(c, 'headstart3'), isTrue);
    expect(c.read(profileProvider).headStarts, 7);
    expect(c.read(profileProvider).coins, 60);
    expect(buy(c, 'headstart3'), isFalse);
  });

  test('equip only owned, unequip, and the cap of six', () {
    var p = const Profile(owned: {'tree', 'lamp'});
    expect(toggleDecor(p, 'flag').townDecor, isEmpty); // not owned
    expect(toggleDecor(p, 'pawn_red').townDecor, isEmpty); // not a decoration
    p = toggleDecor(p, 'tree');
    expect(p.townDecor, {'tree'});
    p = toggleDecor(p, 'tree');
    expect(p.townDecor, isEmpty);

    // Cap: a profile that somehow holds more still equips at most six.
    final full = Profile(
      owned: {'tree', 'lamp', 'flag', 'fountain', 'windmill', 'statue'},
      townDecor: {'tree', 'lamp', 'flag', 'fountain', 'windmill'},
    );
    expect(toggleDecor(full, 'statue').townDecor.length, 6);
    expect(maxDecor, 6);
  });

  test('equippedDecor never includes unowned or unknown items', () {
    const p = Profile(owned: {'tree', 'card:nav'}, townDecor: {'tree', 'lamp', 'card:nav', 'bogus'});
    expect(equippedDecor(p), {'tree'});
  });

  test('pawn equip toggles, needs ownership, and has a colour', () {
    var p = const Profile(owned: {'pawn_teal'});
    expect(togglePawn(p, 'pawn_red').pawn, '');
    p = togglePawn(p, 'pawn_teal');
    expect(p.pawn, 'pawn_teal');
    expect(pawnColor(p.pawn), AppColors.teal);
    expect(togglePawn(p, 'pawn_teal').pawn, '');
    expect(pawnColor(''), AppColors.green);
    expect(pawnColor('nope'), AppColors.green);
  });

  test('owned items with other prefixes are ignored', () async {
    final c = await boot(const Profile(coins: 100, owned: {'card:nav', 'album:x'}));
    expect(buyState(c.read(profileProvider), shopItem('tree')!), BuyState.available);
    expect(buy(c, 'tree'), isTrue);
    expect(c.read(profileProvider).owned, {'card:nav', 'album:x', 'tree'});
    expect(toggleDecor(c.read(profileProvider), 'card:nav'), c.read(profileProvider));
    expect(shopItem('card:nav'), isNull);
  });
}

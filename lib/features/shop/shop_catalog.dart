import 'package:flutter/material.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';

enum ShopKind { boost, decor, pawn }

class ShopItem {
  const ShopItem(this.id, this.name, this.blurb, this.price, this.kind);
  final String id, name, blurb;
  final int price;
  final ShopKind kind;
}

const maxDecor = 6;

const shopItems = [
  ShopItem('freeze', 'Streak freeze', 'Saves your streak for one missed day.', 60, ShopKind.boost),
  ShopItem('headstart3', 'Head start x3', 'Three free head starts for arcade games.', 70, ShopKind.boost),
  ShopItem('tree', 'Oak tree', 'Shade for Portfolio Town.', 80, ShopKind.decor),
  ShopItem('lamp', 'Street lamp', 'Lights up the town at night.', 100, ShopKind.decor),
  ShopItem('flag', 'Town flag', 'Waves over the plaza.', 60, ShopKind.decor),
  ShopItem('fountain', 'Fountain', 'A splash in the town square.', 150, ShopKind.decor),
  ShopItem('windmill', 'Windmill', 'Its sails never stop.', 220, ShopKind.decor),
  ShopItem('statue', 'Gold statue', 'For a town that grew well.', 300, ShopKind.decor),
  ShopItem('pawn_red', 'Red pawn', 'Your Story map pawn.', 120, ShopKind.pawn),
  ShopItem('pawn_orange', 'Orange pawn', 'Your Story map pawn.', 120, ShopKind.pawn),
  ShopItem('pawn_teal', 'Teal pawn', 'Your Story map pawn.', 120, ShopKind.pawn),
  ShopItem('pawn_ink', 'Ink pawn', 'Your Story map pawn.', 120, ShopKind.pawn),
];

List<ShopItem> itemsOf(ShopKind k) => [
  for (final i in shopItems)
    if (i.kind == k) i,
];

ShopItem? shopItem(String id) {
  for (final i in shopItems) {
    if (i.id == id) return i;
  }
  return null;
}

const _pawnColors = {
  'pawn_red': AppColors.red,
  'pawn_orange': AppColors.orange,
  'pawn_teal': AppColors.teal,
  'pawn_ink': AppColors.ink,
};

/// Colour of an equipped pawn id; unknown or empty is the default green.
Color pawnColor(String id) => _pawnColors[id] ?? AppColors.green;

enum BuyState { available, poor, owned, held }

/// Whether [i] can be bought now. Boosts are never "owned"; only the freeze can be held.
BuyState buyState(Profile p, ShopItem i) {
  if (i.id == 'freeze' && p.streakFreezes >= 1) return BuyState.held;
  if (i.kind != ShopKind.boost && p.owned.contains(i.id)) return BuyState.owned;
  return p.coins < i.price ? BuyState.poor : BuyState.available;
}

/// Buys [i] for the current profile [p]. Returns false and changes nothing unless it was [BuyState.available].
bool buyItem(ProfileController c, Profile p, ShopItem i) {
  if (buyState(p, i) != BuyState.available || !c.spend(i.price)) return false;
  c.mutate(
    (q) => switch (i.id) {
      'freeze' => q.copyWith(streakFreezes: 1),
      'headstart3' => q.copyWith(headStarts: q.headStarts + 3),
      _ => q.copyWith(owned: {...q.owned, i.id}),
    },
  );
  return true;
}

/// Equipped decorations that are known, owned and within the cap. This is what the town draws.
Set<String> equippedDecor(Profile p) {
  final ids = {for (final i in itemsOf(ShopKind.decor)) i.id};
  return {...p.townDecor.where((d) => ids.contains(d) && p.owned.contains(d)).take(maxDecor)};
}

/// Equips or unequips decoration [id]. Not owned, unknown, or over the cap: unchanged.
Profile toggleDecor(Profile p, String id) {
  if (shopItem(id)?.kind != ShopKind.decor || !p.owned.contains(id)) return p;
  final on = equippedDecor(p);
  if (on.contains(id)) return p.copyWith(townDecor: {...on}..remove(id));
  return on.length >= maxDecor ? p : p.copyWith(townDecor: {...on, id});
}

/// Equips pawn [id], or goes back to the default when it is already equipped. Must be owned.
Profile togglePawn(Profile p, String id) {
  if (shopItem(id)?.kind != ShopKind.pawn || !p.owned.contains(id)) return p;
  return p.copyWith(pawn: p.pawn == id ? '' : id);
}

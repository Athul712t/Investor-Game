import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'shop_art.dart';
import 'shop_catalog.dart';

/// Coin shop: boosts, town decorations and pawn colours. Route /shop. Coins only.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final text = context.text;

    Widget section(String title, ShopKind kind, {String? note}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.md),
        Semantics(header: true, child: Text(title, style: text.titleLarge)),
        if (note != null) Text(note, style: text.bodySmall),
        const SizedBox(height: AppSpace.sm),
        for (final item in itemsOf(kind)) ...[_ItemCard(item: item), const SizedBox(height: AppSpace.sm)],
      ],
    );

    return AppScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.lg),
        children: [
          Row(
            children: [
              _BackButton(),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text('Shop', style: text.headlineMedium)),
              _Balance(coins: p.coins),
            ],
          ),
          section('Boosts', ShopKind.boost),
          section('Town', ShopKind.decor, note: '${equippedDecor(p).length} of $maxDecor equipped in Portfolio Town'),
          section('Pawns', ShopKind.pawn, note: 'Colours your pawn on the Story map'),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  void _back(BuildContext context) {
    final nav = Navigator.of(context);
    nav.canPop() ? nav.pop() : GoRouter.maybeOf(context)?.go('/');
  }

  @override
  Widget build(BuildContext context) => Pressable(
    label: 'Back',
    onTap: () => _back(context),
    builder: (_, down) => Container(
      width: 48,
      height: 48,
      margin: EdgeInsets.only(top: down ? 3 : 0, bottom: down ? 0 : 3),
      decoration: pieceDecoration(radius: 14, depth: down ? 0 : 3),
      child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
    ),
  );
}

class _Balance extends StatelessWidget {
  const _Balance({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Coins $coins',
    excludeSemantics: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
      decoration: pieceDecoration(radius: 999, depth: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Coin3D(size: 28),
          const SizedBox(width: 6),
          CountUp(value: coins, style: context.text.titleLarge!.copyWith(fontSize: 19)),
        ],
      ),
    ),
  );
}

class _ItemCard extends ConsumerStatefulWidget {
  const _ItemCard({required this.item});
  final ShopItem item;

  @override
  ConsumerState<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<_ItemCard> with TickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _tried = false; // a failed buy: keep showing what is missing while it is still missing

  @override
  void dispose() {
    _shake.dispose();
    _pop.dispose();
    super.dispose();
  }

  ShopItem get item => widget.item;

  void _buy() {
    final c = ref.read(profileProvider.notifier);
    if (buyItem(c, ref.read(profileProvider), item)) {
      Sound.play(Sfx.coin);
      setState(() => _tried = false);
      if (!context.reduceMotion) _pop.forward(from: 0);
    }
  }

  void _poorTap() {
    setState(() => _tried = true);
    Sound.play(Sfx.wrong, volume: 0.5);
    if (!context.reduceMotion) _shake.forward(from: 0);
  }

  void _equip() {
    final c = ref.read(profileProvider.notifier);
    c.mutate((p) => item.kind == ShopKind.pawn ? togglePawn(p, item.id) : toggleDecor(p, item.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider);
    final state = buyState(p, item);
    final equipped = switch (item.kind) {
      ShopKind.decor => equippedDecor(p).contains(item.id),
      ShopKind.pawn => p.pawn == item.id,
      ShopKind.boost => false,
    };
    final missing = item.price - p.coins;
    final text = context.text;

    final (String label, Color color, VoidCallback? onTap, String semantic) = switch (state) {
      BuyState.available => ('Buy', AppColors.green, _buy, 'Buy ${item.name} for ${item.price} coins'),
      BuyState.poor => ('Buy', AppColors.track, null, 'Buy ${item.name}, need $missing more coins'),
      BuyState.held => ('Held', AppColors.track, null, '${item.name}, you already hold one'),
      BuyState.owned =>
        equipped
            ? ('Equipped', AppColors.blue, _equip, '${item.name} is equipped. Tap to unequip')
            : ('Equip', AppColors.yellow, _equip, 'Equip ${item.name}'),
    };

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: pieceDecoration(fill: equipped ? AppColors.tint(AppColors.blue, 0.85) : AppColors.card),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: pieceDecoration(fill: AppColors.paperDeep, radius: 14, depth: 0),
            child: ItemArt(item.id),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: text.titleLarge),
                Text(
                  item.id == 'headstart3' && p.headStarts > 0 ? '${item.blurb} You have ${p.headStarts}.' : item.blurb,
                  style: text.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    state == BuyState.owned ? _Tag('Owned') : _Price(item.price),
                    _Btn(
                      label: label,
                      color: color,
                      semantic: semantic,
                      onTap: onTap,
                      onDisabledTap: state == BuyState.poor ? _poorTap : null,
                      key: ValueKey('btn_${item.id}'),
                    ),
                  ],
                ),
                if (_tried && state == BuyState.poor)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Need $missing more coins',
                      style: text.labelSmall!.copyWith(color: AppColors.red, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return KeyedSubtree(
      key: ValueKey('card_${item.id}'),
      child: AnimatedBuilder(
        animation: Listenable.merge([_shake, _pop]),
        builder: (_, child) {
          final s = _shake.value, pp = _pop.value;
          return Transform.translate(
            offset: Offset(sin(s * pi * 6) * 9 * (1 - s), 0),
            child: Transform.scale(
              scale: 1 + 0.05 * sin(pp * pi),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  child!,
                  if (pp > 0 && pp < 1)
                    Positioned(
                      right: 8,
                      top: -10,
                      child: Transform.scale(
                        scale: Curves.easeOutBack.transform((pp * 4).clamp(0, 1)) * (1 - pow(pp, 6)),
                        child: const _Tag('Bought!', color: AppColors.green),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        child: card,
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price(this.price);
  final int price;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$price coins',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: pieceDecoration(fill: AppColors.tint(AppColors.yellow, 0.6), radius: 999, depth: 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Coin3D(size: 18, spin: false),
          const SizedBox(width: 4),
          Text('$price', style: context.text.titleLarge!.copyWith(fontSize: 16)),
        ],
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.color = AppColors.teal});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: pieceDecoration(fill: color, radius: 999, depth: 0),
    child: Text(label, style: context.text.titleLarge!.copyWith(fontSize: 15, color: AppColors.on(color))),
  );
}

/// Chunky pill button, at least 48 high including its hard shadow. Disabled ones still take taps ([onDisabledTap]).
class _Btn extends StatelessWidget {
  const _Btn({
    super.key,
    required this.label,
    required this.color,
    required this.semantic,
    required this.onTap,
    this.onDisabledTap,
  });
  final String label, semantic;
  final Color color;
  final VoidCallback? onTap, onDisabledTap;

  Widget _face(BuildContext context, bool down) => AnimatedContainer(
    duration: const Duration(milliseconds: 60),
    constraints: const BoxConstraints(minHeight: 44, minWidth: 88),
    margin: EdgeInsets.only(top: down ? 4 : 0, bottom: down ? 0 : 4),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    alignment: Alignment.center,
    decoration: pieceDecoration(fill: color, radius: 14, depth: down || onTap == null ? 0 : 4),
    child: Text(
      label,
      style: context.text.titleLarge!.copyWith(
        fontSize: 17,
        color: onTap == null ? AppColors.inkDim : AppColors.on(color),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (onTap != null) return Pressable(label: semantic, onTap: onTap, builder: _face);
    return Semantics(
      button: true,
      enabled: false,
      label: semantic,
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onDisabledTap, child: _face(context, false)),
    );
  }
}

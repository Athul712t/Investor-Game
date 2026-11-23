import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../content/learn_screen.dart';
import '../games/arcade_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';
import 'pictograms.dart';

/// Selected bottom tab: 0 Home, 1 Learn, 2 Play, 3 Profile.
final tabProvider = NotifierProvider<TabIndex, int>(TabIndex.new);

class TabIndex extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

class Shell extends ConsumerWidget {
  const Shell({super.key});

  static const _screens = [HomeScreen(), LearnScreen(), ArcadeScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    return AppScaffold(
      // Hidden tabs keep their state but not their tickers: IndexedStack alone leaves their animations running.
      body: IndexedStack(
        index: tab,
        children: [for (final (i, screen) in _screens.indexed) TickerMode(enabled: i == tab, child: screen)],
      ),
      bottom: _BottomBar(selected: tab, onSelect: ref.read(tabProvider.notifier).go),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const _tabs = [
    ('Home', Pic.home, AppColors.green),
    ('Learn', Pic.learn, AppColors.blue),
    ('Play', Pic.arcade, AppColors.yellow),
    ('Profile', Pic.profile, AppColors.orange),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.card,
      border: Border(
        top: BorderSide(color: AppColors.ink, width: AppSpace.outline),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpace.maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.sm, 10, AppSpace.sm, 8),
            child: Row(
              children: [
                for (final (i, (label, pic, color)) in _tabs.indexed)
                  Expanded(
                    child: _Tab(label: label, pic: pic, color: color, active: i == selected, onTap: () => onSelect(i)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.pic, required this.color, required this.active, required this.onTap});
  final String label;
  final Pic pic;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    child: Pressable(
      onTap: onTap,
      label: label,
      builder: (context, down) => TweenAnimationBuilder<double>(
        tween: Tween(end: active && !down ? 1 : 0),
        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
        curve: Curves.easeOutBack, // the quick spring: a small overshoot as the piece lifts
        builder: (context, lift, child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Transform.translate(
            offset: Offset(0, 4 - 4 * lift),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: pieceDecoration(
                fill: active ? color : AppColors.paperDeep,
                radius: 14,
                depth: 4 * lift.clamp(0.0, 1.2),
              ),
              child: child,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pictogram(pic, size: 24, color: active ? AppColors.card : color),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: context.text.labelSmall!.copyWith(color: active ? AppColors.on(color) : AppColors.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

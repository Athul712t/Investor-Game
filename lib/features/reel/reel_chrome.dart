import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Stands in for every card the player has not reached: nothing about it is built yet.
class HiddenCard extends StatelessWidget {
  const HiddenCard({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Next card, hidden until you get there',
    excludeSemantics: true,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.lg),
          decoration: pieceDecoration(fill: AppColors.paperDeep),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedText(
                '?',
                fill: AppColors.yellow,
                stroke: 7,
                style: context.text.displaySmall!.copyWith(fontSize: 110, height: 1),
              ),
              const SizedBox(height: AppSpace.sm),
              Text('Up next', style: context.text.titleLarge),
              const SizedBox(height: 2),
              Text(
                'A game, a question or a quick read.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Pill with a painted icon and a rolling number.
class ReelPill extends StatelessWidget {
  const ReelPill({super.key, required this.semantic, required this.icon, required this.value});
  final String semantic;
  final Widget icon;
  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$semantic $value',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 10, 3),
      decoration: pieceDecoration(radius: 999, depth: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          CountUp(value: value, style: context.text.titleLarge!.copyWith(fontSize: 16)),
        ],
      ),
    ),
  );
}

/// Bottom strip: a padlock while the card is unfinished, a bobbing "Swipe up" once it is done.
class SwipeCue extends StatelessWidget {
  const SwipeCue({super.key, required this.open, required this.onNext});
  final bool open;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutBack, // the unlock is a reward moment: a small overshoot is allowed
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(a), child: child),
      ),
      child: open ? _Unlocked(key: const ValueKey(true), onNext: onNext) : const _Locked(key: ValueKey(false)),
    ),
  );
}

class _Locked extends StatelessWidget {
  const _Locked({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_rounded, size: 18, color: AppColors.inkDim),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Finish this card to continue',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall!.copyWith(color: AppColors.inkDim),
          ),
        ),
      ],
    ),
  );
}

class _Unlocked extends StatelessWidget {
  const _Unlocked({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Next card',
    button: true,
    onTap: onNext,
    customSemanticsActions: {const CustomSemanticsAction(label: 'Next card'): onNext},
    excludeSemantics: true,
    child: Center(
      child: Pressable(
        onTap: onNext,
        silent: true, // the snap plays its own swipe sound
        builder: (_, down) => AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: Matrix4.translationValues(0, down ? 4 : 0, 0),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(14, 4, 20, 4),
          decoration: pieceDecoration(fill: AppColors.green, radius: 999, depth: down ? 0 : 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Bob(child: Icon(Icons.keyboard_double_arrow_up_rounded, size: 28, color: AppColors.ink)),
              const SizedBox(width: 6),
              Text('Swipe up', style: context.text.titleLarge),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Gently bobs its child up and down to invite the swipe.
class _Bob extends StatefulWidget {
  const _Bob({required this.child});
  final Widget child;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(offset: Offset(0, -4 * sin(_c.value * 2 * pi).abs()), child: child),
      child: widget.child,
    );
  }
}

/// Exit piece for the top bar.
class ExitButton extends StatelessWidget {
  const ExitButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    label: 'Leave the reel',
    builder: (_, down) => SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: Matrix4.translationValues(0, down ? 3 : 0, 0),
          width: 42,
          height: 42,
          decoration: pieceDecoration(radius: 14, depth: down ? 0 : 3),
          child: const Icon(Icons.close_rounded, color: AppColors.ink, size: 24),
        ),
      ),
    ),
  );
}


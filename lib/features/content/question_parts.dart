import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Wiggles its child horizontally each time [shakes] increases.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.shakes, required this.child});
  final int shakes;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.shakes != old.shakes) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) =>
        Transform.translate(offset: Offset(sin(_c.value * pi * 6) * 9 * (1 - _c.value), 0), child: child),
    child: widget.child,
  );
}

enum OptState { idle, selected, right, wrong, missed, dim }

/// Big tappable answer tile with right/wrong colouring and a small pop when chosen.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.state,
    this.onTap,
    this.leading,
    this.center = false,
  });
  final String label;
  final OptState state;
  final VoidCallback? onTap;
  final String? leading;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final c = switch (state) {
      OptState.right || OptState.missed => AppColors.green,
      OptState.wrong => AppColors.red,
      OptState.selected => AppColors.blue,
      _ => AppColors.track,
    };
    final tinted = state != OptState.idle && state != OptState.dim;
    final icon = switch (state) {
      OptState.right || OptState.missed => Icons.check_circle_rounded,
      OptState.wrong => Icons.cancel_rounded,
      _ => null,
    };
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap, // excludeSemantics drops the detector's own tap action
      child: AnimatedOpacity(
        duration: AppMotion.base,
        opacity: state == OptState.dim ? 0.45 : 1,
        child: AnimatedScale(
          duration: AppMotion.base,
          curve: Curves.easeOutBack,
          scale: state == OptState.right || state == OptState.wrong ? 1.03 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.curve,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: tinted ? Color.alphaBlend(c.withValues(alpha: 0.18), AppColors.card) : AppColors.paperDeep,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c, width: 2),
                boxShadow: [
                  BoxShadow(color: tinted ? c.withValues(alpha: 0.6) : AppColors.track, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c, width: 1.5),
                      ),
                      child: Text(
                        leading!,
                        style: context.text.labelLarge!.copyWith(color: tinted ? c : AppColors.inkDim),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: center ? TextAlign.center : TextAlign.start,
                      style: context.text.bodyLarge,
                    ),
                  ),
                  if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: c)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Result banner: icon, headline, optional note (scenario outcome) and the explanation.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key, required this.correct, required this.title, required this.explanation, this.note});
  final bool correct;
  final String title, explanation;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = correct ? AppColors.green : AppColors.red;
    return TweenAnimationBuilder<double>(
      duration: AppMotion.base,
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0, end: 1),
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.withValues(alpha: 0.16), AppColors.card),
          borderRadius: BorderRadius.circular(AppSpace.radius),
          border: Border.all(color: c.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: context.text.titleLarge!.copyWith(color: c)),
                ),
              ],
            ),
            if (note != null) ...[const SizedBox(height: AppSpace.sm), Text(note!, style: context.text.bodyLarge)],
            const SizedBox(height: AppSpace.sm),
            Text(explanation, style: context.text.bodyMedium!.copyWith(color: AppColors.ink.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }
}

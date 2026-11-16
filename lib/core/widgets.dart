import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Page frame: soft colour glows on the ink background, centred content column.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.appBar, this.bottom, this.glow = AppColors.violet});
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottom;
  final Color glow;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    extendBodyBehindAppBar: true,
    bottomNavigationBar: bottom,
    body: Stack(
      children: [
        Positioned(top: -120, right: -80, child: _Glow(glow)),
        const Positioned(bottom: -140, left: -100, child: _Glow(AppColors.mint)),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpace.maxWidth),
              child: body,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Raised surface card. Pass [accent] for a tinted border and gradient wash.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.accent,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });
  final Widget child;
  final Color? accent;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final a = accent;
    final radius = BorderRadius.circular(AppSpace.radius);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: a?.withValues(alpha: 0.45) ?? AppColors.line, width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              a == null ? AppColors.surfaceHi : Color.alphaBlend(a.withValues(alpha: 0.20), AppColors.surfaceHi),
              AppColors.surface,
            ],
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The main action button: chunky, with a darker bottom edge that compresses on press.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.mint,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool expand;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final face = enabled ? widget.color : AppColors.line;
    final edge = HSLColor.fromColor(face)
        .withLightness((HSLColor.fromColor(face).lightness - 0.18).clamp(0, 1))
        .toColor();
    final fg = face.computeLuminance() > 0.4 ? AppColors.ink : AppColors.text;
    const depth = 5.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed, // excludeSemantics drops the detector's own tap action
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          margin: EdgeInsets.only(top: _down ? depth : 0),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          width: widget.expand ? double.infinity : null,
          decoration: BoxDecoration(
            color: face,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: edge, offset: Offset(0, _down ? 0 : depth))],
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, color: fg, size: 22), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge!.copyWith(color: fg, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small icon + value chip (coins, XP, streak).
class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.icon, required this.value, required this.color, this.semantic});
  final IconData icon;
  final String value;
  final Color color;
  final String? semantic;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semantic == null ? value : '$semantic $value',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(value, style: context.text.titleSmall!.copyWith(color: color)),
        ],
      ),
    ),
  );
}

/// Thick animated progress bar, [value] from 0 to 1.
class FatProgress extends StatelessWidget {
  const FatProgress({super.key, required this.value, this.color = AppColors.mint, this.height = 12});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${(value.clamp(0, 1) * 100).round()} percent',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: AppColors.line,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.35)!]),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Round emoji/icon badge used on cards and map nodes.
class Badge3D extends StatelessWidget {
  const Badge3D({super.key, required this.emoji, required this.color, this.size = 52});
  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.32),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.25)!, color],
      ),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
    ),
    child: ExcludeSemantics(
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    ),
  );
}

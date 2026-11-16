import 'dart:math';

import 'package:flutter/material.dart';

import 'sfx.dart';
import 'theme.dart';

/// Page frame: paper ground with a faint dot grid, centred content column.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.appBar, this.bottom, this.fill = AppColors.paper});
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottom;
  final Color fill;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: fill,
    appBar: appBar,
    extendBodyBehindAppBar: true,
    bottomNavigationBar: bottom,
    body: Stack(
      children: [
        const Positioned.fill(child: PaperBackground()),
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

/// Dot grid, like the back of a board-game board. Texture without a gradient.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(child: CustomPaint(painter: _DotPainter())),
  );
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.ink.withValues(alpha: 0.07);
    const gap = 22.0;
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.4, p);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Reports the pressed state from touch-down, with sound and haptic on the same frame.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.builder, required this.onTap, this.label, this.silent = false});
  final Widget Function(BuildContext context, bool down) builder;
  final VoidCallback? onTap;
  final String? label; // screen-reader label; the tap action stays reachable
  final bool silent;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
      excludeSemantics: widget.label != null,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on
            ? (_) {
                setState(() => _down = true);
                if (!widget.silent) Sound.tap();
              }
            : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: on
            ? (_) {
                setState(() => _down = false);
                widget.onTap!();
              }
            : null,
        child: widget.builder(context, _down),
      ),
    );
  }
}

/// A piece that sinks by [depth] while pressed. Shared by cards and buttons.
class _Piece extends StatelessWidget {
  const _Piece({
    required this.down,
    required this.fill,
    required this.child,
    this.radius = AppSpace.radius,
    this.depth = AppSpace.depth,
    this.padding = EdgeInsets.zero,
    this.width,
  });
  final bool down;
  final Color fill;
  final double radius, depth;
  final EdgeInsets padding;
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: depth), // room for the hard shadow
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      transform: Matrix4.translationValues(0, down ? depth : 0, 0),
      width: width,
      padding: padding,
      decoration: pieceDecoration(fill: fill, radius: radius, depth: down ? 0 : depth),
      child: child,
    ),
  );
}

/// Card. Pass [accent] for a solid colour tint, [onTap] to make it press down.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.accent,
    this.fill,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });
  final Widget child;
  final Color? accent; // tinted fill
  final Color? fill; // exact fill, wins over accent
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = fill ?? (accent == null ? AppColors.card : AppColors.tint(accent!));
    if (onTap == null) return _Piece(down: false, fill: color, padding: padding, child: child);
    return Pressable(
      onTap: onTap,
      builder: (_, down) => _Piece(down: down, fill: color, padding: padding, child: child),
    );
  }
}

/// The main action button: a solid block that sinks on touch-down.
class ChunkyButton extends StatelessWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.green,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final face = onPressed == null ? AppColors.track : color;
    final fg = onPressed == null ? AppColors.inkDim : AppColors.on(face);
    return Pressable(
      onTap: onPressed,
      label: label,
      builder: (context, down) => _Piece(
        down: down,
        fill: face,
        radius: 14,
        depth: 4,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: fg, size: 22), const SizedBox(width: 8)],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: context.text.titleLarge!.copyWith(color: fg),
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      decoration: pieceDecoration(radius: 999, depth: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: AppColors.on(color)),
          ),
          const SizedBox(width: 6),
          Text(value, style: context.text.titleLarge!.copyWith(fontSize: 17)),
        ],
      ),
    ),
  );
}

/// Thick outlined progress bar, [value] from 0 to 1.
class FatProgress extends StatelessWidget {
  const FatProgress({super.key, required this.value, this.color = AppColors.green, this.height = 16});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${(value.clamp(0, 1) * 100).round()} percent',
    child: Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      alignment: Alignment.centerLeft,
      child: AnimatedFractionallySizedBox(
        duration: AppMotion.base,
        curve: AppMotion.curve,
        widthFactor: value.clamp(0.0, 1.0),
        heightFactor: 1,
        // Flat highlight stripe along the top: reads as a glossy bar without a gradient.
        child: ColoredBox(
          color: color,
          child: Align(
            alignment: const Alignment(0, -0.5),
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: Container(height: height * 0.16, color: AppColors.card.withValues(alpha: 0.45)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Solid colour block holding an emoji or an icon.
class Badge3D extends StatelessWidget {
  const Badge3D({super.key, this.emoji, this.icon, required this.color, this.size = 52})
    : assert(emoji != null || icon != null);
  final String? emoji;
  final IconData? icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: pieceDecoration(fill: color, radius: size * 0.28, depth: 3),
      child: ExcludeSemantics(
        child: icon != null
            ? Icon(icon, size: size * 0.56, color: AppColors.on(color))
            : Text(emoji!, style: TextStyle(fontSize: size * 0.48)),
      ),
    ),
  );
}

/// Leans its child toward the finger in 3D, then settles back.
class Tilt3D extends StatefulWidget {
  const Tilt3D({super.key, required this.child, this.maxDegrees = 8});
  final Widget child;
  final double maxDegrees;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  Offset _lean = Offset.zero; // -1..1 on each axis

  void _track(PointerEvent e) {
    final size = context.size;
    if (size == null) return;
    setState(
      () => _lean = Offset(
        (e.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (e.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;
    final max = widget.maxDegrees * pi / 180;
    return Listener(
      onPointerDown: _track,
      onPointerMove: _track,
      onPointerUp: (_) => setState(() => _lean = Offset.zero),
      onPointerCancel: (_) => setState(() => _lean = Offset.zero),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: _lean),
        duration: _lean == Offset.zero ? AppMotion.base : AppMotion.fast,
        curve: _lean == Offset.zero ? Curves.easeOutBack : Curves.easeOut,
        builder: (_, lean, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateX(-lean.dy * max)
            ..rotateY(lean.dx * max),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Entrance: scales up with a small overshoot after [delay]. Once per mount.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  /// Stagger helper: `PopIn.at(index, child)`.
  factory PopIn.at(int index, Widget child) => PopIn(
    delay: Duration(milliseconds: 40 * index),
    child: child,
  );

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

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
      builder: (_, child) => Opacity(
        opacity: Curves.easeOut.transform((_c.value * 2).clamp(0, 1)),
        child: Transform.scale(scale: 0.86 + 0.14 * Curves.easeOutBack.transform(_c.value), child: child),
      ),
      child: widget.child,
    );
  }
}

/// A number that rolls to its new value.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.prefix = '', this.suffix = ''});
  final int value;
  final TextStyle? style;
  final String prefix, suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text('$prefix${v.round()}$suffix', style: style),
  );
}

/// Display text with an ink outline, for titles and scores over busy art.
class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text, {super.key, this.style, this.fill = AppColors.card, this.stroke = 5, this.textAlign});
  final String text;
  final TextStyle? style;
  final Color fill;
  final double stroke;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.text.displaySmall!;
    return Stack(
      children: [
        ExcludeSemantics(
          child: Text(
            text,
            textAlign: textAlign,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = stroke
                ..strokeJoin = StrokeJoin.round
                ..color = AppColors.ink,
            ),
          ),
        ),
        Text(
          text,
          textAlign: textAlign,
          style: base.copyWith(color: fill),
        ),
      ],
    );
  }
}

/// A coin with real thickness that spins around its vertical axis.
class Coin3D extends StatefulWidget {
  const Coin3D({super.key, this.size = 28, this.spin = true});
  final double size;
  final bool spin;

  @override
  State<Coin3D> createState() => _Coin3DState();
}

class _Coin3DState extends State<Coin3D> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.spin && !context.reduceMotion ? _c.repeat() : _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(size: Size.square(widget.size), painter: _CoinPainter(_c.value * 2 * pi)),
      ),
    ),
  );
}

class _CoinPainter extends CustomPainter {
  _CoinPainter(this.angle);
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 1.5;
    final c = size.center(Offset.zero);
    final face = cos(angle).abs().clamp(0.08, 1.0); // visible width of the face
    final edge = r * 0.22 * sin(angle).abs(); // visible thickness
    final dir = sin(angle) * cos(angle) >= 0 ? 1.0 : -1.0;
    final ink = Paint()..color = AppColors.ink;
    Rect oval(double dx, double grow) =>
        Rect.fromCenter(center: c.translate(dx, 0), width: 2 * r * face + grow, height: 2 * r + grow);

    // Rim (the coin's thickness), then the face on top.
    canvas.drawOval(oval(-dir * edge, 3), ink);
    canvas.drawRect(Rect.fromLTRB(c.dx - edge - 1, c.dy - r * 0.92, c.dx + edge + 1, c.dy + r * 0.92), ink);
    canvas.drawOval(oval(-dir * edge, 0), Paint()..color = const Color(0xFFD99A00));
    canvas.drawOval(oval(dir * edge, 3), ink);
    canvas.drawOval(oval(dir * edge, 0), Paint()..color = AppColors.yellow);
    canvas.drawOval(
      oval(dir * edge, -r * 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = const Color(0xFFD99A00),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(fontFamily: 'Baloo2', fontWeight: FontWeight.w800, fontSize: r * 1.15, color: AppColors.ink),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas
      ..save()
      ..translate(c.dx + dir * edge, c.dy)
      ..scale(face, 1);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoinPainter old) => old.angle != angle;
}

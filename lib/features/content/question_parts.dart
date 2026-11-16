import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'art.dart';

enum OptState { idle, selected, right, wrong, missed, dim, paired }

const _letterColors = [AppColors.blue, AppColors.yellow, AppColors.teal, AppColors.orange];

/// Answer piece. Sinks while pressed. When the answer locks, the right one jumps (bouncy spring) and turns green,
/// a wrong one shakes and turns red. The caller plays the sound on the same frame it changes [state].
class OptionTile extends StatefulWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.state,
    this.onTap,
    this.leading,
    this.center = false,
    this.tone,
    this.tag,
    this.dense = false,
    this.roomy = false,
  });
  final String label;
  final OptState state;
  final VoidCallback? onTap;
  final String? leading; // letter block: A, B, C, D
  final bool center; // big block (true/false)
  final Color? tone; // idle fill of a big block, fill of a paired tile
  final String? tag; // small number tag on the corner (match)
  final bool dense; // smaller type and padding (compact sheet, match columns)
  final bool roomy; // taller choice card (scenario)

  @override
  State<OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<OptionTile> with TickerProviderStateMixin {
  late final _jump = AnimationController.unbounded(vsync: this);
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(OptionTile old) {
    super.didUpdateWidget(old);
    if (old.state == widget.state || context.reduceMotion) return;
    switch (widget.state) {
      case OptState.wrong:
        _shake.forward(from: 0);
      case OptState.right || OptState.paired:
        _jump.springTo(0, spring: AppMotion.bouncy, velocity: -520);
      case OptState.missed:
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted) _jump.springTo(0, spring: AppMotion.bouncy, velocity: -520);
        });
      default:
    }
  }

  @override
  void dispose() {
    _jump.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final fill = switch (s) {
      OptState.right || OptState.missed => AppColors.green,
      OptState.wrong => AppColors.red,
      OptState.selected => AppColors.tint(AppColors.blue, 0.72),
      OptState.paired => widget.tone ?? AppColors.blue,
      OptState.dim => AppColors.paperDeep,
      OptState.idle => widget.tone ?? AppColors.card,
    };
    final fg = s == OptState.dim ? AppColors.inkDim : AppColors.on(fill);
    final depth = widget.dense ? 4.0 : 5.0;
    final locked = s == OptState.right || s == OptState.wrong || s == OptState.paired || s == OptState.dim;
    final icon = switch (s) {
      OptState.right || OptState.missed => Icons.check_rounded,
      OptState.wrong => Icons.close_rounded,
      _ => null,
    };
    final block = widget.dense ? 28.0 : 36.0;
    final letter = widget.leading;
    final style = widget.center
        ? context.text.headlineSmall!.copyWith(color: fg)
        : (widget.dense ? context.text.titleSmall : context.text.titleMedium)!.copyWith(color: fg);

    Widget face(bool down) {
      final sunk = down || locked;
      final lift = s == OptState.selected && !down ? -3.0 : 0.0;
      return Padding(
        padding: EdgeInsets.only(bottom: depth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: Matrix4.translationValues(0, sunk ? depth : lift, 0),
          constraints: BoxConstraints(minHeight: widget.center ? 88 : (widget.roomy ? 68 : (widget.dense ? 48 : 56))),
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? 10 : 12,
            vertical: widget.center ? 12 : (widget.roomy ? 14 : 8),
          ),
          decoration: pieceDecoration(fill: fill, radius: 16, depth: sunk || s == OptState.dim ? 0 : depth),
          child: Row(
            mainAxisAlignment: widget.center ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (letter != null) ...[
                Container(
                  width: block,
                  height: block,
                  alignment: Alignment.center,
                  decoration: pieceDecoration(
                    fill: icon != null ? AppColors.card : _letterColors[(letter.codeUnitAt(0) - 65) % 4],
                    radius: 10,
                    depth: 0,
                  ),
                  child: icon != null
                      ? Icon(icon, color: AppColors.ink, size: block * 0.72)
                      : Text(
                          letter,
                          style: context.text.titleLarge!.copyWith(
                            fontSize: widget.dense ? 16 : 19,
                            color: AppColors.on(_letterColors[(letter.codeUnitAt(0) - 65) % 4]),
                          ),
                        ),
                ),
                SizedBox(width: widget.dense ? 8 : 12),
              ],
              Flexible(
                child: Text(widget.label, textAlign: widget.center ? TextAlign.center : TextAlign.start, style: style),
              ),
              if (icon != null && letter == null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: fg, size: widget.center ? 34 : 22),
              ],
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_jump, _shake]),
      builder: (_, child) => Transform.translate(
        offset: Offset(sin(_shake.value * pi * 6) * 9 * (1 - _shake.value), _jump.value),
        child: child,
      ),
      child: Pressable(
        silent: true,
        label: widget.label,
        onTap: widget.onTap,
        builder: (_, down) {
          if (widget.tag == null) return face(down);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              face(down),
              Positioned(
                top: -7,
                left: -5,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: pieceDecoration(fill: AppColors.card, radius: 8, depth: 0),
                  child: Text(widget.tag!, style: context.text.titleSmall!.copyWith(fontSize: 14, height: 1)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Result banner: a solid green or red piece that slides up with the explanation. A scenario outcome sits on a
/// comic speech panel inside it.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key, required this.correct, required this.title, required this.explanation, this.note});
  final bool correct;
  final String title, explanation;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = correct ? AppColors.green : AppColors.red;
    final fg = AppColors.on(c);
    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: pieceDecoration(fill: c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: pieceDecoration(radius: 10, depth: 0),
                child: Icon(correct ? Icons.check_rounded : Icons.close_rounded, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: context.text.titleLarge!.copyWith(color: fg)),
              ),
            ],
          ),
          if (note != null) ...[const SizedBox(height: AppSpace.sm), _Speech(note!)],
          const SizedBox(height: AppSpace.sm),
          Text(explanation, style: context.text.bodyLarge!.copyWith(color: fg, fontSize: 15)),
        ],
      ),
    );
    if (context.reduceMotion) return banner;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0, end: 1),
      builder: (_, t, child) => Transform.translate(offset: Offset(0, (1 - t) * 56), child: child),
      child: banner,
    );
  }
}

/// Comic speech panel: white, outlined, with a tail pointing up at the headline.
class _Speech extends StatelessWidget {
  const _Speech(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SpeechPainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
      child: SizedBox(
        width: double.infinity,
        child: Text(text, style: context.text.bodyLarge!.copyWith(fontSize: 15)),
      ),
    ),
  );
}

class _SpeechPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const top = 12.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(1, top, size.width - 1, size.height - 1),
      const Radius.circular(14),
    );
    final tail = [const Offset(20, top), const Offset(30, 1), const Offset(44, top)];
    final fill = Paint()..color = AppColors.card;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;
    canvas.drawRRect(body, fill);
    canvas.drawPath(Path()..addPolygon(tail, true), fill);
    canvas.drawRRect(body, line);
    canvas.drawPath(Path()..addPolygon(tail, false), line);
    canvas.drawRect(Rect.fromLTRB(21.5, top - 1.6, 42.5, top + 1.6), fill); // hides the stroke across the tail base
  }

  @override
  bool shouldRepaint(_) => false;
}

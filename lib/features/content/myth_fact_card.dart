import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'art.dart';

/// Swipeable statement card. Drag left = Myth, right = Fact; buttons do the same.
/// When the answer locks, a rubber stamp slams onto the card.
class MythFactBody extends StatefulWidget {
  const MythFactBody({
    super.key,
    required this.statement,
    required this.isFact,
    required this.onResult,
    this.compact = false,
  });
  final String statement;
  final bool isFact;
  final ValueChanged<bool> onResult;
  final bool compact;

  @override
  State<MythFactBody> createState() => _MythFactBodyState();
}

class _MythFactBodyState extends State<MythFactBody> {
  double _dx = 0;
  bool _dragging = false;
  bool? _pickedFact;

  void _pick(bool fact) {
    if (_pickedFact != null) return;
    setState(() {
      _pickedFact = fact;
      _dx = 0;
      _dragging = false;
    });
    widget.onResult(fact == widget.isFact);
  }

  /// Corner chip that lights up as the card leans its way.
  Widget _chip(String text, Color color, double strength) => Transform.scale(
    scale: 1 + 0.18 * strength,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: pieceDecoration(fill: strength > 0.3 ? color : AppColors.card, radius: 999, depth: 0),
      child: Text(
        text,
        style: context.text.labelLarge!.copyWith(
          fontSize: 12,
          color: strength > 0.3 ? AppColors.on(color) : AppColors.ink,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final picked = _pickedFact;
    final lean = (_dx / 110).clamp(-1.0, 1.0);
    final compact = widget.compact;
    final stampColor = widget.isFact ? AppColors.green : AppColors.red;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onHorizontalDragStart: picked == null ? (_) => setState(() => _dragging = true) : null,
          onHorizontalDragUpdate: picked == null ? (d) => setState(() => _dx += d.delta.dx) : null,
          onHorizontalDragEnd: picked == null
              ? (_) => _dx.abs() > 90
                    ? _pick(_dx > 0)
                    : setState(() {
                        _dx = 0;
                        _dragging = false;
                      })
              : null,
          child: AnimatedContainer(
            duration: _dragging ? Duration.zero : AppMotion.base,
            curve: Curves.easeOutBack,
            transformAlignment: Alignment.bottomCenter,
            transform: Matrix4.translationValues(_dx, 0, 0)..rotateZ(_dx / 900),
            padding: const EdgeInsets.only(bottom: AppSpace.depth),
            child: Semantics(
              label: widget.statement,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: pieceDecoration(radius: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 8),
                      decoration: const BoxDecoration(
                        color: AppColors.yellow,
                        border: Border(
                          bottom: BorderSide(color: AppColors.ink, width: AppSpace.outline),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _chip('MYTH', AppColors.red, picked == null ? max(0, -lean) : (picked ? 0 : 1)),
                          Flexible(
                            child: Text(
                              'MYTH OR FACT?',
                              style: context.text.titleSmall!.copyWith(fontSize: compact ? 13 : 15),
                            ),
                          ),
                          _chip('FACT', AppColors.green, picked == null ? max(0, lean) : (picked ? 1 : 0)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(18, compact ? 14 : 24, 18, compact ? 6 : 10),
                      child: Center(
                        child: Text(
                          widget.statement,
                          textAlign: TextAlign.center,
                          style: compact ? context.text.titleMedium : context.text.titleLarge!.copyWith(fontSize: 22),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: compact ? 56 : 84,
                      child: picked == null
                          ? Center(child: Text('Swipe the card, or tap a button', style: context.text.bodySmall))
                          : Center(
                              child: _Stamp(isFact: widget.isFact, color: stampColor, compact: compact),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        if (picked == null)
          Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  label: 'Myth',
                  icon: Icons.arrow_back_rounded,
                  color: AppColors.red,
                  onPressed: () => _pick(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChunkyButton(label: 'Fact', icon: Icons.arrow_forward_rounded, onPressed: () => _pick(true)),
              ),
            ],
          ),
      ],
    );
  }
}

/// Rubber stamp: scales down from large with a spring and lands about 12 degrees counter-clockwise.
class _Stamp extends StatefulWidget {
  const _Stamp({required this.isFact, required this.color, required this.compact});
  final bool isFact, compact;
  final Color color;

  @override
  State<_Stamp> createState() => _StampState();
}

class _StampState extends State<_Stamp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.springTo(1, spring: const SpringDescription(mass: 1, stiffness: 560, damping: 24));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.scale(scale: 3 - 2 * _c.value, child: child),
    child: Transform.rotate(
      angle: -12 * pi / 180,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: widget.compact ? 0 : 2),
        decoration: pieceDecoration(fill: AppColors.card, radius: 12, depth: 0, outline: widget.color),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: widget.color, width: 2.5)),
          ),
          child: OutlinedText(
            widget.isFact ? 'FACT' : 'MYTH',
            fill: widget.color,
            stroke: 5,
            style: context.text.headlineMedium!.copyWith(fontSize: widget.compact ? 26 : 34, letterSpacing: 2),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Swipeable statement card. Drag left = Myth, right = Fact; buttons do the same.
class MythFactBody extends StatefulWidget {
  const MythFactBody({super.key, required this.statement, required this.isFact, required this.onResult});
  final String statement;
  final bool isFact;
  final ValueChanged<bool> onResult;

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

  @override
  Widget build(BuildContext context) {
    final picked = _pickedFact;
    // While dragging the stamp follows the finger; afterwards it shows the player's pick.
    final leaning = picked ?? (_dx == 0 ? null : _dx > 0);
    final strength = picked != null ? 1.0 : (_dx.abs() / 110).clamp(0.0, 1.0);
    final stampColor = leaning == null
        ? AppColors.line
        : picked == null
        ? (leaning ? AppColors.mint : AppColors.coral)
        : (picked == widget.isFact ? AppColors.mint : AppColors.coral);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MYTH OR FACT?', style: context.text.labelSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.sm),
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
            child: Semantics(
              label: widget.statement,
              child: Container(
                constraints: const BoxConstraints(minHeight: 190),
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpace.radius + 6),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.surfaceHi, AppColors.surface],
                  ),
                  border: Border.all(color: Color.lerp(AppColors.line, stampColor, strength)!, width: 2.5),
                  boxShadow: [BoxShadow(color: stampColor.withValues(alpha: 0.25 * strength), blurRadius: 24)],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(widget.statement, textAlign: TextAlign.center, style: context.text.titleLarge),
                    ),
                    if (leaning != null)
                      Positioned(
                        top: 0,
                        left: leaning ? 0 : null,
                        right: leaning ? null : 0,
                        child: Opacity(
                          opacity: strength,
                          child: Transform.rotate(
                            angle: leaning ? -0.2 : 0.2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: stampColor, width: 3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                leaning ? 'FACT' : 'MYTH',
                                style: context.text.titleLarge!.copyWith(color: stampColor, letterSpacing: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        if (picked == null) ...[
          Text('Swipe the card, or tap a button', style: context.text.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  label: 'Myth',
                  icon: Icons.arrow_back_rounded,
                  color: AppColors.coral,
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
      ],
    );
  }
}
